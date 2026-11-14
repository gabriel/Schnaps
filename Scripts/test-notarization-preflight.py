"""Exercise the real preflight with a fake notarytool; no Apple or Keychain access."""
import os
import pathlib
import subprocess
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).resolve().parent.parent


class NotarizationPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.directory.cleanup)
        cls.root = pathlib.Path(cls.directory.name)
        harness = cls.root / "main.swift"
        harness.write_text('''import Foundation
@main struct TestPreflight {
    static func main() {
        do {
            try NotarizationPreflight.validate(
                runner: Runner(root: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)),
                profile: "Test Profile")
        } catch {
            FileHandle.standardError.write(Data(error.localizedDescription.utf8))
            exit(1)
        }
    }
}
''')
        cls.binary = cls.root / "preflight"
        subprocess.run([
            "swiftc", "-swift-version", "6", "-parse-as-library",
            str(SOURCE / "Scripts/Publish/Preflight.swift"), str(harness), "-o", str(cls.binary),
        ], check=True, capture_output=True, text=True)
        command = cls.root / "xcrun"
        command.write_text('''#!/usr/bin/python3
import os
import sys
assert sys.argv[1:] == ["notarytool", "history", "--keychain-profile", "Test Profile", "--output-format", "json"]
sys.stdout.write(os.environ.get("NOTARY_STDOUT", ""))
sys.stdout.flush()
sys.stderr.write(os.environ.get("NOTARY_STDERR", ""))
sys.exit(int(os.environ.get("NOTARY_STATUS", "0")))
''')
        command.chmod(0o755)

    def preflight(self, diagnostic="", status=1, stdout=""):
        environment = dict(os.environ, PATH=str(self.root) + os.pathsep + os.environ["PATH"],
                           NOTARY_STDERR=diagnostic, NOTARY_STDOUT=stdout, NOTARY_STATUS=str(status))
        return subprocess.run([str(self.binary)], env=environment, cwd=self.root,
                              capture_output=True, text=True, timeout=15)

    def test_success(self):
        result = self.preflight(status=0, stdout='{"history": []}')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout + result.stderr, "")

    def test_agreement_failure(self):
        for diagnostic in (
            "Error: HTTP status code: 403. A required agreement is missing or has expired.",
            "This request requires an in-effect agreement that has not been signed or has expired.",
            "FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED",
        ):
            with self.subTest(diagnostic=diagnostic):
                result = self.preflight(diagnostic)
                self.assertEqual(result.returncode, 1)
                self.assertIn("Account Holder", result.stderr)
                self.assertIn("https://developer.apple.com/account/", result.stderr)
                self.assertIn(diagnostic, result.stderr)
                self.assertNotIn("profile 'Test Profile' is unavailable", result.stderr)

    def test_missing_profile(self):
        diagnostic = "Error: No Keychain password item found for profile: Test Profile"
        result = self.preflight(diagnostic)
        self.assertEqual(result.returncode, 1)
        self.assertIn("SCHNAPS_NOTARY_PROFILE", result.stderr)
        self.assertIn(diagnostic, result.stderr)

    def test_other_failures(self):
        for diagnostic in (
            "Error: HTTP status code: 401. Invalid credentials.",
            "Error: HTTP status code: 403. Access denied.",
            "Error: HTTP status code: 503. Service unavailable.",
            "Error: The Internet connection appears to be offline.",
            "xcrun: error: unable to find utility notarytool",
            "",
        ):
            with self.subTest(diagnostic=diagnostic):
                result = self.preflight(diagnostic)
                self.assertEqual(result.returncode, 1)
                self.assertIn("Could not validate notarization access", result.stderr)
                self.assertIn(diagnostic, result.stderr)
                self.assertNotIn("is unavailable", result.stderr)
                self.assertNotIn("Account Holder", result.stderr)

    def test_combined_output_is_drained_and_preserved(self):
        result = self.preflight("stderr-marker" * 10000, stdout="stdout-marker" * 10000)
        self.assertEqual(result.returncode, 1)
        self.assertIn("stderr-marker" * 10000, result.stderr)
        self.assertIn("stdout-marker" * 10000, result.stderr)


if __name__ == "__main__":
    unittest.main()
