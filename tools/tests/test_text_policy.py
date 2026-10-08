"""Text policy of the repository (docs/TEXT-POLICY.md): English, UTF-8, no VP read.me, no Objects shim."""
import importlib.util
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
    r"^dn/archives/fmtain\.pas$",
    r"^dn/tests/t_(dnutf8|drivrs|zipcharset)\.pas$",
    r"^docs/ZIP-CHARSET\.md$",
    r"^docs/TEXT-POLICY\.md$",
    r"^tools/(fix-resource-lookalikes\.py|tests/test_(text_policy|to_codepage|audit_encoding)\.py)$",
    r"^docs/patches/",
    r"^tools/(dn-linux-(accept|far2l|locale|ops|sortmark)|dn-dos-input|test-zipcharset)\.py$",
    r"^tools/tests/test_source_encoding\.py$",
)
NOT_UTF8_OK = _rx(r"/xlt/")
INI = _rx(r"^dn/data/dn\.ini$")


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
        # dn/data/dn.ini is UTF-8; its comments must be free of Cyrillic
        bad = []
        for name, data in tracked_files():
            if not _any(INI, name):
                continue
            for number, line in enumerate(data.split(b"\n"), 1):
                try:
                    text = line.decode("utf-8")
                except UnicodeDecodeError:
                    text = line.decode("cp866", "replace")
                if line.lstrip().startswith(b";") and CYR.search(text):
                    bad.append("%s:%d" % (name, number))
        self.assertEqual(bad, [])

    def test_no_single_byte_glyphs_in_code(self):
        """A frame, a shade, a block or an arrow is a name of tv/src/tvglyphs.pas (glLightH, GlyphChar(glDblV) ...), not #196 or #$B3.
        The files below hold palettes (strings of palette indices that look like bytes), the tables of the code pages and the range checks of a key."""
        spec = importlib.util.spec_from_file_location("audit_encoding", ROOT / "tools/audit-encoding.py")
        audit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(audit)
        glyph = re.compile(r"#(17[6-9]|18[0-9]|19[0-9]|2[01][0-9]|22[0-3]|240|249|25[0-4])\b|#\$(B[0-9A-Fa-f]|[C-D][0-9A-Fa-f]|F0|F9|FA|FB|FC|FD|FE)\b", re.I)
        palettes = _rx(r"^dn/src/(calendar|dbview|dndlgs|fviewer|palettes|panelwin|pktview|uniwin)\.pas$",
                       r"^dn/src/(filepanel|keymap)\.pas$")              # range checks of a key, the tables of the code pages
        bad = []
        for name, data in tracked_files():
            if not re.match(r"^dn/(src|archives|compat)/.*\.(pas|inc)$", name) or _any(palettes, name):
                continue
            for number, line in enumerate(audit.code_only(data.decode("utf-8", "replace")).split("\n"), 1):
                if glyph.search(line):
                    bad.append("%s:%d: %s" % (name, number, line.strip()[:80]))
        self.assertEqual(bad, [], "a single-byte glyph: use a name of TvGlyphs")

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

    def test_resource_text_is_not_mojibake(self):
        """'Győr' was 'GyУr' in the Russian and Ukrainian resources (a one-byte code page could not keep it); the DOS build lands it (tools/to-codepage.py)."""
        for lang in ("english", "russian", "ukrain"):
            text = (ROOT / "dn/src/resource" / lang / "dn.dnl").read_text(encoding="utf-8")
            self.assertIn("(Győr)", text, lang)
            self.assertNotIn("GyУr", text, lang)

    def test_resource_words_are_in_one_script(self):
        """The old texts had Latin look-alikes in Cyrillic words (and back): tools/fix-resource-lookalikes.py repaired them once."""
        word = re.compile(r"[A-Za-z\u0400-\u04ff]+(?:~[A-Za-z\u0400-\u04ff]+)*")
        spec = re.compile(r"%[-0-9.*]*[A-Za-z]")
        kept = {"DN\u0443", "DN\u0430", "FAT\u0430"}      # an abbreviation and a Russian ending
        bad = []
        for lang in ("russian", "ukrain"):
            for name in ("dn.dnl", "dn.dnr", "dnhelp.htx"):
                text = spec.sub(" ", (ROOT / "dn/src/resource" / lang / name).read_text(encoding="utf-8"))
                for m in word.finditer(text):
                    w = m.group()
                    if CYR.search(w) and re.search("[A-Za-z]", w) and w not in kept:
                        bad.append("%s/%s: %s" % (lang, name, w))
        self.assertEqual(sorted(set(bad))[:20], [])
        for lang in ("ukrain",):
            text = (ROOT / "dn/src/resource" / lang / "dn.dnl").read_text(encoding="utf-8")
            self.assertNotIn("\u045e", text)           # the short u was the hack for the Ukrainian i


if __name__ == "__main__":
    unittest.main()
