#!/usr/bin/env python3
"""Remove class-reference aliases without decoding Pascal source bytes.

Discover library types with --types, then plan changes under --rewrite.
--apply requires clean committed worktrees on non-main branches.
Strings and comments are preserved; actual record pointers keep their names.
"""
import argparse
from dataclasses import dataclass
from pathlib import Path
import subprocess


@dataclass(frozen=True)
class Token:
    start: int
    end: int
    text: bytes


def tokens(data):
    result = []
    i = 0
    letters = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
    digits = b"0123456789"
    while i < len(data):
        if data[i] in b" \t\r\n":
            i += 1
            continue
        if data[i:i + 2] == b"//":
            end = data.find(b"\n", i)
            i = len(data) if end < 0 else end + 1
            continue
        if data[i:i + 1] == b"{" or data[i:i + 2] == b"(*":
            stack = []
            while i < len(data):
                if data[i:i + 1] == b"{":
                    stack.append(b"}")
                    i += 1
                elif data[i:i + 2] == b"(*":
                    stack.append(b"*)")
                    i += 2
                elif stack and data[i:i + len(stack[-1])] == stack[-1]:
                    i += len(stack.pop())
                    if not stack:
                        break
                else:
                    i += 1
            if stack:
                raise ValueError("unterminated Pascal comment")
            continue
        if data[i:i + 1] == b"'":
            i += 1
            while i < len(data):
                if data[i:i + 2] == b"''":
                    i += 2
                elif data[i:i + 1] == b"'":
                    i += 1
                    break
                else:
                    i += 1
            else:
                raise ValueError("unterminated Pascal string")
            continue
        start = i
        i += 1
        if data[start] in letters:
            while i < len(data) and data[i] in letters + digits:
                i += 1
        result.append(Token(start, i, data[start:i]))
    return result


def declared_kinds(ts):
    result = {}
    for i in range(len(ts) - 2):
        if ts[i + 1].text == b"=":
            kind = ts[i + 2].text.lower()
            if kind in (b"class", b"record"):
                if kind == b"class" and i + 3 < len(ts) and ts[i + 3].text.lower() == b"of":
                    continue
                result[ts[i].text.lower()] = kind
    return result


def alias_targets(ts):
    result = []
    for i in range(len(ts) - 3):
        if not ts[i].text.lower().startswith(b"p") or ts[i + 1].text != b"=":
            continue
        j = i + 2
        if ts[j].text == b"^":
            j += 1
        if j + 1 >= len(ts) or ts[j + 1].text != b";":
            continue
        target = ts[j].text
        result.append((ts[i], ts[j + 1], target))
    return result


def alias_declarations(ts, classes):
    local_kinds = declared_kinds(ts)
    result = []
    for first, last, target in alias_targets(ts):
        key = target.lower()
        is_class = local_kinds.get(key) == b"class" or (
            key not in local_kinds and key in classes)
        if is_class:
            result.append((first, last, target))
    return result


def library_aliases(sources):
    parsed = [tokens(data) for data in sources]
    classes, records = set(), set()
    for ts in parsed:
        for name, kind in declared_kinds(ts).items():
            (classes if kind == b"class" else records).add(name)
    classes -= records
    aliases = {}
    for ts in parsed:
        for first, last, target in alias_declarations(ts, classes):
            key = first.text.lower()
            if key in aliases and aliases[key].lower() != target.lower():
                raise ValueError(f"ambiguous class alias: {first.text!r}")
            aliases[key] = target
    return classes, aliases


def rewrite(data, classes, shared):
    ts = tokens(data)
    local_aliases = alias_targets(ts)
    declarations = alias_declarations(ts, classes)
    local_names = {first.text.lower() for first, _, _ in local_aliases}
    aliases = {name: target for name, target in shared.items() if name not in local_names}
    removals = []
    for first, last, target in declarations:
        aliases[first.text.lower()] = target
        start, end = first.start, last.end
        line_start = data.rfind(b"\n", 0, start) + 1
        line_end = data.find(b"\n", end)
        line_end = len(data) if line_end < 0 else line_end + 1
        if not data[line_start:start].strip() and not data[end:line_end].strip():
            start, end = line_start, line_end
        removals.append((start, end, b""))
    edits = list(removals)
    for token in ts:
        replacement = aliases.get(token.text.lower())
        if replacement is not None and not any(a <= token.start < b for a, b, _ in removals):
            edits.append((token.start, token.end, replacement))
    edits.sort()
    result = bytearray()
    position = 0
    for start, end, replacement in edits:
        if start < position:
            raise ValueError("overlapping Pascal edits")
        result.extend(data[position:start])
        result.extend(replacement)
        position = end
    result.extend(data[position:])
    return bytes(result), len(declarations)


def files(paths):
    result = set()
    for name in paths:
        path = Path(name)
        candidates = [path] if path.is_file() else path.rglob("*")
        for candidate in candidates:
            if candidate.is_file() and candidate.suffix.lower() in (".pas", ".inc"):
                result.add(candidate.resolve())
    return sorted(result)


def checkpoints(paths):
    repos = set()
    for path in paths:
        root = subprocess.check_output(
            ["git", "-C", str(path.parent), "rev-parse", "--show-toplevel"], text=True).strip()
        repos.add(root)
    for root in sorted(repos):
        branch = subprocess.check_output(["git", "-C", root, "branch", "--show-current"], text=True).strip()
        if not branch or branch in ("main", "master"):
            raise ValueError(f"rewrite requires a migration branch: {root}")
        if subprocess.check_output(["git", "-C", root, "status", "--porcelain"]):
            raise ValueError(f"rewrite requires a clean checkpoint: {root}")
        sha = subprocess.check_output(["git", "-C", root, "rev-parse", "HEAD"], text=True).strip()
        print(f"checkpoint {root}: {sha}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--types", nargs="+", required=True)
    parser.add_argument("--rewrite", nargs="+", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    sources = files(args.types)
    targets = files(args.rewrite)
    if args.apply:
        checkpoints(targets)
    classes, shared = library_aliases([path.read_bytes() for path in sources])
    plans = []
    for path in targets:
        original = path.read_bytes()
        converted, count = rewrite(original, classes, shared)
        if original != converted:
            plans.append((path, original, converted))
            print(f"{path}: {count} declarations removed")
    if args.apply:
        for path, original, converted in plans:
            if path.read_bytes() != original:
                raise ValueError(f"source changed while planning: {path}")
        for path, original, converted in plans:
            path.write_bytes(converted)
    print(f"{len(shared)} library aliases; {len(plans)} files {'changed' if args.apply else 'planned'}")


if __name__ == "__main__":
    main()
