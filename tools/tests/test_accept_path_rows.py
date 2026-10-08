"""Rows that differ only in how a path is written do not fail the object-vs-class gate (dn#23)."""
import importlib.util
import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, TOOLS)
_spec = importlib.util.spec_from_file_location('dn_linux_accept', os.path.join(TOOLS, 'dn-linux-accept.py'))
accept = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(accept)

ATTR = 0x1F
OTHER = 0x2E


def snap(rows, attr=ATTR):
    cells = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            cells.append((y, x, ch, attr))
    return {'alive': True, 'status': None, 'cursor': (0, 0, True), 'cells': cells, 'text': '\n'.join(rows)}


class PathNotationRows(unittest.TestCase):
    OBJECT = ['menu', '\u2554\u2550\u2550\u2550 C:\\tmp\\x \u2550\u2550\u2550\u2557', 'files']
    CLASS = ['menu', '\u2554\u2550\u2550\u2550\u2550 /tmp/x \u2550\u2550\u2550\u2550\u2557', 'files']

    def test_same_title_in_two_notations_passes(self):
        self.assertEqual(accept.diff_snaps(snap(self.OBJECT), snap(self.CLASS)), [])

    def test_a_changed_word_still_fails(self):
        changed = list(self.CLASS)
        changed[2] = 'filez'
        msgs = accept.diff_snaps(snap(self.OBJECT), snap(changed))
        self.assertTrue(msgs and msgs[0].startswith('cells differ'), msgs)

    def test_a_different_path_still_fails(self):
        other = list(self.CLASS)
        other[1] = '\u2554\u2550\u2550\u2550\u2550 /tmp/y \u2550\u2550\u2550\u2550\u2557'
        msgs = accept.diff_snaps(snap(self.OBJECT), snap(other))
        self.assertTrue(msgs and msgs[0].startswith('cells differ'), msgs)

    def test_a_changed_colour_on_the_title_still_fails(self):
        object_snap = snap(self.OBJECT)
        class_snap = snap(self.CLASS)
        class_snap['cells'] = [(y, x, ch, OTHER if y == 1 else attr) for y, x, ch, attr in class_snap['cells']]
        msgs = accept.diff_snaps(object_snap, class_snap)
        self.assertTrue(msgs and msgs[0].startswith('cells differ'), msgs)

    def test_identical_rows_are_not_touched(self):
        rows = ['menu', 'C:\\tmp', 'files']
        self.assertEqual(accept.path_notation_rows('\n'.join(rows), '\n'.join(rows), {}, {}), set())


if __name__ == '__main__':
    unittest.main()
