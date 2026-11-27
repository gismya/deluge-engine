"""Platform-layer tests (E2, spec §3.4 & §3.5): clock, pacing, DMA, allocator/LRU/F3, freezes, scheduler startup.

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/platform/test_platform.py
"""

import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TIMEOUT_S = 60
FREEZE_TIMEOUT_S = 20  # a freeze must exit immediately, never busy-wait


def binary():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release")) / "test_platform"


def run_tool(*args, timeout=TIMEOUT_S):
    return subprocess.run([str(binary()), *args], capture_output=True, text=True, timeout=timeout)


class PlatformLayerTests(unittest.TestCase):
    def test_unit_suite(self):
        r = run_tool("--unit")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_real_wall_clock_pacing(self):
        r = run_tool("--pace-real", timeout=FREEZE_TIMEOUT_S)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_freeze_macro_exits_70_with_code_loaded_and_backtrace(self):
        r = run_tool("--freeze-macro", "E999", "SYNTHS/GEN Sine Sub.XML", timeout=FREEZE_TIMEOUT_S)
        self.assertEqual(r.returncode, 70, r.stderr)
        self.assertIn("FREEZE_WITH_ERROR E999", r.stderr)
        self.assertIn("SYNTHS/GEN Sine Sub.XML", r.stderr)
        self.assertIn("backtrace:", r.stderr)
        self.assertIn("0x", r.stderr)

    def test_display_freeze_exits_70_without_busy_wait(self):
        r = run_tool("--freeze-display", "B001", timeout=FREEZE_TIMEOUT_S)
        self.assertEqual(r.returncode, 70, r.stderr)
        self.assertIn("FREEZE_WITH_ERROR B001", r.stderr)
        self.assertIn("backtrace:", r.stderr)

    def test_freeze_callback_runs_before_exit_70(self):
        r = run_tool("--freeze-callback", "E777", timeout=FREEZE_TIMEOUT_S)
        self.assertEqual(r.returncode, 70, r.stderr)
        self.assertIn("CALLBACK code=E777 loaded=SYNTHS/CALLBACK.XML", r.stderr)
        self.assertNotIn("bt_len=0", r.stderr)

    def test_firmware_s002_freeze_exits_70(self):
        r = run_tool("--freeze-s002", timeout=FREEZE_TIMEOUT_S)
        self.assertEqual(r.returncode, 70, r.stderr)
        self.assertIn("FREEZE_WITH_ERROR S002", r.stderr)
        self.assertIn("STRING_S002", r.stderr)
        self.assertIn("backtrace:", r.stderr)


if __name__ == "__main__":
    unittest.main()
