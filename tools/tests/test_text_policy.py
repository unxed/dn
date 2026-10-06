"""Text policy of the repository (docs/TEXT-POLICY.md): English, UTF-8, no VP read.me, no Objects shim."""
import os
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CYR = re.compile("[\u0400-\u04ff]")


def _rx(*patterns):
    return [re.compile(p) for p in patterns]


# docs/TEXT-POLICY.md: keep the two lists and the document in sync.
CYRILLIC_OK = _rx(
    r"^dn/src/resource/(russian|ukrain)/",
    r"^dist/[^/]+/screenshots/viewer\.txt$",
    r"^dn/archives/fmtain\.pas$",
    r"^dn/tests/t_(dnutf8|drivrs|zipcharset)\.pas$",
    r"^docs/ZIP-CHARSET\.md$",
    r"^docs/patches/",
    r"^tools/(dn-linux-(accept|far2l|locale|ops)|test-zipcharset)\.py$",
    r"^tools/tests/test_source_encoding\.py$",
)
NOT_UTF8_OK = _rx(r"/xlt/", r"^dn/data/dn\.ini$", r"^dist/[^/]+/dn\.ini$")
INI = _rx(r"^dn/data/dn\.ini$", r"^dist/[^/]+/dn\.ini$")


def _any(rxs, path):
    return any(r.search(path) for r in rxs)


def tracked_files():
    out = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
    for name in out.decode("utf-8").split("\0"):
        if name and (ROOT / name).is_file():  # a submodule (tv/) is a directory
            yield name, (ROOT / name).read_bytes()


class TextPolicyTests(unittest.TestCase):
    def test_text_files_are_utf8(self):
        bad = []
        for name, data in tracked_files():
            if b"\0" in data or _any(NOT_UTF8_OK, name):
                continue
            try:
                data.decode("utf-8")
            except UnicodeDecodeError:
                bad.append(name)
        self.assertEqual(bad, [], "not UTF-8 (CP866?); convert or add to docs/TEXT-POLICY.md")

    def test_cyrillic_only_where_allowed(self):
        bad = []
        for name, data in tracked_files():
            if b"\0" in data or _any(NOT_UTF8_OK, name) or _any(CYRILLIC_OK, name):
                continue
            if CYR.search(data.decode("utf-8", "replace")):
                bad.append(name)
        self.assertEqual(bad, [], "Cyrillic outside docs/TEXT-POLICY.md")

    def test_ini_comments_are_english(self):
        # dn.ini holds CP437 glyph bytes in values, so it is read as CP866 here; comments must be ASCII-clean of Cyrillic
        bad = []
        for name, data in tracked_files():
            if not _any(INI, name):
                continue
            for number, line in enumerate(data.split(b"\n"), 1):
                if line.lstrip().startswith(b";") and CYR.search(line.decode("cp866", "replace")):
                    bad.append("%s:%d" % (name, number))
        self.assertEqual(bad, [])

    def test_obsolete_vp_readme_is_gone(self):
        names = [n for n, _ in tracked_files()]
        self.assertNotIn("dn/src/read.me", names)
        self.assertNotIn("read.me", (ROOT / "bootstrap/run.sh").read_text(encoding="utf-8").lower())

    def test_no_objects_shim_and_no_unit_objects_in_uses(self):
        shims = (ROOT / "dn/compat/shims/shims.map").read_text(encoding="utf-8")
        self.assertFalse(re.search(r"(?mi)^_?objects\s*:", shims))
        uses_objects = re.compile(r"(?is)\buses\b[^;]*?[\s,]objects\s*[,;]")
        bad = []
        for name, data in tracked_files():
            if re.match(r"^dn/(src|archives|compat|lib|tests)/.*\.(pas|inc)$", name, re.I):
                if uses_objects.search(data.decode("utf-8", "replace")):
                    bad.append(name)
        self.assertEqual(bad, [])


if __name__ == "__main__":
    unittest.main()
