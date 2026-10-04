import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from class_names import library_aliases, rewrite


class ClassNamesTests(unittest.TestCase):
    def convert(self, source, libraries=None):
        classes, shared = library_aliases(libraries or [source])
        return rewrite(source, classes, shared)[0]

    def test_direct_class_alias(self):
        source = b'type TView=class; PView=TView; var V:PView; V:=PView.Create;'
        self.assertEqual(self.convert(source),
            b'type TView=class;  var V:TView; V:=TView.Create;')

    def test_pointer_to_class_alias(self):
        source = b'type TStream=class; PStream=^TStream; var S:PStream;'
        self.assertEqual(self.convert(source), b'type TStream=class;  var S:TStream;')

    def test_record_pointer_preserved(self):
        source = b'type TRec=record X:Integer; end; PRec=^TRec; var R:PRec;'
        self.assertEqual(self.convert(source), source)

    def test_local_record_alias_shadows_library_class_alias(self):
        lib = b'TView=class; PView=TView;'
        source = b'TRecord=record; PView=^TRecord; var V:PView;'
        self.assertEqual(self.convert(source, [lib]), source)

    def test_strings_and_comments_preserved(self):
        lib = b'TView=class; PView=TView;'
        source = b"PView.Create('PView''PView'); { PView { nested } } (* PView *) // PView\n"
        self.assertEqual(self.convert(source, [lib]),
            b"TView.Create('PView''PView'); { PView { nested } } (* PView *) // PView\n")

    def test_external_alias_and_case(self):
        lib = b'TView=class; PView=TView;'
        self.assertEqual(self.convert(b'var V:pVIEW;', [lib]), b'var V:TView;')

    def test_crlf_and_byte_encoding(self):
        source = b'type TView=class;\r\n  PView=TView;\r\n{\xff\xfe}\r\nvar V:PView;\r\n'
        self.assertEqual(self.convert(source),
            b'type TView=class;\r\n{\xff\xfe}\r\nvar V:TView;\r\n')

    def test_metaclass_preserved(self):
        source = b'TView=class; PFactory=class of TView;'
        self.assertEqual(self.convert(source), source)

    def test_local_class_alias(self):
        lib = b'TView=class; PView=TView;'
        source = b'TLocal=class; PLocal=TLocal; var X:PLocal;'
        self.assertEqual(self.convert(source, [lib]), b'TLocal=class;  var X:TLocal;')

    def test_unterminated_comment_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unterminated'):
            self.convert(b'TView=class; PView=TView; {')

    def test_ambiguous_alias_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            library_aliases([b'TA=class; PA=TA;', b'TB=class; PA=TB;'])


if __name__ == '__main__':
    unittest.main()
