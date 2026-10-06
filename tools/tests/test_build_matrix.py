"""tools/build-matrix.sh: a target without its toolchain is reported UNAVAILABLE (never PASS) and does not fail the run unless DN_MATRIX_REQUIRE=1."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "build-matrix.sh"


def run(names, require=False):
    home = tempfile.mkdtemp(prefix="matrix-home-")            # an empty HOME: none of the cross compilers is there
    env = {"PATH": os.environ["PATH"], "HOME": home, "DN_MATRIX_OUT": os.path.join(home, "out")}
    for key in ("DN_LINUX", "DN_AARCH64", "DN_WIN", "DN_WIN32", "DN_PREFIX"):
        env.pop(key, None)
    if require:
        env["DN_MATRIX_REQUIRE"] = "1"
    return subprocess.run(["sh", str(SCRIPT)] + names, env=env, capture_output=True, text=True)


class BuildMatrixTests(unittest.TestCase):
    def test_missing_toolchains_are_unavailable_not_passed(self):
        r = run(["aarch64", "win64", "win32", "linux32", "dos"])
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        lines = [l for l in r.stdout.splitlines() if l.split()[:1] and l.split()[0] in ("aarch64", "win64", "win32", "linux32", "dos")]
        self.assertEqual(len(lines), 5)
        for line in lines:
            self.assertIn("UNAVAILABLE", line)
            self.assertNotIn("PASS", line)
        self.assertIn("5 unavailable", r.stdout)

    def test_require_makes_an_unavailable_target_fail(self):
        r = run(["aarch64"], require=True)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("1 failed", r.stdout)


if __name__ == "__main__":
    unittest.main()
