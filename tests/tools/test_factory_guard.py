"""check.py's factory-content guard: no tracked build output, WAV or card image."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import check  # noqa: E402


def git(repo, *args):
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


def repo_with(files):
    """A repo with one commit holding `files`. They go straight into the index, as a commit can carry them even when
    .gitignore or a case-insensitive file system would stop them in a checkout (the spike's commit did)."""
    d = tempfile.TemporaryDirectory()
    repo = Path(d.name)
    git(repo, "init", "-q")
    blob = subprocess.run(["git", "-C", str(repo), "hash-object", "-w", "--stdin"], input=b"x", check=True,
                          capture_output=True).stdout.decode().strip()
    for name in files:
        git(repo, "update-index", "--add", "--cacheinfo", f"100644,{blob},{name}")
    git(repo, "-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-q", "-m", "test")
    return d, repo


class FactoryGuard(unittest.TestCase):
    def test_a_commit_adding_build_x_wav_fails(self):
        d, repo = repo_with(["README.md", "build/x.wav"])
        with d:
            self.assertEqual(check.factory_violations(repo), ["build/x.wav"])

    def test_wav_img_and_build_anywhere(self):
        # Build/ too: macOS's file system ignores case, so it is the same folder as build/.
        d, repo = repo_with(["tests/fixture.WAV", "cards/deluge_sd.img", "build/notes.txt", "Build/x.o", "engine/a.cpp"])
        with d:
            self.assertEqual(check.factory_violations(repo),
                             ["Build/x.o", "build/notes.txt", "cards/deluge_sd.img", "tests/fixture.WAV"])

    def test_clean_tree_passes(self):
        d, repo = repo_with(["engine/build.cpp", "tools/wav_stats.py", "docs/img/screen.png"])
        with d:
            self.assertEqual(check.factory_violations(repo), [])

    def test_this_repo_is_clean(self):
        self.assertEqual(check.factory_violations(ROOT), [])


if __name__ == "__main__":
    unittest.main()
