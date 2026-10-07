import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pty_screen import Screen


class StringSequenceTests(unittest.TestCase):
    def test_osc_apc_and_dcs_are_not_text(self):
        screen = Screen(30, 2)
        screen.feed(b'a\x1b]52;c;aGVsbG8=\x07b\x1b_far2l1\x1b\\c\x1bPq\x1b\\d')
        self.assertEqual(''.join(c for c, _ in screen.cells[0]).rstrip(), 'abcd')

    def test_a_string_split_between_reads_is_waited_for(self):
        screen = Screen(30, 2)
        screen.feed(b'x\x1b]52;c;aGVs')
        screen.feed(b'bG8=\x1b\\y')
        self.assertEqual(''.join(c for c, _ in screen.cells[0]).rstrip(), 'xy')


class AlternateScreenTests(unittest.TestCase):
    def test_1049_restores_primary_cells_attributes_and_cursor(self):
        screen = Screen(8, 3)
        screen.feed(b'\x1b[31;44mPRIMARY\x1b[2;4H')
        primary = (screen.cells, screen.x, screen.y, screen.attr, screen.cursor_visible)

        screen.feed(b'\x1b[?1049h')
        self.assertTrue(screen.alt)
        self.assertEqual(screen.cells, [[(' ', None)] * 8 for _ in range(3)])
        self.assertEqual((screen.x, screen.y, screen.attr), (0, 0, (None, None, 0)))

        screen.feed(b'\x1b[32mALT')
        screen.feed(b'\x1b[?1049l')

        self.assertFalse(screen.alt)
        self.assertEqual((screen.cells, screen.x, screen.y, screen.attr, screen.cursor_visible), primary)
        self.assertIsNone(screen.primary)

    def test_repeated_1049_transitions_do_not_replace_saved_primary(self):
        screen = Screen(5, 2)
        screen.feed(b'base')
        primary = screen.cells

        screen.feed(b'\x1b[?1049h\x1b[?1049h')
        screen.feed(b'\x1b[?1049l\x1b[?1049l')

        self.assertEqual(screen.cells, primary)
        self.assertFalse(screen.alt)
        self.assertIsNone(screen.primary)


if __name__ == '__main__':
    unittest.main()
