"""Tikras diegimo ir pašalinimo ciklas izoliuotame kataloge, neliečiant naudotojo nustatymų."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="pom-bridge-test-")
        self.addCleanup(self.folder.cleanup)
        self.base = Path(self.folder.name)
        self.env = dict(os.environ, POM_HOME=str(self.base))
        self.claude = self.base / ".claude"
        self.claude.mkdir()
        self.settings = self.claude / "settings.json"
        self.snapshot = self.base / "Library/Application Support/POM/snapshot.json"

    def run_script(self, name, **kwargs):
        return subprocess.run(["/bin/bash", str(ROOT / "scripts" / name)], env=self.env,
                              text=True, capture_output=True, timeout=10, **kwargs)

    def test_install_preserves_custom_script_and_uninstall_restores_it(self):
        script = self.claude / "mano juosta.sh"
        original = '#!/bin/bash\ninput=$(cat)\nprintf "mano juosta"\n'
        command = f'/bin/bash "{script}" --trumpai'
        settings = {"statusLine": {"type": "command", "command": command}, "language": "Lithuanian"}
        self.settings.write_text(json.dumps(settings))
        script.write_text(original)
        result = self.run_script("install-bridge.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(self.settings.read_text()), settings)
        self.assertEqual(len(list(self.claude.glob("mano juosta.sh.bak-*"))), 1)
        result = self.run_script("install-bridge.sh")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(script.read_text().count("# >>> POM"), 1)
        payload = {"rate_limits": {"five_hour": {"used_percentage": 7},
                                   "seven_day": {"used_percentage": 3}}}
        result = subprocess.run(["/bin/bash", str(script)], input=json.dumps(payload),
                                env=self.env, text=True, capture_output=True, timeout=5)
        self.assertEqual(result.stdout, "mano juosta")
        for _ in range(50):
            if self.snapshot.exists():
                break
            time.sleep(.02)
        self.assertEqual(json.loads(self.snapshot.read_text())["five_hour"]["used_percentage"], 7)
        self.assertEqual(self.run_script("uninstall-bridge.sh").returncode, 0)
        self.assertEqual(script.read_text().strip(), original.strip())

    def test_quoted_path_and_missing_path_with_spaces(self):
        script = self.claude / "nauja juosta.sh"
        self.settings.write_text(json.dumps({"statusLine": {"command": f'"{script}"'}}))
        result = self.run_script("install-bridge.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(script.exists())
        self.assertIn("# >>> POM", script.read_text())

    def test_unknown_command_does_not_modify_any_script(self):
        script = self.claude / "statusline.sh"
        original = "#!/bin/bash\ninput=$(cat)\n"
        script.write_text(original)
        for command in [f"/bin/bash -c '{script}'", f"/bin/bash {script}; echo wrong", "node /bin/bash"]:
            self.settings.write_text(json.dumps({"statusLine": {"command": command}}))
            result = self.run_script("install-bridge.sh")
            self.assertNotEqual(result.returncode, 0, command)
            self.assertEqual(script.read_text(), original)

    def test_bridge_preserves_fable_and_does_not_replace_good_data_with_empty(self):
        for window in [{"seven_day_fable": {"used_percentage": 4, "resets_at": 1800000000}},
                       {"model_scoped": [{"display_name": "Fable", "utilization": 4, "resets_at": 1800000000}]},
                       {"limits": [{"kind": "weekly_scoped", "percent": 4, "resets_at": 1800000000,
                                    "scope": {"model": {"display_name": "Fable"}}}]}]:
            payload = {"subscription_type": "max", "rate_limits": {
                "five_hour": {"used_percentage": 7}, "seven_day": {"used_percentage": 3}, **window}}
            self.assertEqual(self.run_script("pom-bridge.sh", input=json.dumps(payload)).returncode, 0)
            snapshot = json.loads(self.snapshot.read_text())
            self.assertEqual(snapshot["seven_day_fable"]["used_percentage"], 4)
            self.assertEqual(snapshot["plan"], "max")
        previous = self.snapshot.read_bytes()
        self.run_script("pom-bridge.sh", input="{}")
        self.assertEqual(self.snapshot.read_bytes(), previous)


if __name__ == "__main__":
    unittest.main()
