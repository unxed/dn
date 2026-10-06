"""tools/audit-encoding.py: the integrity checks and the comparison of an old text with a new one."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("audit_encoding", ROOT / "tools/audit-encoding.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AuditEncodingTests(unittest.TestCase):
    def test_code_only_drops_comments_keeps_strings(self):
        text = "x := 'a{b'; { комментарий }\n(* и ещё\n   'так' *) y := '─'; // хвост\n"
        code = audit.code_only(text)
        self.assertIn("'a{b'", code)
        self.assertIn("'─'", code)
        self.assertNotIn("комментарий", code)
        self.assertNotIn("хвост", code)
        self.assertNotIn("так", code)

    def test_lost_characters(self):
        self.assertEqual(audit.lost_characters("a─b", "a─b"), [])
        report = audit.lost_characters("MoveChar(B, '─')", "MoveChar(B, #$C4)")
        self.assertEqual([(c, n) for c, n, _ in report], [("─", 1)])
        self.assertEqual(audit.lost_characters("Ж", "", skip_cyrillic=True), [])

    def test_integrity_finds_damage(self):
        files = [("a.pas", "ok ─".encode()), ("b.pas", b"bad \xc4"), ("c.pas", "lost �".encode()),
                 ("d.pas", "c1 \u0085".encode()), ("dn/data/xlt/x.pas", b"\xc4\xc4")]
        names = sorted(p.split(":")[0] for p in audit.integrity(files))
        self.assertEqual(names, ["b.pas", "c.pas", "d.pas"])

    def test_tree_is_intact(self):
        self.assertEqual(audit.integrity(list(audit.tracked())), [])


if __name__ == "__main__":
    unittest.main()
