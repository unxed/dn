import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
GATE = TOOLS / 'class-gate.py'


class ClassGateTest(unittest.TestCase):
    def run_gate(self, files, env=None):
        with tempfile.TemporaryDirectory() as d:
            subprocess.run(['git', 'init', '-q', d], check=True)
            for name, text in files.items():
                p = Path(d, name)
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(text.encode('latin-1'))
            subprocess.run(['git', '-C', d, 'add', '-A'], check=True)
            e = dict(os.environ, CLASS_GATE_EXCLUDE='', CLASS_GATE_STRICT='')
            e.update(env or {})
            r = subprocess.run([sys.executable, str(GATE), d], capture_output=True, text=True, env=e)
            return r.returncode, r.stdout + r.stderr

    def test_object_type_is_found_with_line(self):
        rc, out = self.run_gate({'a.pas': 'type\r\n  TA = object(TView)\r\n  end;\r\n'})
        self.assertEqual(rc, 1)
        self.assertIn('a.pas:2:', out)

    def test_packed_and_any_case(self):
        self.assertEqual(self.run_gate({'a.pas': 'type TA = packed OBJECT end;'})[0], 1)
        self.assertEqual(self.run_gate({'a.inc': 'type TA = Object end;'})[0], 1)

    def test_class_code_passes(self):
        src = 'type TFindObject = class(TObject) end;\nvar E: TObject; begin ExceptObject; ObjChangeType(1) end.'
        self.assertEqual(self.run_gate({'a.pas': src})[0], 0)

    def test_comments_and_strings_are_not_looked_at(self):
        src = ("{ TMenuBar object }\n(* the object era\n object *)\n// an object\n"
               "begin Writeln('Cannot write object #', 1); Writeln('it''s an object'); end.\n")
        self.assertEqual(self.run_gate({'a.pas': src})[0], 0)

    def test_code_after_a_comment_and_a_string_is_still_checked(self):
        src = "begin { c } Writeln('x'); end;\ntype T = object end;\n"
        rc, out = self.run_gate({'a.pas': src})
        self.assertEqual(rc, 1)
        self.assertIn('a.pas:2:', out)

    def test_non_pascal_files_are_not_looked_at(self):
        self.assertEqual(self.run_gate({'a.md': 'object', 'b.py': 'object', 'c.rw': 'T = object(TView)'})[0], 0)

    def test_bootstrap_is_included_by_default_and_can_be_excluded_explicitly(self):
        f = {'bootstrap/new/a.pas': 'type T = object end;', 'dn/src/b.pas': 'type T = class end;'}
        self.assertEqual(self.run_gate(f)[0], 1)
        self.assertEqual(self.run_gate(f, {'CLASS_GATE_EXCLUDE': 'bootstrap/'})[0], 0)

    def test_old_construction_is_a_note_unless_strict(self):
        f = {'a.pas': 'begin D := New(TDialog, Init(R, S)); Dispose(D, Done); end.'}
        rc, out = self.run_gate(f)
        self.assertEqual(rc, 0)
        self.assertIn('not blocking', out)
        self.assertEqual(self.run_gate(f, {'CLASS_GATE_STRICT': '1'})[0], 1)

    def test_not_a_git_tree_is_an_error(self):
        with tempfile.TemporaryDirectory() as d:
            r = subprocess.run([sys.executable, str(GATE), d], capture_output=True, text=True)
            self.assertEqual(r.returncode, 2)

    def test_this_repository_passes(self):
        r = subprocess.run([sys.executable, str(GATE), str(TOOLS.parent)], capture_output=True, text=True,
                           env=dict(os.environ, CLASS_GATE_EXCLUDE='', CLASS_GATE_STRICT=''))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == '__main__':
    unittest.main()
