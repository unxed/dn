#!/usr/bin/env python3
"""Remove illegal ^ after class references without decoding Pascal source bytes.

Discover class types with --types, then plan caret removals under --rewrite.
--apply requires clean committed worktrees on non-main branches.
Strings and comments are preserved; record/pointer dereferences keep ^.

Global names come only from fields declared inside class types. Locals and
parameters of the rewritten file are considered too. Comma lists like
`A, B: TView` are supported.
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


def class_type_end(ts, type_index, class_names):
    if type_index >= len(ts) or not is_ident(ts[type_index]):
        return None
    end = type_index + 1
    while end + 1 < len(ts) and ts[end].text == b"." and is_ident(ts[end + 1]):
        end += 2
    if ts[end - 1].text.lower() in class_names:
        return end
    return None


def names_before_colon(ts, colon_index):
    """Return identifiers in `A, B, C:` ending at colon_index."""
    if colon_index <= 0 or not is_ident(ts[colon_index - 1]):
        return []
    names = [ts[colon_index - 1].text.lower()]
    j = colon_index - 1
    while j >= 2 and ts[j - 1].text == b"," and is_ident(ts[j - 2]):
        names.append(ts[j - 2].text.lower())
        j -= 2
    return names


def collect_typed_names(sources, class_names, fields_only=False):
    """Return (class_typed_names, non_class_typed_names).

    fields_only: only fields inside `class`/`record` (safe for global use).
    otherwise: those fields plus vars/parameters of the rewritten file.
    Non-class vars/parameters shadow class field names of the same spelling.
    Non-class fields of other types in the same unit do not, because they
    belong to a different Self.
    """
    class_typed = set()
    other_typed = set()
    skip_before = {
        b"function", b"constructor", b"destructor", b"property", b"procedure",
    }
    aggregate_starts = {b"class", b"record", b"object"}
    for data in sources:
        ts = tokens(data)
        aggregate_depth = 0
        i = 0
        while i < len(ts):
            word = ts[i].text.lower()
            if word in aggregate_starts and i + 1 < len(ts):
                following = ts[i + 1].text.lower()
                if following not in (b"of", b";"):
                    aggregate_depth += 1
            elif word == b"end" and aggregate_depth:
                aggregate_depth -= 1

            if ts[i].text == b":":
                # `:=` is assignment, not a declaration.
                if i + 1 < len(ts) and ts[i + 1].text == b"=":
                    i += 1
                    continue
                if fields_only and aggregate_depth == 0:
                    i += 1
                    continue
                if i >= 2 and ts[i - 2].text.lower() in skip_before:
                    i += 1
                    continue
                names = names_before_colon(ts, i)
                if not names:
                    i += 1
                    continue
                j = type_token_after_colon(ts, i)
                if class_type_end(ts, j, class_names) is not None:
                    if (not fields_only) or aggregate_depth:
                        class_typed.update(names)
                elif not fields_only and aggregate_depth == 0:
                    # Vars/params that are actual pointers shadow class fields.
                    # Scalars like Integer must not: the same short name is often
                    # reused for a class-typed local in another routine.
                    if j < len(ts) and ts[j].text == b"^":
                        other_typed.update(names)
                    else:
                        end = class_type_end(ts, j, class_names)
                        if end is None and j < len(ts) and is_ident(ts[j]):
                            k = j + 1
                            while k + 1 < len(ts) and ts[k].text == b"." and is_ident(ts[k + 1]):
                                k += 2
                            type_name = ts[k - 1].text.lower()
                            if type_name.startswith(b"p") and type_name not in class_names:
                                other_typed.update(names)
            i += 1
    return class_typed, other_typed


def collect_class_vars(sources, class_names, fields_only=False):
    return collect_typed_names(sources, class_names, fields_only=fields_only)[0]


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


def caret_removals(data, class_names, field_vars):
    ts = tokens(data)
    local_class, local_other = collect_typed_names([data], class_names, fields_only=False)
    names = (field_vars | local_class) - local_other
    return [
        (tok.start, tok.end, b"")
        for i, tok in enumerate(ts)
        if tok.text == b"^" and caret_is_class_deref(ts, i, class_names, names)
    ]


def rewrite(data, class_names, field_vars):
    edits = caret_removals(data, class_names, field_vars)
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
    field_vars = collect_class_vars(source_bytes, class_names, fields_only=True)
    return class_names, field_vars


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--types", nargs="+", required=True)
    parser.add_argument("--rewrite", nargs="+", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    targets = files(args.rewrite)
    if args.apply:
        checkpoints(targets)
    class_names, field_vars = prepare(args.types)
    plans = []
    for path in targets:
        original = path.read_bytes()
        converted, count = rewrite(original, class_names, field_vars)
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
        f"{len(class_names)} class names, {len(field_vars)} class fields; "
        f"{len(plans)} files {'changed' if args.apply else 'planned'}"
    )


if __name__ == "__main__":
    main()
