"""startup_guard.py: the text hash of deluge_main and registerTasks (spec §3.4)."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import startup_guard  # noqa: E402

DELUGE_CPP = """
void registerTasks() {
	addRepeatingTask(&AudioEngine::routine, 0, 8 / 44100.0, {16});
	if (x) { addOnceTask(&y); }
}

void other() {}

extern "C" int32_t deluge_main(void) {
	functionsInit();
	// a } in a comment and "a { in a string"
	registerTasks();
	return 0;
}
"""


class StartupGuard(unittest.TestCase):
    def test_finds_each_function_whole(self):
        self.assertEqual(startup_guard.function_text(DELUGE_CPP, "registerTasks"),
                         "void registerTasks() {\n\taddRepeatingTask(&AudioEngine::routine, 0, 8 / 44100.0, {16});\n"
                         "\tif (x) { addOnceTask(&y); }\n}")
        self.assertTrue(startup_guard.function_text(DELUGE_CPP, "deluge_main").endswith("return 0;\n}"))

    def test_missing_function_is_an_error(self):
        with self.assertRaises(startup_guard.GuardError):
            startup_guard.function_text(DELUGE_CPP, "hardwareInit")

    def test_a_changed_body_fails_and_update_accepts_it(self):
        with tempfile.TemporaryDirectory() as d:
            src, stored = Path(d) / "deluge.cpp", Path(d) / "hashes.json"
            src.write_text(DELUGE_CPP)
            self.assertEqual(startup_guard.main(["--source", str(src), "--hashes", str(stored), "--update"]), 0)
            self.assertEqual(startup_guard.main(["--source", str(src), "--hashes", str(stored)]), 0)
            src.write_text(DELUGE_CPP.replace("functionsInit();", "functionsInit();\n\tpicSetup();"))
            self.assertEqual(startup_guard.main(["--source", str(src), "--hashes", str(stored)]), 1)
            # The function that didn't change keeps its hash.
            before = json.loads(stored.read_text())["registerTasks"]
            startup_guard.main(["--source", str(src), "--hashes", str(stored), "--update"])
            self.assertEqual(json.loads(stored.read_text())["registerTasks"], before)

    def test_the_pinned_firmware_matches_the_stored_hashes(self):
        r = subprocess.run([sys.executable, str(ROOT / "tools/startup_guard.py")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
