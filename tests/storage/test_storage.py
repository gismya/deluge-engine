"""Card-image & storage tests (E3, spec §3.6): builder, incremental refresh, write overlay, read-time model,
and concurrent multi-process reads on one shared card image.

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/storage/test_storage.py
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = Path(os.environ.get("DELUGE_FIRMWARE_DIR", ROOT / "firmware"))
TIMEOUT_S = 180


def binary():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release")) / "test_storage"


class StorageLayerTests(unittest.TestCase):
    def test_unit_suite(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e3-unit-") as tmp:
            r = subprocess.run(
                [str(binary()), "--unit", str(FIRMWARE / "pack"), tmp],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_two_processes_read_one_image_concurrently(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e3-conc-") as tmp:
            cache_dir = Path(tmp) / "cache"
            build = subprocess.run(
                [str(binary()), "--build-only", str(FIRMWARE / "pack"), str(cache_dir)],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
            image_path = build.stdout.strip()
            self.assertTrue(Path(image_path).is_file(), f"missing image: {image_path}")
            stat_before = os.stat(image_path)

            # Launch two Engine processes reading the exact same card image at the exact same time,
            # each also writing its own process-local overlay file.
            p_a = subprocess.Popen(
                [str(binary()), "--concurrent-reader", image_path, "A"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            p_b = subprocess.Popen(
                [str(binary()), "--concurrent-reader", image_path, "B"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            try:
                out_a, err_a = p_a.communicate(timeout=TIMEOUT_S)
                out_b, err_b = p_b.communicate(timeout=TIMEOUT_S)
            except subprocess.TimeoutExpired:
                p_a.kill()
                p_b.kill()
                raise

            self.assertEqual(p_a.returncode, 0, f"proc A failed:\n{out_a}{err_a}")
            self.assertEqual(p_b.returncode, 0, f"proc B failed:\n{out_b}{err_b}")

            # Verify the shared card image on disk was never modified.
            stat_after = os.stat(image_path)
            self.assertEqual(stat_before.st_size, stat_after.st_size)
            self.assertEqual(stat_before.st_mtime_ns, stat_after.st_mtime_ns)

            clean = subprocess.run(
                [str(binary()), "--verify-disk-clean", image_path],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(clean.returncode, 0, clean.stdout + clean.stderr)


if __name__ == "__main__":
    unittest.main()
