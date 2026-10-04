import importlib.util
import unittest
from pathlib import Path


MODULE = Path(__file__).parents[1] / "source_encoding.py"
spec = importlib.util.spec_from_file_location("source_encoding", MODULE)
source_encoding = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_encoding)


class SourceEncodingTests(unittest.TestCase):
    def test_classify_utf8_and_cp866(self):
        self.assertEqual(source_encoding.classify("Привет\n".encode("utf-8")), "utf8")
        self.assertEqual(source_encoding.classify("Привет\n".encode("cp866")), "cp866")

    def test_classify_rejects_binary(self):
        self.assertEqual(source_encoding.classify(b"abc\x00def"), "binary")

    def test_conversion_preserves_line_endings(self):
        import tempfile

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sample.pas"
            path.write_bytes("строка\r\nрамка ┌─┐\r\n".encode("cp866"))
            source_encoding.convert(path, "cp866")
            self.assertEqual(
                path.read_bytes(), "строка\r\nрамка ┌─┐\r\n".encode("utf-8")
            )


if __name__ == "__main__":
    unittest.main()
