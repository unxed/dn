"""tools/check-platform.py: the platform boundary of DN."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("check_platform", ROOT / "tools/check-platform.py")
check_platform = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_platform)


class CheckPlatformTests(unittest.TestCase):
    def test_scan_ignores_comments_strings_and_keeps_directives(self):
        code, directives = check_platform.scan("uses A; { go32 } (* BaseUnix *) // Unix\nx := 'Windows'; {$IFDEF UNIX}\n")
        self.assertNotIn("go32", code)
        self.assertNotIn("BaseUnix", code)
        self.assertNotIn("Windows", code)
        self.assertEqual(directives, ["{$IFDEF UNIX}"])

    def test_tree_keeps_the_boundary(self):
        self.assertEqual(check_platform.check(), [])


if __name__ == "__main__":
    unittest.main()
