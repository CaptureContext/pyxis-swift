import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class ReleasePublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "work"
        self.repo.mkdir()
        self.env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull}
        subprocess.run(["git", "init", "--bare", "--quiet", str(self.root / "origin.git")], check=True, env=self.env)
        self.git("init", "--quiet")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.test")
        self.git("commit", "--quiet", "--allow-empty", "-m", "fixture")
        self.git("branch", "-M", "main")
        self.git("remote", "add", "origin", str(self.root / "origin.git"))
        self.git("push", "--quiet", "origin", "main")
        self.sha = self.git("rev-parse", "HEAD")
        self.asset = self.root / "pyxis-example.pyx"
        self.asset.write_bytes(b"validated fixture placeholder")
        self.state = self.root / "gh-state.json"
        self.state.write_text(json.dumps({"release": None, "calls": []}))
        binary = self.root / "bin"
        binary.mkdir()
        gh = binary / "gh"
        gh.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
path = Path(os.environ['FAKE_GH_STATE'])
state = json.loads(path.read_text())
args = sys.argv[1:]
state['calls'].append(args)
command = args[1]
status = 0
if command == 'view':
    if state['release'] is None:
        status = 1
    else:
        print(str(state['release']['draft']).lower())
elif command == 'create':
    state['release'] = {'draft': True, 'asset': False}
elif command == 'upload':
    if os.environ.get('FAIL_UPLOAD'):
        status = 1
    else:
        state['release']['asset'] = True
elif command == 'edit':
    assert state['release']['asset'], 'Cannot publish without an asset'
    assert '--latest' in args and '--prerelease=false' in args
    state['release']['draft'] = False
else:
    raise AssertionError(args)
path.write_text(json.dumps(state))
sys.exit(status)
''')
        gh.chmod(0o755)
        self.env.update({"PATH": str(binary) + os.pathsep + os.environ["PATH"], "FAKE_GH_STATE": str(self.state), "GITHUB_REPOSITORY": "example/pyxis", "RELEASE_TAG": "0.0.1", "RELEASE_SHA": self.sha})

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, env=self.env, text=True, stderr=subprocess.PIPE).strip()

    def publish(self, **extra_env):
        script = Path(__file__).resolve().parents[1] / "publish_release.sh"
        return subprocess.run(["bash", str(script), str(self.asset)], cwd=self.repo, env={**self.env, **extra_env}, text=True, capture_output=True)

    def test_tags_exact_commit_and_uploads_before_publishing(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("rev-parse", "0.0.1^{commit}"), self.sha)
        self.assertEqual(self.git("cat-file", "-t", "refs/tags/0.0.1"), "tag")
        self.assertIn("refs/tags/0.0.1", self.git("ls-remote", "--tags", "origin"))
        state = json.loads(self.state.read_text())
        self.assertEqual([call[1] for call in state["calls"]], ["view", "create", "upload", "edit"])
        self.assertFalse(state["release"]["draft"])

    def test_failed_upload_stays_draft_and_retry_reuses_tag(self):
        self.assertNotEqual(self.publish(FAIL_UPLOAD="1").returncode, 0)
        tag = self.git("rev-parse", "0.0.1")
        self.assertTrue(json.loads(self.state.read_text())["release"]["draft"])
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("rev-parse", "0.0.1"), tag)
        state = json.loads(self.state.read_text())
        self.assertEqual(sum(call[1] == "create" for call in state["calls"]), 1)
        self.assertFalse(state["release"]["draft"])

    def test_does_not_overwrite_published_release(self):
        self.assertEqual(self.publish().returncode, 0)
        before = len(json.loads(self.state.read_text())["calls"])
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already published", result.stderr)
        self.assertEqual([call[1] for call in json.loads(self.state.read_text())["calls"][before:]], ["view"])

    def test_rejects_tag_at_different_commit(self):
        self.git("commit", "--quiet", "--allow-empty", "-m", "another commit")
        self.git("tag", "0.0.1")
        self.git("push", "--quiet", "origin", "refs/tags/0.0.1")
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("different commit", result.stderr)
        self.assertEqual(json.loads(self.state.read_text())["calls"], [])

    def test_missing_asset_does_not_create_tag(self):
        self.asset.unlink()
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.git("tag", "--list"), "")


if __name__ == "__main__":
    unittest.main()
