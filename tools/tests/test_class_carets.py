import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from class_carets import library_classes, collect_class_vars, rewrite


class ClassCaretsTest(unittest.TestCase):
    def convert(self, source, libraries=None):
        libs = libraries or [source]
        class_names = library_classes(libs)
        field_vars = collect_class_vars(libs, class_names, fields_only=True)
        return rewrite(source, class_names, field_vars)[0]

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

    def test_comma_field_list(self):
        source = (
            b"type TView = class\n"
            b"    InfoView, DriveLine, SortView: TView;\n"
            b"  end;\n"
            b"begin\n"
            b"  DriveLine^.Show;\n"
            b"  InfoView^.Show;\n"
            b"end.\n"
        )
        out = self.convert(source)
        self.assertIn(b"DriveLine.Show", out)
        self.assertIn(b"InfoView.Show", out)

    def test_foreign_param_name_does_not_mark_record_pointer(self):
        library = (
            b"type TView = class end;\n"
            b"procedure Helper(P: TView); begin end;\n"
        )
        source = (
            b"type TRec = record X: Integer; end;\n"
            b"  PRec = ^TRec;\n"
            b"  TView = class end;\n"
            b"var P: PRec;\n"
            b"begin\n"
            b"  P^.X := 1;\n"
            b"end.\n"
        )
        out = self.convert(source, libraries=[library, source])
        self.assertIn(b"P^.X", out)

    def test_same_unit_string_field_does_not_shadow_class_field(self):
        source = (
            b"type TView = class\n"
            b"    DriveLine: TView;\n"
            b"  end;\n"
            b"  TDriveLine = class(TView)\n"
            b"    DriveLine: String[29];\n"
            b"  end;\n"
            b"begin\n"
            b"  DriveLine^.Show;\n"
            b"end.\n"
        )
        self.assertIn(b"DriveLine.Show", self.convert(source))

    def test_local_record_pointer_shadows_class_field_name(self):
        library = (
            b"type TView = class\n"
            b"    P: TView;\n"
            b"  end;\n"
        )
        source = (
            b"type TRec = record X: Integer; end;\n"
            b"  PRec = ^TRec;\n"
            b"  TView = class\n"
            b"    P: TView;\n"
            b"  end;\n"
            b"var P: PRec;\n"
            b"begin\n"
            b"  P^.X := 1;\n"
            b"end.\n"
        )
        out = self.convert(source, libraries=[library, source])
        self.assertIn(b"P^.X", out)

    def test_assignment_is_not_a_declaration(self):
        source = (
            b"type TView = class\n"
            b"    Drive: TView;\n"
            b"  end;\n"
            b"begin\n"
            b"  Drive := nil;\n"
            b"  Drive^.Show;\n"
            b"end.\n"
        )
        self.assertIn(b"Drive.Show", self.convert(source))


if __name__ == "__main__":
    unittest.main()
