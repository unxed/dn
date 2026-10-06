"""dn/data/xlt/sort1125.xlt (tools/gen-sort1125.py): the sort order of the Ukrainian alphabet on the code page 1125."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("gen_sort1125", ROOT / "tools/gen-sort1125.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


def keys():
    table = {}
    for line in (ROOT / "dn/data/xlt/sort1125.xlt").read_bytes().split(b"\r\n"):
        if len(line) == 2:
            table[line[0]] = line[1]
    return table


def L(code):
    return chr(code)


def key(table, ch):
    return table[ch.encode("cp1125")[0]]


GHE, GHE_UP, DE = L(0x413), L(0x490), L(0x414)
IE, UK_IE, ZHE = L(0x415), L(0x404), L(0x416)
I_, UK_I, YI, SHORT_I = L(0x418), L(0x406), L(0x407), L(0x419)
ALL = [L(c) for c in list(range(0x410, 0x430)) + [0x401, 0x404, 0x406, 0x407, 0x490]]


class Sort1125Tests(unittest.TestCase):
    def test_file_is_what_the_script_makes(self):
        self.assertEqual((ROOT / "dn/data/xlt/sort1125.xlt").read_bytes(), gen.make())

    def test_both_cases_have_one_key(self):
        t = keys()
        for letter in ALL:
            self.assertEqual(key(t, letter), key(t, letter.lower()), letter)

    def test_ukrainian_letters_stand_where_the_alphabet_puts_them(self):
        t = keys()
        order = [key(t, c) for c in (GHE, GHE_UP, DE)]
        self.assertEqual(order, sorted(order))
        self.assertEqual(len(set(order)), 3)
        for a, b in ((IE, UK_IE), (UK_IE, ZHE), (I_, UK_I), (UK_I, YI), (YI, SHORT_I)):
            self.assertLess(key(t, a), key(t, b), "%04X %04X" % (ord(a), ord(b)))

    def test_latin_and_signs_are_those_of_sort866(self):
        t = keys()
        self.assertEqual(t[ord("a")], ord("A"))
        self.assertEqual(t[0xFC], 0x23)
        self.assertEqual(t[0xFD], 0x24)


if __name__ == "__main__":
    unittest.main()
