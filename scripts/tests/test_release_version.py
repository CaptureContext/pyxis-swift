import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_version import Version, next_release


class ReleaseVersionTests(unittest.TestCase):
    def test_first_release_uses_zero(self):
        for bump, expected in [("patch", "0.0.1"), ("minor", "0.1.0"), ("major", "1.0.0")]:
            with self.subTest(bump=bump):
                previous, version = next_release([], bump)
                self.assertEqual(str(previous), "0.0.0")
                self.assertEqual(str(version), expected)

    def test_bumps_reset_lower_components(self):
        for bump, expected in [("patch", "1.2.4"), ("minor", "1.3.0"), ("major", "2.0.0")]:
            with self.subTest(bump=bump):
                self.assertEqual(str(next_release(["1.2.3"], bump)[1]), expected)

    def test_latest_is_numeric_not_lexical_or_input_order(self):
        previous, version = next_release(["1.10.2", "1.9.99", "1.10.10", "1.10.9"], "patch")
        self.assertEqual(str(previous), "1.10.10")
        self.assertEqual(str(version), "1.10.11")

    def test_ignores_noncanonical_and_prerelease_tags(self):
        invalid = ["v9.0.0", "9.0.0-alpha-1", "9.0.0-beta-2", "01.0.0", "1.00.0", "1.0.01", "9.0", "9.0.0+build", "9.0.0\n", "９.0.0", "topic", ""]
        for tag in invalid:
            with self.subTest(tag=tag):
                self.assertIsNone(Version.parse(tag))
        self.assertEqual(str(next_release(invalid + ["1.0.0"], "patch")[1]), "1.0.1")

    def test_prerelease_bumps_are_not_supported(self):
        for bump in ["alpha", "beta", "other"]:
            with self.assertRaises(ValueError):
                next_release([], bump)

    def test_cli_reads_all_tags_and_only_writes_outputs(self):
        script = Path(__file__).resolve().parents[1] / "release_version.py"
        with tempfile.TemporaryDirectory() as directory:
            env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull}
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=directory, env=env, text=True).strip()
            git("init", "--quiet")
            git("-c", "user.name=Test", "-c", "user.email=test@example.test", "commit", "--quiet", "--allow-empty", "-m", "fixture")
            git("tag", "1.9.0")
            git("tag", "1.10.0")
            output = Path(directory) / "output"
            before = git("tag", "--list")
            subprocess.run([sys.executable, str(script), "--bump", "minor", "--github-output", str(output)], cwd=directory, env=env, check=True, capture_output=True)
            self.assertEqual(output.read_text(), "previous_tag=1.10.0\ntag=1.11.0\n")
            self.assertEqual(git("tag", "--list"), before)


if __name__ == "__main__":
    unittest.main()
