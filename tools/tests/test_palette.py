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

    def test_no_dull_pairs(self):
        # no entry is black on dark gray (0x80) or dark gray on black (0x08); the entry 224 was 08 (no view of DN maps to it: the
        # palettes of the views stop at 221, and the color dialog lists 1..221)
        table = ccolor()
        for i, a in enumerate(table, 1):
            self.assertNotIn(a, (0x80, 0x08), 'entry %d' % i)
        self.assertEqual(table[224 - 1], 0x07)

    def test_editor_keywords(self):
        # the entry 197 is "Keywords 1" of the highlight of the editor (CUniWindow of uniwin.pas): yellow on the dark gray of the editor
        self.assertEqual(ccolor()[197 - 1], 0x8E)

    def test_input_lines(self):
        # the text of an input line is white on black (0F), as on the reference screens of DN; its selected text and the history arrow are
        # the active color 3F (the dialog palette of tv3 maps the input line to 50..53); no white on light blue (9F) is left
        table = ccolor()
        self.assertEqual(table[50 - 1], 0x0F)
        self.assertEqual(table[51 - 1], 0x3F)
        self.assertEqual(table[53 - 1], 0x3F)
        self.assertNotIn(0x9F, table)

    def test_file_tail_is_not_colors(self):
        # after the table: the remembered places of the color dialog (LoadIndexes of dnutil.pas: a size byte and the record), then "VGAP";
        # the 08 bytes there (the offsets 235 and 242 of the file) are item numbers of that dialog, not colors
        pal = (ROOT / 'dn/data/colors/default.pal').read_bytes()
        n = pal[0]
        self.assertEqual(n, len(ccolor()))
        size = pal[1 + n]
        self.assertEqual(pal[1 + n + 1 + size:1 + n + 1 + size + 4], b'VGAP')


if __name__ == '__main__':
    unittest.main()
