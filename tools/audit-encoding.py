#!/usr/bin/env python3
"""Audit the text of the tracked files for lost or damaged characters (docs/TEXT-POLICY.md).

    tools/audit-encoding.py                       # integrity of the tree: UTF-8, no U+FFFD, no C1 controls
    tools/audit-encoding.py --against REV         # + characters that REV (a git revision of dn) had and the tree lost
    tools/audit-encoding.py --against-dir DIR     # + the same against an unpacked original tree (the DN OSP archive, CP866)

An old text that is not valid UTF-8 is read as CP866 (--codepage). The comparison is per file (files are paired by name,
a renamed one by dn/renames.map when given), by the multiset of non-ASCII characters: a character that was in the old file
and is not in the new one is reported with the line it was on. Intended changes (translated comments, repaired look-alike
letters, glyph constants) show up as reports too: the output is a list to look through, the exit code is 1 only for the
integrity problems of the tree itself (the checks of the first mode), so that CI can gate on them.
"""
import argparse
import collections
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
C1 = re.compile("[\u0080-\u009f]")
TEXT_SUFFIXES = {".pas", ".inc", ".pp", ".lpr", ".txt", ".md", ".htx", ".dnl", ".dnr", ".ini", ".py", ".sh", ".yml",
                 ".env", ".cfg", ".diz", ".ion", ".list", ".map", ".rw", ".sed", ".patch", ".flg"}
# data in a code page on purpose (docs/TEXT-POLICY.md)
BINARY_OK = (re.compile(r"/xlt/"),)


def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=True).stdout


def tracked(cwd=ROOT, prefix=""):
    for name in git("ls-files", "-z", cwd=cwd).decode("utf-8").split("\0"):
        path = cwd / name
        if name and path.is_file():
            yield prefix + name, path.read_bytes()


def is_text(name, data):
    if b"\0" in data or any(rx.search(name) for rx in BINARY_OK):
        return False
    return Path(name).suffix.lower() in TEXT_SUFFIXES or "." not in Path(name).name


def decode(data, codepage):
    try:
        return data.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return data.decode(codepage, errors="replace"), codepage


def integrity(files):
    problems = []
    for name, data in files:
        if not is_text(name, data):
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError as error:
            problems.append("%s: not UTF-8 (byte %d)" % (name, error.start))
            continue
        if text.startswith("\ufeff"):
            problems.append("%s: byte order mark" % name)
        for number, line in enumerate(text.split("\n"), 1):
            if "\ufffd" in line:
                problems.append("%s:%d: U+FFFD (a lost character): %s" % (name, number, line.strip()[:100]))
            elif C1.search(line):
                problems.append("%s:%d: C1 control character (a code page byte read as Latin-1): %s" % (name, number, line.strip()[:100]))
    return problems


PASCAL = {".pas", ".inc", ".pp", ".lpr"}
DOCS = {".md", ".txt", ".py", ".sh", ".yml", ".env", ".list", ".map", ".rw", ".sed", ".patch"}
COMMENT = re.compile(r"\(\*.*?\*\)|\{[^}\n]*\}|//[^\n]*", re.S)
STRING = re.compile(r"'(?:[^'\n]|'')*'")


def code_only(text):
    """A Pascal text without its comments: the code and the string literals stay (a small scanner, not a regex:
    comments are multi-line and hold apostrophes)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":                                  # a string literal ('' inside is a quote)
            j = i + 1
            while j < n and text[j] != "\n" and not (text[j] == "'" and text[j + 1:j + 2] != "'"):
                j += 2 if text[j] == "'" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif c == "{":
            j = text.find("}", i)
            i = n if j < 0 else j + 1
        elif text.startswith("(*", i):
            j = text.find("*)", i + 2)
            i = n if j < 0 else j + 2
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def relevant(name, text, show_docs):
    """The part of a text whose characters matter: the code and the strings of a Pascal file, the whole of a resource."""
    suffix = Path(name).suffix.lower()
    if suffix in PASCAL:
        return code_only(text)
    if suffix in DOCS:
        return text if show_docs else ""
    return text


def non_ascii(text):
    return collections.Counter(c for c in text if ord(c) > 127)


def lost_characters(old_text, new_text, skip_cyrillic=False):
    """[(char, how many fewer, the first old line holding it)] for the characters the new text has fewer of."""
    old, new = non_ascii(old_text), non_ascii(new_text)
    report = []
    for char, count in sorted(old.items()):
        if skip_cyrillic and "\u0400" <= char <= "\u04ff":
            continue                    # the English resources have no Cyrillic on purpose
        if new[char] < count:
            line = next(l for l in old_text.split("\n") if char in l)
            report.append((char, count - new[char], line.strip()[:100]))
    return report


def compare(old_files, new_files, codepage, renames, show_docs=False):
    new_by_name = {name: data for name, data in new_files}
    shown = 0
    for name, data in old_files:
        if not is_text(name, data):
            continue
        new = new_by_name.get(renames.get(name, name))
        if new is None:
            print("only in the old tree: %s" % name)
            continue
        old_text, how = decode(data, codepage)
        new_text = new.decode("utf-8", errors="replace")
        english = "/resource/english/" in (renames.get(name, name))
        for char, count, line in lost_characters(relevant(name, old_text, show_docs), relevant(name, new_text, show_docs), english):
            print("%s (old %s): U+%04X %r lost x%d: %s" % (name, how, ord(char), char, count, line))
            shown += 1
    return shown


def load_renames():
    result = {}
    path = ROOT / "dn/renames.map"
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) == 2 and not line.startswith("#"):
                result[parts[0]] = parts[1]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--against", metavar="REV", help="a git revision of this repository")
    parser.add_argument("--against-dir", metavar="DIR", help="an unpacked original tree (paths matched by lower-cased name)")
    parser.add_argument("--codepage", default="cp866", help="the code page of an old text that is not UTF-8")
    parser.add_argument("--docs", action="store_true", help="also compare the documents and scripts (their comments and text were translated)")
    parser.add_argument("--no-tv", action="store_true", help="do not read the tv/ submodule")
    args = parser.parse_args()

    files = list(tracked())
    if not args.no_tv and (ROOT / "tv/.git").exists():
        files += list(tracked(ROOT / "tv", "tv/"))
    problems = integrity(files)
    for problem in problems:
        print("INTEGRITY:", problem)
    print("%d text files checked, %d integrity problems" % (sum(1 for n, d in files if is_text(n, d)), len(problems)))

    if args.against:
        old = []
        for name in git("ls-tree", "-r", "--name-only", args.against).decode("utf-8").split("\n"):
            if name.startswith(("dn/", "tools/", "docs/")):
                old.append((name, git("show", "%s:%s" % (args.against, name))))
        print("-- against", args.against)
        compare(old, files, args.codepage, load_renames(), args.docs)
    if args.against_dir:
        base = Path(args.against_dir)
        old = []
        for path in sorted(base.rglob("*")):
            if path.is_file():
                old.append((path.name.lower(), path.read_bytes()))
        by_base = collections.defaultdict(list)
        for name, data in files:
            by_base[Path(name).name.lower()].append((name, data))
        print("-- against", base)
        for name, data in old:
            for new_name, new_data in by_base.get(name, []):
                if new_name.startswith(("dn/src/", "dn/data/")) and is_text(name, data):
                    old_text, how = decode(data, args.codepage)
                    english = "/resource/english/" in new_name
                    for char, count, line in lost_characters(relevant(new_name, old_text, args.docs), relevant(new_name, new_data.decode("utf-8", errors="replace"), args.docs), english):
                        print("%s (old %s): U+%04X %r lost x%d: %s" % (new_name, how, ord(char), char, count, line))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
