#!/usr/bin/env python3
"""The table of the sort order of DN for the code page 1125 (Ukrainian): dn/data/xlt/sort1125.xlt (tools/gen-sort1125.py [--check]).

sort866.xlt is a list of lines "BK" (the byte B of the page and its sort key K, both bytes): the letters of the two cases have one key, and a name is
sorted by the keys of its bytes. The table for 866 puts Ukrainian letters among the Russian ones as the cp866 positions give them (and has no Ghe with upturn and Ukrainian I). The code page 1125
has the letters Ghe with upturn, Ukrainian I, Yi and Ie at other positions, so this table is made by the alphabet (ALPHABET below: Ghe with upturn after Ghe, Ukrainian Ie after Russian Io, I and Yi before Short I).
The Latin part and the two signs (№ ¤) are those of sort866.xlt. --check: the file on the disk is what this script makes (exit status 1 if it is not).
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "dn/data/xlt/sort866.xlt"
DST = ROOT / "dn/data/xlt/sort1125.xlt"
# the capital letters of the alphabet of DN for this page, by code point (U+0490 is the Ukrainian Ghe with upturn, U+0404 Ie, U+0406 and U+0407 the Ukrainian I and Yi)
ALPHABET = "".join(chr(c) for c in (
    0x410, 0x411, 0x412, 0x413, 0x490, 0x414, 0x415, 0x401, 0x404, 0x416, 0x417, 0x418, 0x406, 0x407, 0x419, 0x41A, 0x41B, 0x41C, 0x41D, 0x41E, 0x41F,
    0x420, 0x421, 0x422, 0x423, 0x40E, 0x424, 0x425, 0x426, 0x427, 0x428, 0x429, 0x42A, 0x42B, 0x42C, 0x42D, 0x42E, 0x42F))
BASE = 0x80


def make():
    lines = [l for l in SRC.read_bytes().split(b"\r\n") if len(l) == 2]
    keep = [l for l in lines if l[0] < 0x80 or l[0] in (0xFC, 0xFD)]       # Latin and the signs
    cyr = []
    for index, upper in enumerate(ALPHABET):
        for ch in (upper, upper.lower()):
            try:
                byte = ch.encode("cp1125")[0]
            except UnicodeEncodeError:
                continue                                                      # the page has no such letter (Short U)
            cyr.append(bytes([byte, BASE + index]))
    cyr.sort()
    return b"".join(l + b"\r\n" for l in keep + cyr)


if __name__ == "__main__":
    data = make()
    if "--check" in sys.argv:
        ok = DST.is_file() and DST.read_bytes() == data
        print("sort1125.xlt:", "up to date" if ok else "differs from what tools/gen-sort1125.py makes")
        sys.exit(0 if ok else 1)
    DST.write_bytes(data)
    print("wrote", DST, len(data), "bytes")
