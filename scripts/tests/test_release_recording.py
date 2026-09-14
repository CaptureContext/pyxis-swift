import json
from pathlib import Path
import subprocess
import unittest


class ReleaseRecordingTests(unittest.TestCase):
    def test_ci_recording_preserves_authored_matrix_without_local_history(self):
        root = Path(__file__).resolve().parents[2]
        original = json.loads(subprocess.check_output([
            "ruby", "-rjson", "-ryaml", "-e",
            "puts JSON.generate(YAML.safe_load(File.read(ARGV.fetch(0))))",
            str(root / "Example/pyxis.yaml"),
        ], text=True))
        config = json.loads(subprocess.check_output([
            "ruby", str(root / "scripts/release_recording_config.rb"),
        ], cwd="/tmp", text=True))

        self.assertEqual(config["devices"], [{"name": "iPhone 17 Pro"}])
        self.assertNotIn("storage", config)
        self.assertIs(config["archive"], True)
        self.assertEqual(config["output"], str(root / ".generated/release/recordings"))
        self.assertEqual(config["derived_data"], str(root / ".generated/release/DerivedData"))
        self.assertEqual(config["xcode"].pop("workspace"), str(root / "Example/PyxisExample.xcworkspace"))
        original["xcode"].pop("workspace")
        for key in ["version", "variants", "coverage", "images", "xcode"]:
            with self.subTest(key=key):
                self.assertEqual(config[key], original[key])


if __name__ == "__main__":
    unittest.main()
