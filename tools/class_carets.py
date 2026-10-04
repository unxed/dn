#!/usr/bin/env python3
"""Remove illegal ^ after class references without decoding Pascal source bytes.

Discover class types with --types, then plan caret removals under --rewrite.
--apply requires clean committed worktrees on non-main branches.
Strings and comments are preserved; record/pointer dereferences keep ^.
"""
import argparse

from class_names import (
    alias_declarations,
    checkpoints,
    declared_kinds,
    files,
    tokens,
)


def library_classes(sources):
    parsed = [tokens(data) for data in sources]
    classes, records = set(), set()
    for ts in parsed:
        for name, kind in declared_kinds(ts).items():
            (classes if kind == b"class" else records).add(name)
    classes -= records
    aliases = {}
    for ts in parsed:
        for first, _last, target in alias_declarations(ts, classes):
            key = first.text.lower()
            if key in aliases and aliases[key].lower() != target.lower():
                raise ValueError(f"ambiguous class alias: {first.text!r}")
            aliases[key] = target
    names = set(classes)
    names.update(aliases)
    return names


def is_ident(tok):
    return bool(tok.text) and (
        (65 <= tok.text[0] <= 90)
        or (97 <= tok.text[0] <= 122)
        or tok.text[0] == 95
    )


def type_name_before(ts, index, class_names):
    """If ts[index-1] ends a class type name, return True."""
    if index <= 0 or not is_ident(ts[index - 1]):
        return False
    j = index - 1
    while j >= 2 and ts[j - 1].text == b"." and is_ident(ts[j - 2]):
        j -= 2
    return ts[index - 1].text.lower() in class_names


def type_token_after_colon(ts, colon_index):
    j = colon_index + 1
    while j < len(ts) and ts[j].text.lower() in (b"packed", b"bitpacked", b"specialize"):
        j += 1
    if j < len(ts) and ts[j].text == b"^":
        j += 1
    return j


def collect_class_vars(sources, class_names):
    """Names of fields/vars/params whose declared type is a class reference."""
    result = set()
    for data in sources:
        ts = tokens(data)
        i = 0
        while i < len(ts):
            if ts[i].text == b":" and i > 0 and is_ident(ts[i - 1]):
                if i >= 2 and ts[i - 2].text.lower() in (
                    b"function", b"constructor", b"destructor", b"property",
                    b"procedure",
                ):
                    i += 1
                    continue
                j = type_token_after_colon(ts, i)
                if j < len(ts) and is_ident(ts[j]):
                    end = j + 1
                    while end + 1 < len(ts) and ts[end].text == b"." and is_ident(ts[end + 1]):
                        end += 2
                    if ts[end - 1].text.lower() in class_names:
                        result.add(ts[i - 1].text.lower())
            i += 1
    return result


def find_open_paren(ts, close_index):
    depth = 0
    for i in range(close_index, -1, -1):
        if ts[i].text == b")":
            depth += 1
        elif ts[i].text == b"(":
            depth -= 1
            if depth == 0:
                return i
    return None


def caret_is_class_deref(ts, caret_index, class_names, class_vars):
    if caret_index <= 0 or ts[caret_index].text != b"^":
        return False
    nxt = caret_index + 1
    if nxt >= len(ts):
        return False
    if not (
        ts[nxt].text == b"."
        or ts[nxt].text.lower() == b"do"
        or ts[nxt].text in (b")", b",", b";")
    ):
        return False

    prev = caret_index - 1
    if ts[prev].text == b")":
        open_paren = find_open_paren(ts, prev)
        return open_paren is not None and type_name_before(ts, open_paren, class_names)

    if is_ident(ts[prev]):
        return ts[prev].text.lower() in class_vars
    return False


def caret_removals(data, class_names, class_vars):
    ts = tokens(data)
    names = class_vars | collect_class_vars([data], class_names)
    return [
        (tok.start, tok.end, b"")
        for i, tok in enumerate(ts)
        if tok.text == b"^" and caret_is_class_deref(ts, i, class_names, names)
    ]


def rewrite(data, class_names, class_vars):
    edits = caret_removals(data, class_names, class_vars)
    result = bytearray()
    position = 0
    for start, end, replacement in edits:
        if start < position:
            raise ValueError("overlapping Pascal edits")
        result.extend(data[position:start])
        result.extend(replacement)
        position = end
    result.extend(data[position:])
    return bytes(result), len(edits)


def prepare(types_paths):
    sources = files(types_paths)
    source_bytes = [path.read_bytes() for path in sources]
    class_names = library_classes(source_bytes)
    class_vars = collect_class_vars(source_bytes, class_names)
    return class_names, class_vars


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--types", nargs="+", required=True)
    parser.add_argument("--rewrite", nargs="+", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    targets = files(args.rewrite)
    if args.apply:
        checkpoints(targets)
    class_names, class_vars = prepare(args.types)
    plans = []
    for path in targets:
        original = path.read_bytes()
        converted, count = rewrite(original, class_names, class_vars)
        if original != converted:
            plans.append((path, original, converted, count))
            print(f"{path}: {count} carets removed")
    if args.apply:
        for path, original, converted, _count in plans:
            if path.read_bytes() != original:
                raise ValueError(f"source changed while planning: {path}")
        for path, original, converted, _count in plans:
            path.write_bytes(converted)
    print(
        f"{len(class_names)} class names, {len(class_vars)} class-typed names; "
        f"{len(plans)} files {'changed' if args.apply else 'planned'}"
    )


if __name__ == "__main__":
    main()
