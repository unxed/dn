import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from class_carets import library_classes, collect_class_vars, rewrite


class ClassCaretsTest(unittest.TestCase):
    def convert(self, source, libraries=None):
        libs = libraries or [source]
        class_names = library_classes(libs)
        class_vars = collect_class_vars(libs, class_names)
        return rewrite(source, class_names, class_vars)[0]

    def test_removes_caret_after_class_field(self):
        source = (
            b"type TView = class\n"
            b"    Owner: TGroup;\n"
            b"  end;\n"
            b"  TGroup = class(TView)\n"
            b"  end;\n"
            b"begin\n"
            b"  Owner^.Redraw;\n"
            b"end.\n"
        )
        self.assertIn(b"Owner.Redraw", self.convert(source))
        self.assertNotIn(b"Owner^.", self.convert(source))

    def test_keeps_record_pointer_caret(self):
        source = (
            b"type TRec = record X: Integer; end;\n"
            b"  PRec = ^TRec;\n"
            b"  TView = class end;\n"
            b"var R: PRec;\n"
            b"begin\n"
            b"  R^.X := 1;\n"
            b"end.\n"
        )
        self.assertIn(b"R^.X", self.convert(source))

    def test_removes_caret_after_class_cast(self):
        source = (
            b"type TView = class end;\n"
            b"  PView = TView;\n"
            b"begin\n"
            b"  PView(Item)^.Draw;\n"
            b"  TView(Item)^.Draw;\n"
            b"end.\n"
        )
        out = self.convert(source)
        self.assertIn(b"PView(Item).Draw", out)
        self.assertIn(b"TView(Item).Draw", out)
        self.assertNotIn(b")^.", out)

    def test_keeps_record_cast_caret(self):
        source = (
            b"type TRec = record X: Integer; end;\n"
            b"  PRec = ^TRec;\n"
            b"  TView = class end;\n"
            b"begin\n"
            b"  PRec(Item)^.X := 1;\n"
            b"end.\n"
        )
        self.assertIn(b"PRec(Item)^.X", self.convert(source))

    def test_with_class_reference(self):
        source = (
            b"type TView = class\n"
            b"    Panel: TView;\n"
            b"  end;\n"
            b"begin\n"
            b"  with Panel^ do Draw;\n"
            b"end.\n"
        )
        self.assertIn(b"with Panel do", self.convert(source))

    def test_preserves_comments_and_strings(self):
        source = (
            b"type TView = class\n"
            b"    Owner: TGroup;\n"
            b"  end;\n"
            b"  TGroup = class(TView) end;\n"
            b"begin\n"
            b"  { Owner^.Redraw }\n"
            b"  S := 'Owner^.Redraw';\n"
            b"  Owner^.Redraw;\n"
            b"end.\n"
        )
        out = self.convert(source)
        self.assertIn(b"{ Owner^.Redraw }", out)
        self.assertIn(b"'Owner^.Redraw'", out)
        self.assertIn(b"Owner.Redraw;", out)

    def test_alias_typed_variable(self):
        source = (
            b"type TFilesCollection = class end;\n"
            b"  PFilesCollection = TFilesCollection;\n"
            b"var Files: PFilesCollection;\n"
            b"begin\n"
            b"  if Files^.Count > 0 then;\n"
            b"end.\n"
        )
        self.assertIn(b"Files.Count", self.convert(source))


if __name__ == "__main__":
    unittest.main()
