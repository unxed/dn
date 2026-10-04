#!/usr/bin/env python3
"""Inspect and convert DN text sources without changing line endings.

The repository historically contains CP866 text next to UTF-8 text.  This
tool refuses to guess for files that are neither valid UTF-8 nor valid CP866.
It never touches binary files or paths outside the selected source roots.
"""

from __future__ import annotations

import argparse
from pathlib import Path


TEXT_SUFFIXES = {
    ".dnl", ".dnr", ".htx", ".inc", ".lpr", ".md", ".pas", ".pp", ".py",
    ".sh", ".txt",
}
DEFAULT_ROOTS = ("dn", "tv")
SKIP_PARTS = {".git", "build", "dist", "out", "__pycache__"}


def iter_files(root: Path):
    for base in DEFAULT_ROOTS:
        directory = root / base
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if (
                path.is_file()
                and path.suffix.lower() in TEXT_SUFFIXES
                and not (SKIP_PARTS & set(path.relative_to(root).parts))
            ):
                yield path


def classify(data: bytes) -> str:
    if b"\x00" in data:
        return "binary"
    try:
        data.decode("utf-8")
        return "utf8"
    except UnicodeDecodeError:
        try:
            data.decode("cp866")
            return "cp866"
        except UnicodeDecodeError:
            return "unknown"


def convert(path: Path, source: str) -> None:
    data = path.read_bytes()
    if source != "cp866":
        raise ValueError(f"{path}: expected cp866, got {source}")
    text = data.decode("cp866")
    path.write_bytes(text.encode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--convert", action="store_true")
    parser.add_argument("--only", choices=("cp866", "unknown", "all"))
    args = parser.parse_args()

    counts = {"utf8": 0, "cp866": 0, "binary": 0, "unknown": 0}
    failures = []
    for path in iter_files(args.root):
        kind = classify(path.read_bytes())
        counts[kind] += 1
        if kind == "unknown":
            failures.append(str(path.relative_to(args.root)))
        if args.convert and kind == "cp866" and args.only in (None, "cp866", "all"):
            convert(path, kind)
            print(f"converted cp866 -> utf8: {path.relative_to(args.root)}")
        elif not args.convert:
            print(f"{kind:7} {path.relative_to(args.root)}")

    print("summary:", " ".join(f"{k}={counts[k]}" for k in counts))
    if failures:
        print("unknown encoding:", *failures, sep="\n  ")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
