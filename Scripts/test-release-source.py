"""Exercise release gates using disposable local Git repositories; never publish."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).resolve().parent.parent


class ReleaseSourceTests(unittest.TestCase):
    def run_command(self, *args, check=True):
        return subprocess.run(args, cwd=self.repo, check=check, capture_output=True, text=True)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = pathlib.Path(self.directory.name)
        self.repo = root / "repo"
        self.remote = root / "origin.git"
        self.repo.mkdir()
        self.run_command("git", "init", "--bare", str(self.remote))
        self.run_command("git", "init", "-b", "main")
        self.run_command("git", "config", "user.name", "Release Test")
        self.run_command("git", "config", "user.email", "release@example.invalid")
        (self.repo / "Scripts").mkdir()
        shutil.copy(SOURCE / "Scripts/check-release-source.sh", self.repo / "Scripts")
        shutil.copy(SOURCE / "Makefile", self.repo)
        (self.repo / ".gitignore").write_text("build/\n")
        self.run_command("git", "add", ".")
        self.run_command("git", "commit", "-m", "Initial")
        self.run_command("git", "remote", "add", "origin", str(self.remote))
        self.run_command("git", "push", "origin", "main")
        # Pretend the publisher is built, without compiling or running release code.
        for source in ("Sources/MeasurementCore/ReleaseChannel.swift",
                       "Sources/MeasurementCore/ReleaseFeed.swift", "Scripts/Publish/main.swift"):
            path = self.repo / source
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        self.run_command("git", "add", ".")
        self.run_command("git", "commit", "-m", "Build inputs")
        self.run_command("git", "push", "origin", "main")
        binary = self.repo / "build/tools/schnaps-release"
        binary.parent.mkdir(parents=True)
        binary.write_text('#!/bin/sh\necho "publisher-invoked $*"\n')
        binary.chmod(0o755)

    def guard(self, allowed=False):
        result = self.run_command("sh", "Scripts/check-release-source.sh", check=False)
        self.assertEqual(result.returncode == 0, allowed, result.stdout + result.stderr)

    def test_clean_main_and_make_targets(self):
        self.guard(allowed=True)
        for target, mode in (("beta", "beta"), ("release", "stable"), ("promote", "promote")):
            self.assertIn(f"publisher-invoked {mode} --plan", self.run_command("make", target, "ARGS=--plan").stdout)

    def test_feature_and_detached_heads(self):
        self.run_command("git", "switch", "-c", "feature")
        self.guard()
        for target in ("beta", "release", "promote"):
            for args in ("", "--plan", "--resume 1.0.0"):
                result = self.run_command("make", target, "ARGS=" + args, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("publisher-invoked", result.stdout)
        self.assertIn("publisher-invoked", self.run_command("make", "plan-beta").stdout)
        self.run_command("git", "checkout", "--detach")
        self.guard()

    def test_edits_staged_and_untracked(self):
        path = self.repo / "Makefile"
        original = path.read_text()
        path.write_text(original + "\n# edit\n")
        self.guard()
        self.run_command("git", "add", "Makefile")
        self.guard()
        self.run_command("git", "reset", "--hard", "HEAD")
        (self.repo / "untracked").write_text("edit")
        self.guard()

    def test_ahead_behind_and_diverged(self):
        self.run_command("git", "commit", "--allow-empty", "-m", "Local commit")
        self.guard()
        self.run_command("git", "push", "origin", "main")
        self.run_command("git", "reset", "--hard", "HEAD~1")
        # origin/main's local tracking ref is stale on purpose.
        self.run_command("git", "update-ref", "refs/remotes/origin/main", "HEAD")
        self.guard()
        self.run_command("git", "commit", "--allow-empty", "-m", "Diverged commit")
        self.guard()

    def test_missing_remote_branch_and_unreachable_remote(self):
        self.run_command("git", "--git-dir=" + str(self.remote), "update-ref", "-d", "refs/heads/main")
        self.guard()
        self.run_command("git", "remote", "set-url", "origin", str(self.remote / "missing"))
        self.guard()


if __name__ == "__main__":
    unittest.main()
