"""The smoke test (E1, updated by E3): build the pack/ card image via the Engine's card image builder,
render one CC0 pack/ synth with the modelled read-time sector device, and check the audio.

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/smoke/test_render_pack.py
"""

import math
import os
import struct
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = Path(os.environ.get("DELUGE_FIRMWARE_DIR", ROOT / "firmware"))  # tools/check.py --firmware-dir

# CC0: pack/LICENSES.md lists it under "Generated files". One sine, an 80 ms attack, full sustain, a 1.5 s release.
PRESET = "SYNTHS/GENERATIVE/GEN Sine Sub.XML"
NOTE = 60  # middle C, 261.63 Hz; the preset has no transpose
MIDDLE_C_HZ = 261.63
RATE = 44100
NOTE_ON_FRAME = 4096  # render_preset lets the engine settle for 4096 frames first
HELD_S, TOTAL_S = 1.0, 2.5
RENDER_TIMEOUT_S = 120


def build_dir():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release"))


def render(card_folder, cache_dir, out):
    return subprocess.run(
        [
            str(build_dir() / "render_preset"),
            "--card", str(card_folder),
            "--card-cache", str(cache_dir),
            "--audio", "null",
            PRESET, str(out), str(NOTE), str(HELD_S), str(TOTAL_S),
        ],
        capture_output=True, text=True, timeout=RENDER_TIMEOUT_S,
    )


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
        cls.dir.mkdir(parents=True, exist_ok=True)
        cls.cache = cls.dir / "cards"
        cls.pack = FIRMWARE / "pack"

    def test_sine_sub_plays_middle_c_and_releases(self):
        out = self.dir / "sine_sub.wav"
        r = render(self.pack, self.cache, out)
        self.assertEqual(r.returncode, 0, r.stderr[-2000:])
        self.assertIn("Cluster::size 32768", r.stderr, r.stderr[-2000:])
        self.assertIn("overruns 0", r.stderr, r.stderr[-2000:])
        channels, rate, bits, left, right = read_wav(out)
        self.assertEqual((channels, rate, bits), (2, RATE, 32))
        self.assertEqual(len(left), int(TOTAL_S * RATE))  # exact 2.5 s captured from the scheduler-driven DMA sink
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
            r = render(self.pack, self.cache, out)
            self.assertEqual(r.returncode, 0, r.stderr[-2000:])
        self.assertEqual(a.read_bytes(), b.read_bytes())


if __name__ == "__main__":
    unittest.main()
