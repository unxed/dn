#!/usr/bin/env python3
"""ZIP charset fixture + assertion (separate from tools/dn-linux-archives.py).

Builds a small ZIP with a CP866 OEM filename (FAT creator), then checks
github.com/unxed/zipcharset DecodeText matches UTF-8 «привет.txt» when OEM is
forced to CP866 (docs/ZIP-CHARSET.md lock).

Writes tools/testdata/zipcharset/cp866-privet.zip for manual DN listing.

usage:
  python3 tools/test-zipcharset.py
  DN_ZIPCHARSET_SKIP_GO=1 python3 tools/test-zipcharset.py   # fixture only
"""
from __future__ import annotations

import os
import struct
import subprocess
import sys
import tempfile
import zipfile
import zlib

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(HERE, "tools", "testdata", "zipcharset")
# "привет.txt" in CP866
CP866_NAME = bytes([0xAF, 0xE0, 0xA8, 0xA2, 0xA5, 0xE2, 0x2E, 0x74, 0x78, 0x74])
EXPECTED = "привет.txt"


def write_fat_oem_zip(path: str, name_bytes: bytes, payload: bytes = b"hi\n") -> None:
    """Minimal stored ZIP: FAT creator (OS=0), no UTF-8 flag, OEM name bytes."""
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    local = struct.pack(
        "<IHHHHHIIIHH",
        0x04034B50,
        20,
        0,
        0,
        0,
        0,
        crc,
        len(payload),
        len(payload),
        len(name_bytes),
        0,
    )
    # version made = 0x0014 (FAT/0, ver 20) → OEM in zipcharset
    central = struct.pack(
        "<IHHHHHHIIIHHHHHII",
        0x02014B50,
        0x0014,
        20,
        0,
        0,
        0,
        0,
        crc,
        len(payload),
        len(payload),
        len(name_bytes),
        0,
        0,
        0,
        0,
        0,
        0,
    )
    end = struct.pack(
        "<IHHHHIIH",
        0x06054B50,
        0,
        0,
        1,
        1,
        len(central) + len(name_bytes),
        len(local) + len(name_bytes) + len(payload),
        0,
    )
    with open(path, "wb") as f:
        f.write(local)
        f.write(name_bytes)
        f.write(payload)
        f.write(central)
        f.write(name_bytes)
        f.write(end)


def check_with_go(zip_path: str) -> str:
    go_src = r"""
package main
import (
  "fmt"
  "os"
  "github.com/klauspost/compress/zip"
  "github.com/unxed/localecp"
  "github.com/unxed/zipcharset"
  "golang.org/x/text/encoding/charmap"
)
func main() {
  localecp.OEMDecoder = charmap.CodePage866.NewDecoder()
  localecp.ANSIDecoder = charmap.Windows1251.NewDecoder()
  f, err := os.Open(os.Args[1])
  if err != nil { panic(err) }
  defer f.Close()
  st, _ := f.Stat()
  zr, err := zip.NewReaderWithOptions(f, st.Size(), zip.ReaderOptions{
    NameDecoder: zipcharset.NewNameDecoder(),
  })
  if err != nil { panic(err) }
  if len(zr.File) < 1 { panic("empty") }
  fmt.Print(zr.File[0].Name)
}
"""
    with tempfile.TemporaryDirectory(prefix="dn-zipcharset-") as td:
        with open(os.path.join(td, "main.go"), "w", encoding="utf-8") as f:
            f.write(go_src)
        with open(os.path.join(td, "go.mod"), "w", encoding="utf-8") as f:
            f.write("module dnzipcharsettest\n\ngo 1.21\n")
        subprocess.check_call(
            ["go", "get", "github.com/unxed/zipcharset@latest"],
            cwd=td,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return subprocess.check_output(
            ["go", "run", ".", zip_path], cwd=td
        ).decode("utf-8")


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    zpath = os.path.join(OUT_DIR, "cp866-privet.zip")
    write_fat_oem_zip(zpath, CP866_NAME)

    with zipfile.ZipFile(zpath) as zf:
        _ = zf.namelist()[0]

    if os.environ.get("DN_ZIPCHARSET_SKIP_GO") == "1":
        print(f"OK fixture {zpath} (Go check skipped)")
        return 0

    try:
        got = check_with_go(zpath)
    except FileNotFoundError:
        print("SKIP: go not on PATH; fixture written:", zpath)
        return 0
    except subprocess.CalledProcessError as e:
        print("FAIL: go harness:", e)
        return 1

    if got != EXPECTED:
        print(f"FAIL: zipcharset got {got!r}, want {EXPECTED!r}")
        return 1
    print(f"OK {zpath}: zipcharset → {got!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
