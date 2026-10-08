"""The built-in palette of DN: dn/data/colors/default.pal is the table CColor of dn/src/palettes.pas, and its entries stay readable."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def ccolor():
    text = (ROOT / 'dn/src/palettes.pas').read_text(encoding='utf-8')
    body = re.search(r'\n  CColor =(.*?);', text, re.S).group(1)
    return bytes(int(x, 16) for x in re.findall(r'#\$([0-9A-Fa-f]{2})', body))


class PaletteTests(unittest.TestCase):
    def test_file_is_the_constant(self):
        # the file has one byte of a header in front of the table
        pal = (ROOT / 'dn/data/colors/default.pal').read_bytes()
        table = ccolor()
        self.assertEqual(pal[1:1 + len(table)], table)

    def test_highlight_groups_are_readable(self):
        # the entries 192..196 (1-based) are the colors of the five additional highlight groups of the file panel (panelwin.pas, #192..#196);
        # they stand on the dark gray background of the panel: black (0x80) and dark blue (0x81) on it are not readable
        table = ccolor()
        for i in range(192, 197):
            self.assertNotIn(table[i - 1], (0x80, 0x81), 'entry %d' % i)
            self.assertNotEqual(table[i - 1] >> 4, table[i - 1] & 15, 'entry %d: the same color for text and background' % i)


if __name__ == '__main__':
    unittest.main()
