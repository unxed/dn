#!/usr/bin/env python3
"""The table of the sort order of DN for the code page 1125 (Ukrainian): dn/data/xlt/sort1125.xlt (tools/gen-sort1125.py [--check]).

sort866.xlt is a list of lines "BK" (the byte B of the page and its sort key K, both bytes): the letters of the two cases have one key, and a name is
sorted by the keys of its bytes. The table for 866 puts Ukrainian letters among the Russian ones as the cp866 positions give them (and has no Ґ and І). The code page 1125
has Ґ ґ І і Ї ї Є є at other positions, so this table is made by the alphabet: А Б В Г Ґ Д Е Ё Є Ж З И І Ї Й К Л М Н О П Р С Т У Ў Ф Х Ц Ч Ш Щ Ъ Ы Ь Э Ю Я.
The Latin part and the two signs (№ ¤) are those of sort866.xlt. --check: the file on the disk is what this script makes (exit status 1 if it is not).
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "dn/data/xlt/sort866.xlt"
DST = ROOT / "dn/data/xlt/sort1125.xlt"
ALPHABET = "АБВГҐДЕЁЄЖЗИІЇЙКЛМНОПРСТУЎФХЦЧШЩЪЫЬЭЮЯ"
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
                continue                                                      # the page has no such letter (Ў)
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
