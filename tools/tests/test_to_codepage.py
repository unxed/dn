"""tools/to-codepage.py: the landing of UTF-8 texts on a code page (the DOS build)."""
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('to_codepage', ROOT / 'tools' / 'to-codepage.py')
tc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tc)


class LandTest(unittest.TestCase):
    def test_representable_is_kept(self):
        data, lost = tc.land('Привет, Гомель', 'cp866')
        self.assertEqual(data, 'Привет, Гомель'.encode('cp866'))
        self.assertEqual(lost, {})

    def test_marks_are_dropped_not_replaced_by_another_letter(self):
        data, lost = tc.land('Győr', 'cp866')
        self.assertEqual(data, b'Gyor')
        self.assertEqual(lost, {'\u0151': 1})

    def test_stroked_letter_gets_the_placeholder(self):
        data, lost = tc.land('ł', 'cp866')
        self.assertEqual(data, b'?')
        self.assertEqual(lost, {'ł': 1})

    def test_fallback_signs(self):
        data, _ = tc.land('\u2261 \u2022 \u2219', 'cp866')
        self.assertEqual(data, b'= * \xf9')   # the bullet U+2219 is in cp866: it is kept

    def test_unknown_char_is_a_question_mark(self):
        data, lost = tc.land('a中b', 'cp866')
        self.assertEqual(data, b'a?b')
        self.assertEqual(lost, {'中': 1})

    def test_ascii_and_line_ends_are_not_touched(self):
        src = 'one\r\ntwo\x1b[0m\x00\n'
        self.assertEqual(tc.land(src, 'cp866')[0], src.encode('ascii'))


class CommandTest(unittest.TestCase):
    def run_tool(self, content):
        with tempfile.TemporaryDirectory() as d:
            a, b = Path(d, 'in'), Path(d, 'out')
            a.write_bytes(content)
            r = subprocess.run([sys.executable, str(ROOT / 'tools' / 'to-codepage.py'), 'cp866', str(a), str(b)], capture_output=True, text=True)
            return r, (b.read_bytes() if b.exists() else None)

    def test_reports_the_lost_characters(self):
        r, out = self.run_tool('Győr'.encode('utf-8'))
        self.assertEqual((r.returncode, out), (0, b'Gyor'))
        self.assertIn('U+0151', r.stderr)

    def test_not_utf8_is_an_error(self):
        r, out = self.run_tool('Привет'.encode('cp866'))
        self.assertEqual(r.returncode, 1)
        self.assertIsNone(out)


if __name__ == '__main__':
    unittest.main()
