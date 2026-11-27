"""Engine core API, preset swapping, TestPort inject/sink, freeze callback, and load-all-twice tests (E4).

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/core/test_engine.py
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = Path(os.environ.get("DELUGE_FIRMWARE_DIR", ROOT / "firmware"))
TIMEOUT_S = 180
FREEZE_TIMEOUT_S = 30

# Minimal CC0 Kit preset referencing only CC0 samples from firmware/pack/SAMPLES/.
CC0_TEST_KIT_XML = """<?xml version="1.0" encoding="UTF-8"?>
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

# Minimal CC0 Synth preset with grainFX mod FX (F7 regression test: ~ModControllableAudio() freeing GMA grainFX).
CC0_GRAINFX_SYNTH_XML = """<?xml version="1.0" encoding="UTF-8"?>
<firmwareVersion>c1.3.0</firmwareVersion>
<sound>
\t<osc1>
\t\t<type>sine</type>
\t</osc1>
\t<osc2>
\t\t<type>sine</type>
\t\t<transpose>0</transpose>
\t\t<cents>0</cents>
\t</osc2>
\t<polyphonic>auto</polyphonic>
\t<mode>subtractive</mode>
\t<transpose>0</transpose>
\t<lpfMode>24dB</lpfMode>
\t<modFXType>grainFX</modFXType>
\t<defaultParams>
\t\t<portamento>0x80000000</portamento>
\t\t<oscAVolume>0x7FFFFFFF</oscAVolume>
\t\t<oscBVolume>0x80000000</oscBVolume>
\t\t<noiseVolume>0x80000000</noiseVolume>
\t\t<volume>0x3851EB64</volume>
\t\t<pan>0x00000000</pan>
\t\t<lpfFrequency>0x7FFFFFFF</lpfFrequency>
\t\t<lpfResonance>0x80000000</lpfResonance>
\t\t<hpfFrequency>0x80000000</hpfFrequency>
\t\t<modFXRate>0x40000000</modFXRate>
\t\t<modFXDepth>0x00000000</modFXDepth>
\t\t<modFXOffset>0x20000000</modFXOffset>
\t\t<modFXFeedback>0x00000000</modFXFeedback>
\t\t<envelope1>
\t\t\t<attack>0x80000000</attack>
\t\t\t<decay>0xE6666654</decay>
\t\t\t<sustain>0x7FFFFFFF</sustain>
\t\t\t<release>0x80000000</release>
\t\t</envelope1>
\t\t<delayFeedback>0x80000000</delayFeedback>
\t\t<reverbAmount>0x80000000</reverbAmount>
\t</defaultParams>
</sound>
"""

# Minimal CC0 4-drum Kit referencing the 4 long CC0 pack/ riser samples (F7 cluster loading-queue swap test:
# triggering all 4 simultaneously enqueues multiple lookahead clusters so swapping away hits loadingQueue.erase()).
CC0_LONG_SAMPLE_KIT_XML = """<?xml version="1.0" encoding="UTF-8"?>
<firmwareVersion>c1.3.0</firmwareVersion>
<kit>
\t<defaultParams>
\t\t<volume>0x3851EB64</volume>
\t</defaultParams>
\t<soundSources>
\t\t<sound>
\t\t\t<name>RISER1</name>
\t\t\t<osc1><type>sample</type><fileName>SAMPLES/FX/Riser/GEN Riser 1.wav</fileName><loopMode>1</loopMode></osc1>
\t\t\t<polyphonic>poly</polyphonic><mode>subtractive</mode><lpfMode>24dB</lpfMode>
\t\t\t<defaultParams><oscAVolume>0x7FFFFFFF</oscAVolume><oscBVolume>0x80000000</oscBVolume><noiseVolume>0x80000000</noiseVolume><volume>0x3851EB64</volume><lpfFrequency>0x7FFFFFFF</lpfFrequency><lpfResonance>0x80000000</lpfResonance><hpfFrequency>0x80000000</hpfFrequency></defaultParams>
\t\t</sound>
\t\t<sound>
\t\t\t<name>RISER2</name>
\t\t\t<osc1><type>sample</type><fileName>SAMPLES/FX/Riser/GEN Riser 2.wav</fileName><loopMode>1</loopMode></osc1>
\t\t\t<polyphonic>poly</polyphonic><mode>subtractive</mode><lpfMode>24dB</lpfMode>
\t\t\t<defaultParams><oscAVolume>0x7FFFFFFF</oscAVolume><oscBVolume>0x80000000</oscBVolume><noiseVolume>0x80000000</noiseVolume><volume>0x3851EB64</volume><lpfFrequency>0x7FFFFFFF</lpfFrequency><lpfResonance>0x80000000</lpfResonance><hpfFrequency>0x80000000</hpfFrequency></defaultParams>
\t\t</sound>
\t\t<sound>
\t\t\t<name>RISER3</name>
\t\t\t<osc1><type>sample</type><fileName>SAMPLES/FX/Riser/GEN Riser 3.wav</fileName><loopMode>1</loopMode></osc1>
\t\t\t<polyphonic>poly</polyphonic><mode>subtractive</mode><lpfMode>24dB</lpfMode>
\t\t\t<defaultParams><oscAVolume>0x7FFFFFFF</oscAVolume><oscBVolume>0x80000000</oscBVolume><noiseVolume>0x80000000</noiseVolume><volume>0x3851EB64</volume><lpfFrequency>0x7FFFFFFF</lpfFrequency><lpfResonance>0x80000000</lpfResonance><hpfFrequency>0x80000000</hpfFrequency></defaultParams>
\t\t</sound>
\t\t<sound>
\t\t\t<name>RISERS</name>
\t\t\t<osc1><type>sample</type><fileName>SAMPLES/FX/Riser/Short/GEN Riser Short.wav</fileName><loopMode>1</loopMode></osc1>
\t\t\t<polyphonic>poly</polyphonic><mode>subtractive</mode><lpfMode>24dB</lpfMode>
\t\t\t<defaultParams><oscAVolume>0x7FFFFFFF</oscAVolume><oscBVolume>0x80000000</oscBVolume><noiseVolume>0x80000000</noiseVolume><volume>0x3851EB64</volume><lpfFrequency>0x7FFFFFFF</lpfFrequency><lpfResonance>0x80000000</lpfResonance><hpfFrequency>0x80000000</hpfFrequency></defaultParams>
\t\t</sound>
\t</soundSources>
</kit>
"""


def build_dir():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release"))


def test_binary():
    return build_dir() / "test_engine"


def make_cc0_card_with_kit(dst: Path):
    """Copies CC0 firmware/pack/ into dst and adds generated CC0 Kit, grainFX, and long-sample test presets."""
    shutil.copytree(FIRMWARE / "pack", dst)
    kits_dir = dst / "KITS"
    kits_dir.mkdir(exist_ok=True)
    (kits_dir / "TEST CC0 KIT.XML").write_text(CC0_TEST_KIT_XML, encoding="utf-8")
    (kits_dir / "TEST CC0 RISERS.XML").write_text(CC0_LONG_SAMPLE_KIT_XML, encoding="utf-8")
    test_synths = dst / "SYNTHS" / "TEST"
    test_synths.mkdir(parents=True, exist_ok=True)
    (test_synths / "GRAINFX.XML").write_text(CC0_GRAINFX_SYNTH_XML, encoding="utf-8")


class EngineCoreTests(unittest.TestCase):
    def test_pure_wav_and_midi_parsers(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e4-pure-") as tmp:
            r = subprocess.run(
                [str(test_binary()), "--unit-pure", tmp],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_engine_api_swapping_kit_and_testport(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e4-api-") as tmp:
            card_dir = Path(tmp) / "card"
            make_cc0_card_with_kit(card_dir)
            r = subprocess.run(
                [str(test_binary()), "--unit-engine", str(card_dir), tmp],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_freeze_callback_and_exit_code_70(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e4-freeze-") as tmp:
            r = subprocess.run(
                [str(test_binary()), "--test-freeze", str(FIRMWARE / "pack"), tmp],
                capture_output=True, text=True, timeout=FREEZE_TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 70, r.stdout + r.stderr)
            self.assertIn("ENGINE_FREEZE_CB code=E999 loaded=SYNTHS/GENERATIVE/GEN Sine Sub.XML", r.stderr)

    def test_load_every_pack_preset_twice_and_render_note(self):
        with tempfile.TemporaryDirectory(prefix="deluge-e4-twice-") as tmp:
            card_dir = Path(tmp) / "card"
            cache_dir = Path(tmp) / "cache"
            make_cc0_card_with_kit(card_dir)
            r = subprocess.run(
                [str(test_binary()), "--load-all-twice", str(card_dir), str(cache_dir)],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("failed=0", r.stderr, r.stderr)
            self.assertIn("overruns=0", r.stderr, r.stderr)

    def test_render_cli_validation_errors(self):
        engine = str(build_dir() / "deluge-engine")
        bad_invocations = [
            ["render"],
            ["render", "--card", str(FIRMWARE / "pack"), "--preset", "SYNTHS/GENERATIVE/GEN Sine Sub.XML",
             "--notes", "60", "--out", "/tmp/unused.wav", "--audio", "default"],
            ["render", "--card", str(FIRMWARE / "pack"), "--preset", "SYNTHS/GENERATIVE/GEN Sine Sub.XML",
             "--notes", "60", "--midi", "/tmp/unused.mid", "--out", "/tmp/unused.wav", "--audio", "null"],
            ["render", "--card", str(FIRMWARE / "pack"), "--preset", "SYNTHS/GENERATIVE/GEN Sine Sub.XML",
             "--notes", "NOT_A_NOTE", "--out", "/tmp/unused.wav", "--audio", "null"],
        ]
        for args in bad_invocations:
            with self.subTest(args=args):
                r = subprocess.run([engine, *args], capture_output=True, text=True, timeout=FREEZE_TIMEOUT_S)
                self.assertEqual(r.returncode, 2, r.stdout + r.stderr)

        # Missing preset error should be reported once (not duplicated by both callback and cmdRender).
        with tempfile.TemporaryDirectory(prefix="deluge-e4-missing-") as tmp:
            r = subprocess.run(
                [
                    engine, "render",
                    "--card", str(FIRMWARE / "pack"),
                    "--card-cache", str(Path(tmp) / "cache"),
                    "--preset", "SYNTHS/NO_SUCH_PRESET.XML",
                    "--notes", "60:0.2",
                    "--out", str(Path(tmp) / "out.wav"),
                    "--audio", "null",
                ],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
            self.assertEqual(r.stderr.count("preset not found on card image"), 1, r.stderr)

    def test_f7_grainfx_preset_swap_under_asan(self):
        """F7 regression test: swapping away from a grainFX Synth frees GMA-allocated grainFX cleanly."""
        with tempfile.TemporaryDirectory(prefix="deluge-e4-grainfx-") as tmp:
            card_dir = Path(tmp) / "card"
            make_cc0_card_with_kit(card_dir)
            r = subprocess.run(
                [str(test_binary()), "--test-f7-grainfx", str(card_dir), tmp],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_f7_cluster_loading_swap_under_asan(self):
        """F7 regression test: swapping away from a long sample preset while lookahead clusters load."""
        with tempfile.TemporaryDirectory(prefix="deluge-e4-cluster-") as tmp:
            card_dir = Path(tmp) / "card"
            make_cc0_card_with_kit(card_dir)
            r = subprocess.run(
                [str(test_binary()), "--test-f7-cluster", str(card_dir), tmp],
                capture_output=True, text=True, timeout=TIMEOUT_S,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
