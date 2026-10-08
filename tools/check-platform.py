#!/usr/bin/env python3
"""The platform boundary of DN (docs/PLATFORM-SEPARATION.md): tools/check-platform.py, exit code 1 when it is broken.

1. A unit outside the backends does not use a platform unit (BaseUnix, Unix, Windows, go32, termio, dpmiexcp, Linux).
2. A target conditional ({$IFDEF GO32V2}, {$IF DEFINED(UNIX)} ...) is in a backend or in a file of the table below, which gives the reason in one line.
   A conditional that is inside a comment (dead code) does not count.
The backends are the platform facades and their targets (compat/os*, compat/dnrun*, realmode, dnuserscreendos, ...): they may use anything.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

BACKENDS = [
    r"^dn/compat/(osdep|osdisk\w*|osnames\w*|osrun\w*|ossystem\w*|osstartscreen|dnscreen|dnrun\w*|dnuserscreendos|realmode|dosharness|drivers)\.pas$",
    r"^dn/compat/(linux/)?country\.pas$",
]

# file -> why a target conditional is there (one line each; a new one needs a line here)
ALLOWED = {
    "dn/compat/dnpath.pas": "the one unit that knows the separator and the drives of the host (docs/PATHS.md)",
    "dn/src/dnrun.pas": "the facade selects the backend of the target (DNRunDos, DNRunLinux, DNRunOther): the only place",
    "dn/archives/fmt7z.pas": "the format works through host tools that exist on Unix (7z)",
    "dn/archives/fmtbz2.pas": "the format works through host tools / zstream of Unix (tar.bz2)",
    "dn/archives/fmtrar.pas": "the format works through host tools that exist on Unix (unrar)",
    "dn/archives/fmttar.pas": "tar: the Unix mode bits of a member",
    "dn/archives/fmttgz.pas": "the format works through zstream of Unix (tar.gz)",
    "dn/archives/fmtxz.pas": "the format works through the xz tool of Unix (tar.xz)",
    "dn/archives/fmtzip.pas": "the format works through host tools that exist on Unix (zip)",
}

PLATFORM_UNITS = re.compile(r"\b(BaseUnix|Unix|Windows|go32|termio|dpmiexcp|Linux)\b", re.I)
TARGETS = re.compile(r"\b(GO32V2|LINUX|UNIX|WINDOWS|WIN32|WIN64|MSWINDOWS|DPMI32|OS2|DARWIN|FREEBSD|BSD)\b", re.I)
DIRECTIVE = re.compile(r"\{\$(IFDEF|IFNDEF|IF|ELSEIF)\s+([^}]*)\}", re.I)


def scan(text):
    """The code of a Pascal text as (kept, directives): comments and strings are dropped, the directives {$...} are kept apart."""
    kept, directives, i, n = [], [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            j = i + 1
            while j < n and text[j] != "\n" and not (text[j] == "'" and text[j + 1:j + 2] != "'"):
                j += 2 if text[j] == "'" else 1
            i = j + 1
        elif c == "{":
            j = text.find("}", i)
            j = n - 1 if j < 0 else j
            if text.startswith("{$", i):
                directives.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("(*", i):
            j = text.find("*)", i + 2)
            i = n if j < 0 else j + 2
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        else:
            kept.append(c)
            i += 1
    return "".join(kept), directives


def tracked():
    out = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z", "dn"]).decode("utf-8")
    for name in out.split("\0"):
        if re.search(r"\.(pas|inc)$", name) and not name.startswith("dn/tests/") and (ROOT / name).is_file():
            yield name, (ROOT / name).read_bytes().decode("utf-8", "replace")


def check():
    problems = []
    for name, text in tracked():
        backend = any(re.search(p, name) for p in BACKENDS)
        code, directives = scan(text)
        if not backend:
            for m in re.finditer(r"\buses\b([^;]*);", code, re.I | re.S):
                bad = PLATFORM_UNITS.findall(m.group(1))
                if bad:
                    problems.append("%s: uses a platform unit (%s): go through a facade of dn/compat" % (name, ", ".join(sorted(set(bad)))))
            if name not in ALLOWED:
                for d in directives:
                    m = DIRECTIVE.match(d)
                    if m and TARGETS.search(m.group(2)):
                        problems.append("%s: target conditional %s outside the backends: move it behind a facade or list the file in tools/check-platform.py with a reason" % (name, d))
                        break
    for name in ALLOWED:
        if not (ROOT / name).is_file():
            problems.append("%s: listed in tools/check-platform.py but there is no such file" % name)
    return problems


if __name__ == "__main__":
    found = check()
    for problem in found:
        print("PLATFORM:", problem)
    print("platform boundary: %d problems" % len(found))
    sys.exit(1 if found else 0)
