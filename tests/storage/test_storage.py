"""Card-image & storage tests (E3, spec §3.6): builder, incremental COW refresh, write overlay, read-time model,
DELUGE_SD_IMAGE fallback, nested access E259/E258 freezes, and concurrent multi-process reads/refreshes.

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/storage/test_storage.py
"""

import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = Path(os.environ.get("DELUGE_FIRMWARE_DIR", ROOT / "firmware"))
TIMEOUT_S = 180
FREEZE_TIMEOUT_S = 20


def build_dir():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release"))


def binary():
    return build_dir() / "test_storage"


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

    def test_live_reader_unaffected_by_concurrent_refresh(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e3-cow-") as tmp:
            card_dir = Path(tmp) / "card"
            cache_dir = Path(tmp) / "cache"
            (card_dir / "SYNTHS").mkdir(parents=True)
            (card_dir / "SAMPLES").mkdir(parents=True)
            (card_dir / "SYNTHS/A.XML").write_text("version-1\n")
            (card_dir / "SAMPLES/BIG.BIN").write_bytes(b"1" * 131072)

            b1 = subprocess.run(
                [str(binary()), "--build-only", str(card_dir), str(cache_dir)],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(b1.returncode, 0, b1.stdout + b1.stderr)
            image_path = b1.stdout.strip()
            ino_before = os.stat(image_path).st_ino

            # Hold card.img open read-only in a live reader process while another process refreshes it.
            reader = subprocess.Popen(
                [str(binary()), "--hold-reader", image_path],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            try:
                ready = reader.stdout.readline().strip()
                if ready != "READY":
                    _, err_r = reader.communicate(timeout=FREEZE_TIMEOUT_S)
                    self.fail(f"reader failed before ready (got {ready!r}): {err_r}")

                # Mutate the source folder and run an incremental refresh while reader holds the old inode open.
                time.sleep(0.01)
                (card_dir / "SYNTHS/A.XML").write_text("version-2-refreshed\n")
                (card_dir / "SAMPLES/BIG.BIN").write_bytes(b"2" * 131072)
                (card_dir / "SYNTHS/C.XML").write_text("added\n")

                b2 = subprocess.run(
                    [str(binary()), "--build-only", str(card_dir), str(cache_dir)],
                    capture_output=True, text=True, timeout=TIMEOUT_S,
                )
                self.assertEqual(b2.returncode, 0, b2.stdout + b2.stderr)
                self.assertIn("fullRebuild=0", b2.stderr, b2.stderr)
                ino_after = os.stat(image_path).st_ino
                self.assertNotEqual(ino_before, ino_after, "incremental refresh must replace inode via COW clone")

                # Let the old reader re-read from its already-open fd: it must still see intact v1 data.
                out_r, err_r = reader.communicate(input="GO\n", timeout=TIMEOUT_S)
                self.assertEqual(reader.returncode, 0, f"live reader saw torn data:\n{out_r}{err_r}")
            finally:
                if reader.poll() is None:
                    reader.kill()
                    reader.wait()

            # A fresh reader opening card.img must see the refreshed v2 data.
            v2 = subprocess.run(
                [str(binary()), "--verify-refreshed", image_path],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(v2.returncode, 0, v2.stdout + v2.stderr)

    def test_deluge_sd_image_env_fallback(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e3-env-") as tmp:
            cache_dir = Path(tmp) / "cache"
            build = subprocess.run(
                [str(binary()), "--build-only", str(FIRMWARE / "pack"), str(cache_dir)],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
            image_path = build.stdout.strip()

            env = dict(os.environ, DELUGE_SD_IMAGE=image_path)
            r = subprocess.run(
                [str(binary()), "--deluge-sd-image"],
                env=env, capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

            # Also verify `deluge-engine render` works without --card via DELUGE_SD_IMAGE alone.
            out_wav = Path(tmp) / "env_render.wav"
            rp = subprocess.run(
                [
                    str(build_dir() / "deluge-engine"), "render", "--audio", "null",
                    "--preset", "SYNTHS/GENERATIVE/GEN Sine Sub.XML",
                    "--notes", "60:0.2",
                    "--lead-in", "0.05",
                    "--tail", "0.25",
                    "--out", str(out_wav),
                ],
                env=env, capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(rp.returncode, 0, rp.stdout + rp.stderr)
            self.assertIn("overruns 0", rp.stderr, rp.stderr)
            self.assertTrue(out_wav.is_file() and out_wav.stat().st_size > 44)

    def test_nested_card_access_freezes_e259_and_e258(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e3-freeze-") as tmp:
            card_dir = Path(tmp) / "card"
            cache_dir = Path(tmp) / "cache"
            (card_dir / "SYNTHS").mkdir(parents=True)
            (card_dir / "SYNTHS/A.XML").write_text("<sound/>\n")

            build = subprocess.run(
                [str(binary()), "--build-only", str(card_dir), str(cache_dir)],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
            image_path = build.stdout.strip()

            for flag, code in (("--freeze-e259", "E259"), ("--freeze-e258", "E258")):
                with self.subTest(code=code):
                    r = subprocess.run(
                        [str(binary()), flag, image_path],
                        capture_output=True, text=True, timeout=FREEZE_TIMEOUT_S,
                    )
                    self.assertEqual(r.returncode, 70, r.stdout + r.stderr)
                    self.assertIn(f"FREEZE_WITH_ERROR {code}", r.stderr)


if __name__ == "__main__":
    unittest.main()
