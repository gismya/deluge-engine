"""Smoke and golden tests for `deluge-engine render` (E4, spec §3.9 & §11):
- 44.1 kHz, stereo, 24-bit WAV output
- Synth and CC0 Kit presets via `--notes` and `--midi`
- Goldens: CC0 pack/ presets rendered twice and compared bit for bit in CI

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/smoke/test_render_pack.py
"""

import math
import os
import shutil
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = Path(os.environ.get("DELUGE_FIRMWARE_DIR", ROOT / "firmware"))  # tools/check.py --firmware-dir

# CC0 presets listed under "Generated files" in firmware/pack/LICENSES.md.
SINE_PRESET = "SYNTHS/GENERATIVE/GEN Sine Sub.XML"
GOLDEN_SYNTHS = [
    ("SYNTHS/GENERATIVE/GEN Sine Sub.XML", "60:0.6"),
    ("SYNTHS/GENERATIVE/GEN Psy Bass.XML", "C3:0.5"),
    ("SYNTHS/GENERATIVE/GEN House Stab.XML", "C3+E3+G3:0.5"),
    ("SYNTHS/GENERATIVE/GEN Dub Sub.XML", "48:0.5"),
    ("SYNTHS/GENERATIVE/GEN Ambient Drone 1.XML", "C3:0.6"),
]

MIDDLE_C_HZ = 261.63
RATE = 44100
LEAD_IN_S = 0.1
HELD_S = 1.0
TAIL_S = 1.5
RENDER_TIMEOUT_S = 120

CC0_KIT_XML = """<?xml version="1.0" encoding="UTF-8"?>
<firmwareVersion>c1.3.0</firmwareVersion>
<kit>
\t<defaultParams>
\t\t<volume>0x3851EB64</volume>
\t</defaultParams>
\t<soundSources>
\t\t<sound>
\t\t\t<name>CLAP</name>
\t\t\t<osc1>
\t\t\t\t<type>sample</type>
\t\t\t\t<fileName>SAMPLES/DRUMS/Clap/GEN Clap 1.wav</fileName>
\t\t\t\t<loopMode>1</loopMode>
\t\t\t</osc1>
\t\t\t<polyphonic>poly</polyphonic>
\t\t\t<mode>subtractive</mode>
\t\t\t<lpfMode>24dB</lpfMode>
\t\t\t<defaultParams>
\t\t\t\t<oscAVolume>0x7FFFFFFF</oscAVolume>
\t\t\t\t<oscBVolume>0x80000000</oscBVolume>
\t\t\t\t<noiseVolume>0x80000000</noiseVolume>
\t\t\t\t<volume>0x3851EB64</volume>
\t\t\t\t<lpfFrequency>0x7FFFFFFF</lpfFrequency>
\t\t\t\t<lpfResonance>0x80000000</lpfResonance>
\t\t\t\t<hpfFrequency>0x80000000</hpfFrequency>
\t\t\t\t<envelope1>
\t\t\t\t\t<attack>0x80000000</attack>
\t\t\t\t\t<decay>0xE6666654</decay>
\t\t\t\t\t<sustain>0x7FFFFFFF</sustain>
\t\t\t\t\t<release>0x80000000</release>
\t\t\t\t</envelope1>
\t\t\t</defaultParams>
\t\t</sound>
\t\t<sound>
\t\t\t<name>RIDE</name>
\t\t\t<osc1>
\t\t\t\t<type>sample</type>
\t\t\t\t<fileName>SAMPLES/DRUMS/Ride/GEN Ride 1.wav</fileName>
\t\t\t\t<loopMode>1</loopMode>
\t\t\t</osc1>
\t\t\t<polyphonic>poly</polyphonic>
\t\t\t<mode>subtractive</mode>
\t\t\t<lpfMode>24dB</lpfMode>
\t\t\t<defaultParams>
\t\t\t\t<oscAVolume>0x7FFFFFFF</oscAVolume>
\t\t\t\t<oscBVolume>0x80000000</oscBVolume>
\t\t\t\t<noiseVolume>0x80000000</noiseVolume>
\t\t\t\t<volume>0x3851EB64</volume>
\t\t\t\t<lpfFrequency>0x7FFFFFFF</lpfFrequency>
\t\t\t\t<lpfResonance>0x80000000</lpfResonance>
\t\t\t\t<hpfFrequency>0x80000000</hpfFrequency>
\t\t\t\t<envelope1>
\t\t\t\t\t<attack>0x80000000</attack>
\t\t\t\t\t<decay>0xE6666654</decay>
\t\t\t\t\t<sustain>0x7FFFFFFF</sustain>
\t\t\t\t\t<release>0x80000000</release>
\t\t\t\t</envelope1>
\t\t\t</defaultParams>
\t\t</sound>
\t</soundSources>
</kit>
"""


def build_dir():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release"))


def render_cli(card_folder, cache_dir, preset, out, *, notes=None, midi=None, lead_in=LEAD_IN_S, tail=TAIL_S):
    cmd = [
        str(build_dir() / "deluge-engine"),
        "render",
        "--card", str(card_folder),
        "--card-cache", str(cache_dir),
        "--preset", preset,
        "--out", str(out),
        "--lead-in", str(lead_in),
        "--tail", str(tail),
        "--audio", "null",
    ]
    if notes is not None:
        cmd += ["--notes", notes]
    if midi is not None:
        cmd += ["--midi", str(midi)]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=RENDER_TIMEOUT_S)


def read_wav24(path):
    data = path.read_bytes()
    assert data[:4] == b"RIFF" and data[8:16] == b"WAVEfmt ", "not a WAV file"
    fmt, channels, rate, byte_rate, block_align, bits = struct.unpack_from("<HHIIHH", data, 20)
    assert fmt == 1, f"expected PCM format 1, got {fmt}"
    assert data[36:40] == b"data"
    data_bytes = struct.unpack_from("<I", data, 40)[0]
    assert bits == 24 and channels == 2 and block_align == 6 and byte_rate == rate * 6
    assert len(data) == 44 + data_bytes
    raw = memoryview(data)[44:]
    n_frames = data_bytes // 6
    left = []
    right = []
    for i in range(n_frames):
        off = i * 6
        lv = raw[off] | (raw[off + 1] << 8) | (raw[off + 2] << 16)
        if lv & 0x800000:
            lv -= 0x1000000
        rv = raw[off + 3] | (raw[off + 4] << 8) | (raw[off + 5] << 16)
        if rv & 0x800000:
            rv -= 0x1000000
        left.append(lv)
        right.append(rv)
    return channels, rate, bits, left, right


def rms24(xs):
    return math.sqrt(sum(x * x for x in xs) / len(xs)) / 2**23 if xs else 0.0


def frequency(xs):
    """From rising zero crossings, interpolated between samples."""
    crossings = [i + xs[i] / (xs[i] - xs[i + 1]) for i in range(len(xs) - 1) if xs[i] < 0 <= xs[i + 1]]
    return (len(crossings) - 1) * RATE / (crossings[-1] - crossings[0])


def make_smf_type0(path: Path, channel: int, note: int, dur_ticks: int = 480):
    """Writes a minimal Format 0 SMF at 120 BPM (480 ticks/quarter = 0.5 s)."""
    def vlq(v):
        out = [v & 0x7F]
        v >>= 7
        while v:
            out.append((v & 0x7F) | 0x80)
            v >>= 7
        return bytes(reversed(out))

    track = bytearray()
    track += b"\x00\xFF\x51\x03\x07\xA1\x20"  # 120 BPM
    track += b"\x00" + bytes([0x90 | channel, note, 100])
    track += vlq(dur_ticks) + bytes([0x80 | channel, note, 0x40])
    track += b"\x00\xFF\x2F\x00"
    smf = b"MThd" + struct.pack(">IHHH", 6, 0, 1, 480) + b"MTrk" + struct.pack(">I", len(track)) + bytes(track)
    path.write_bytes(smf)


class RenderPackSynth(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = build_dir() / "smoke"
        cls.dir.mkdir(parents=True, exist_ok=True)
        cls.cache = cls.dir / "cards"
        cls.pack = FIRMWARE / "pack"

    def test_sine_sub_plays_middle_c_and_releases_wav24(self):
        out = self.dir / "sine_sub.wav"
        r = render_cli(self.pack, self.cache, SINE_PRESET, out, notes=f"60:{HELD_S}:100")
        self.assertEqual(r.returncode, 0, r.stderr[-2000:])
        self.assertIn("overruns 0", r.stderr, r.stderr[-2000:])
        channels, rate, bits, left, right = read_wav24(out)
        self.assertEqual((channels, rate, bits), (2, RATE, 24))
        total_s = LEAD_IN_S + HELD_S + TAIL_S
        self.assertEqual(len(left), int(round(total_s * RATE)))
        note_on = int(round(LEAD_IN_S * RATE))
        release = note_on + int(round(HELD_S * RATE))
        self.assertLess(rms24(left[:note_on]), 1e-5, "sound before the note")
        held = left[note_on + RATE // 4:release]  # past the 80 ms attack
        self.assertGreater(rms24(held), 0.003, "the held note is (nearly) silent")
        self.assertAlmostEqual(frequency(held), MIDDLE_C_HZ, delta=MIDDLE_C_HZ * 0.003)  # within 5 cents
        # Centred (the output dither differs per channel, so not sample-equal).
        self.assertAlmostEqual(rms24(right[note_on + RATE // 4:release]) / rms24(held), 1.0, delta=0.01)
        late = left[release + int(1.2 * RATE):]
        self.assertLess(rms24(late), rms24(held) / 4, "the 1.5 s release didn't decay")

    def test_midi_file_render_synth_and_kit(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e4-midi-") as tmp:
            card_dir = Path(tmp) / "card"
            cache_dir = Path(tmp) / "cache"
            shutil.copytree(self.pack, card_dir)
            (card_dir / "KITS").mkdir(exist_ok=True)
            (card_dir / "KITS/TEST CC0 KIT.XML").write_text(CC0_KIT_XML, encoding="utf-8")

            # Synth via Format 0 SMF on channel 1 (index 0).
            synth_mid = Path(tmp) / "synth.mid"
            make_smf_type0(synth_mid, channel=0, note=60, dur_ticks=480)
            synth_wav = Path(tmp) / "synth.wav"
            r = render_cli(card_dir, cache_dir, SINE_PRESET, synth_wav, midi=synth_mid, lead_in=0.1, tail=0.5)
            self.assertEqual(r.returncode, 0, r.stderr[-2000:])
            channels, rate, bits, left, _ = read_wav24(synth_wav)
            self.assertEqual((channels, rate, bits), (2, RATE, 24))
            self.assertGreater(rms24(left[int(0.25 * RATE):int(0.55 * RATE)]), 0.003)

            # Kit via Format 0 SMF on channel 10 (index 9), drum 0 = note 36.
            kit_mid = Path(tmp) / "kit.mid"
            make_smf_type0(kit_mid, channel=9, note=36, dur_ticks=240)
            kit_wav = Path(tmp) / "kit.wav"
            r2 = render_cli(card_dir, cache_dir, "KITS/TEST CC0 KIT.XML", kit_wav, midi=kit_mid, lead_in=0.1, tail=0.5)
            self.assertEqual(r2.returncode, 0, r2.stderr[-2000:])
            channels, rate, bits, kleft, _ = read_wav24(kit_wav)
            self.assertEqual((channels, rate, bits), (2, RATE, 24))
            self.assertLess(rms24(kleft[:int(0.08 * RATE)]), 1e-5)
            self.assertGreater(rms24(kleft[int(0.1 * RATE):int(0.35 * RATE)]), 0.003)

    def test_pack_goldens_repeat_bit_for_bit(self):
        """Spec §11 / E4: pack/ renders, rendered twice and compared bit for bit."""
        for idx, (preset, notes) in enumerate(GOLDEN_SYNTHS):
            with self.subTest(preset=preset):
                a = self.dir / f"golden_{idx}_a.wav"
                b = self.dir / f"golden_{idx}_b.wav"
                for out in (a, b):
                    r = render_cli(self.pack, self.cache, preset, out, notes=notes, lead_in=0.05, tail=0.4)
                    self.assertEqual(r.returncode, 0, r.stderr[-2000:])
                    self.assertIn("overruns 0", r.stderr, r.stderr[-2000:])
                self.assertEqual(a.read_bytes(), b.read_bytes(), f"{preset} did not repeat bit-for-bit")
                channels, rate, bits, left, _ = read_wav24(a)
                self.assertEqual((channels, rate, bits), (2, RATE, 24))
                self.assertGreater(rms24(left), 0.001, f"{preset} rendered silence")


if __name__ == "__main__":
    unittest.main()
