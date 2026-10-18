"""Exercise release readiness failures without real credentials or Apple requests."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/apple-preflight.sh"
IDENTITY = "Developer ID Application: Example Company (TESTTEAM12)"


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.bin = Path(self.temp.name)
        self.env = dict(os.environ, PATH=f"{self.bin}:/usr/bin:/bin", POM_SIGN_IDENTITY=IDENTITY,
                        POM_NOTARY_PROFILE="test-profile", TEST_IDENTITY=IDENTITY)
        for name in ("POM_SIGN_KEYCHAIN", "POM_NOTARY_KEYCHAIN", "TEST_NOTARY_FAIL", "TEST_XCODE_FAIL", "TEST_IOS_FAIL", "TEST_FIRST_LAUNCH_FAIL"):
            self.env.pop(name, None)
        mocks = {
            "codesign": "exit 0",
            "security": 'if [ -n "$TEST_IDENTITY" ]; then printf \' 1) ABCDEF "%s"\\n\' "$TEST_IDENTITY"; fi',
            "xcodebuild": '''if [ "$1" = -checkFirstLaunchStatus ] && [ "${TEST_FIRST_LAUNCH_FAIL:-0}" = 1 ]; then exit 1; fi
[ "${TEST_XCODE_FAIL:-0}" != 1 ]''',
            "xcrun": '''if [ "$1" = notarytool ] && [ "$2" = history ]; then
  if [ "${TEST_NOTARY_FAIL:-0}" = 1 ]; then echo PRIVATE-ERROR-DETAIL >&2; exit 1; fi
  echo '{}'; exit 0
fi
if [ "$1" = --sdk ] && [ "$2" = iphoneos ] && [ "${TEST_IOS_FAIL:-0}" = 1 ]; then exit 1; fi
exit 0''',
        }
        for name, body in mocks.items():
            path = self.bin / name
            path.write_text("#!/bin/bash\n" + body + "\n")
            path.chmod(0o700)

    def run_check(self, *args):
        return subprocess.run(["/bin/bash", str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_matching_identity_and_notary_pass(self):
        result = self.run_check("--verify-notary", "--app-store")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("No build was signed", result.stdout)

    def test_missing_private_identity_fails(self):
        self.env["TEST_IDENTITY"] = ""
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_wrong_certificate_type_fails(self):
        self.env["TEST_IDENTITY"] = self.env["POM_SIGN_IDENTITY"] = "Apple Development: Example (TESTTEAM12)"
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_configured_name_must_match(self):
        self.env["POM_SIGN_IDENTITY"] = IDENTITY + " wrong"
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_profile_required_for_online_check(self):
        self.env.pop("POM_NOTARY_PROFILE")
        self.assertEqual(self.run_check().returncode, 0)
        self.assertNotEqual(self.run_check("--verify-notary").returncode, 0)

    def test_failed_notary_does_not_expose_error_details(self):
        self.env["TEST_NOTARY_FAIL"] = "1"
        result = self.run_check("--verify-notary")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PRIVATE-ERROR-DETAIL", result.stdout + result.stderr)

    def test_full_xcode_only_required_for_store(self):
        self.env["TEST_XCODE_FAIL"] = "1"
        self.assertEqual(self.run_check().returncode, 0)
        self.assertNotEqual(self.run_check("--app-store").returncode, 0)

    def test_missing_ios_sdk_fails_store_check(self):
        self.env["TEST_IOS_FAIL"] = "1"
        self.assertNotEqual(self.run_check("--app-store").returncode, 0)

    def test_unfinished_xcode_first_launch_fails_store_check(self):
        self.env["TEST_FIRST_LAUNCH_FAIL"] = "1"
        result = self.run_check("--app-store")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Complete Xcode first launch", result.stdout)


if __name__ == "__main__":
    unittest.main()
