"""The first smoke test (E1): render one CC0 pack/ synth and check the audio.

The card image is made here, under the build folder: newfs_msdos formats a sparse file and the firmware's own
fat_image.py (scripts/generative) writes the preset onto it. E3 replaces this with the Engine's card image builder.

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/smoke/test_render_pack.py
"""

import math
import os
import struct
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = Path(os.environ.get("DELUGE_FIRMWARE_DIR", ROOT / "firmware"))  # tools/check.py --firmware-dir
sys.path.insert(0, str(FIRMWARE / "scripts/generative"))
import fat_image  # noqa: E402  (the firmware's FAT32 writer, stdlib only)

# CC0: pack/LICENSES.md lists it under "Generated files". One sine, an 80 ms attack, full sustain, a 1.5 s release.
PRESET = "SYNTHS/GENERATIVE/GEN Sine Sub.XML"
NOTE = 60  # middle C, 261.63 Hz; the preset has no transpose
MIDDLE_C_HZ = 261.63
RATE = 44100
NOTE_ON_FRAME = 4096  # render_preset lets the engine settle for 4096 frames first
HELD_S, TOTAL_S = 1.0, 2.5
RENDER_TIMEOUT_S = 120

CARD_MIB = 2200  # FAT32 with 32 KiB clusters needs at least 65525 clusters (spec §3.6 asks for 32 KiB)


def build_dir():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release"))


def run_checked(cmd, timeout=120):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed with exit {r.returncode}:\n{r.stdout}{r.stderr}")
    return r.stdout


def format_via_device(path):
    """macOS 26's newfs_msdos won't format a plain file ("Cannot get partition offset"). Attached as a raw disk
    image with no mount, the same file is a device it formats; detached again whatever happens."""
    out = run_checked(["hdiutil", "attach", "-imagekey", "diskimage-class=CRawDiskImage", "-nomount", str(path)])
    device = out.split()[0]  # /dev/diskN
    try:
        run_checked(["newfs_msdos", "-F", "32", "-c", "64", "-v", "DELUGE", device.replace("/dev/disk", "/dev/rdisk")])
    finally:
        run_checked(["hdiutil", "detach", device])


def make_card(path, via_device=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        f.truncate(CARD_MIB * 1024 * 1024)  # sparse: a few MB on disk
    try:
        if via_device:
            raise RuntimeError("asked for the device route")
        # 32 KiB clusters (-c 64), the geometry given because a plain file has none.
        run_checked(["newfs_msdos", "-F", "32", "-c", "64", "-S", "512", "-s", str(CARD_MIB * 2048), "-h", "255",
                     "-u", "63", "-o", "0", "-v", "DELUGE", str(path)])
    except RuntimeError:
        format_via_device(path)
    with fat_image.FatImage(str(path)) as card:
        card.write_file(PRESET, (FIRMWARE / "pack" / PRESET).read_bytes())


def render(card, out):
    env = dict(os.environ, DELUGE_SD_IMAGE=str(card))
    return subprocess.run([str(build_dir() / "render_preset"), PRESET, str(out), str(NOTE), str(HELD_S), str(TOTAL_S)],
                          env=env, capture_output=True, text=True, timeout=RENDER_TIMEOUT_S)


def read_wav(path):
    data = path.read_bytes()
    assert data[:4] == b"RIFF" and data[8:16] == b"WAVEfmt ", "not a WAV file"
    channels, rate, bits = struct.unpack_from("<HI", data, 22) + struct.unpack_from("<H", data, 34)
    assert data[36:40] == b"data"
    samples = struct.unpack_from(f"<{struct.unpack_from('<I', data, 40)[0] // 4}i", data, 44)
    return channels, rate, bits, samples[0::2], samples[1::2]


def rms(xs):
    return math.sqrt(sum(x * x for x in xs) / len(xs)) / 2**31 if xs else 0.0


def frequency(xs):
    """From rising zero crossings, interpolated between samples."""
    crossings = [i + xs[i] / (xs[i] - xs[i + 1]) for i in range(len(xs) - 1) if xs[i] < 0 <= xs[i + 1]]
    return (len(crossings) - 1) * RATE / (crossings[-1] - crossings[0])


class RenderPackSynth(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = build_dir() / "smoke"
        cls.card = cls.dir / "card.img"
        make_card(cls.card)

    def test_sine_sub_plays_middle_c_and_releases(self):
        out = self.dir / "sine_sub.wav"
        r = render(self.card, out)
        self.assertEqual(r.returncode, 0, r.stderr[-2000:])
        channels, rate, bits, left, right = read_wav(out)
        self.assertEqual((channels, rate, bits), (2, RATE, 32))
        self.assertEqual(len(left), 110272)  # 2.5 s, rounded up to render_preset's 32-frame steps
        release = NOTE_ON_FRAME + int(HELD_S * RATE)
        self.assertLess(rms(left[:NOTE_ON_FRAME]), 1e-6, "sound before the note")
        held = left[NOTE_ON_FRAME + RATE // 4:release]  # past the 80 ms attack
        self.assertGreater(rms(held), 0.003, "the held note is (nearly) silent")
        self.assertAlmostEqual(frequency(held), MIDDLE_C_HZ, delta=MIDDLE_C_HZ * 0.003)  # within 5 cents
        # Centred (the output dither differs per channel, so not sample-equal).
        self.assertAlmostEqual(rms(right[NOTE_ON_FRAME + RATE // 4:release]) / rms(held), 1.0, delta=0.01)
        late = left[release + int(1.2 * RATE):]
        self.assertLess(rms(late), rms(held) / 4, "the 1.5 s release didn't decay")

    def test_renders_repeat_bit_for_bit(self):
        a, b = self.dir / "repeat_a.wav", self.dir / "repeat_b.wav"
        for out in (a, b):
            r = render(self.card, out)
            self.assertEqual(r.returncode, 0, r.stderr[-2000:])
        self.assertEqual(a.read_bytes(), b.read_bytes())


if __name__ == "__main__":
    unittest.main()
