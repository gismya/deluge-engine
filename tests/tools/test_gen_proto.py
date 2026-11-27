"""gen_proto.py and engine.proto schema tests (E10, spec §7.1, §7.2, §7.4, §7.5)."""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN_PROTO = ROOT / "tools/gen_proto.py"
TIMEOUT_S = 180


class GenProtoTests(unittest.TestCase):
    def test_committed_generated_files_are_up_to_date(self):
        r = subprocess.run([sys.executable, str(GEN_PROTO), "--check"],
                           capture_output=True, text=True, timeout=TIMEOUT_S)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_check_fails_when_generated_file_drifts(self):
        with tempfile.TemporaryDirectory() as d:
            py_dir = Path(d) / "py"
            dart_dir = Path(d) / "dart"
            shutil.copytree(ROOT / "tools/proto_gen", py_dir)
            shutil.copytree(ROOT / "gui/lib/proto", dart_dir)
            pb_py = py_dir / "engine_pb2.py"
            pb_py.write_text(pb_py.read_text() + "\n# drift\n")
            r = subprocess.run([sys.executable, str(GEN_PROTO), "--check",
                                "--python-out", str(py_dir), "--dart-out", str(dart_dir)],
                               capture_output=True, text=True, timeout=TIMEOUT_S)
            self.assertNotEqual(r.returncode, 0, "gen_proto --check should fail on drifted Python output")
            self.assertIn("engine_pb2.py", r.stdout + r.stderr)

            # Also verify drift detection on Dart output.
            shutil.rmtree(py_dir)
            shutil.copytree(ROOT / "tools/proto_gen", py_dir)
            pb_dart = dart_dir / "engine.pb.dart"
            pb_dart.write_text(pb_dart.read_text() + "\n// drift\n")
            r = subprocess.run([sys.executable, str(GEN_PROTO), "--check",
                                "--python-out", str(py_dir), "--dart-out", str(dart_dir)],
                               capture_output=True, text=True, timeout=TIMEOUT_S)
            self.assertNotEqual(r.returncode, 0, "gen_proto --check should fail on drifted Dart output")
            self.assertIn("engine.pb.dart", r.stdout + r.stderr)

    def test_dart_generated_files_present_and_have_envelopes(self):
        dart_dir = ROOT / "gui/lib/proto"
        for name in ("engine.pb.dart", "engine.pbenum.dart", "engine.pbjson.dart"):
            path = dart_dir / name
            self.assertTrue(path.is_file(), f"missing {path}")
        pb_text = (dart_dir / "engine.pb.dart").read_text()
        for sym in ("class ToEngine ", "class FromEngine ", "class Hello ", "class Heartbeat ",
                    "class RenderDone ", "class ErrorReply "):
            self.assertIn(sym, pb_text)
        enum_text = (dart_dir / "engine.pbenum.dart").read_text()
        self.assertIn("PROTOCOL_VERSION_CURRENT", enum_text)

    def test_python_schema_covers_all_spec_messages_and_roundtrips(self):
        sys.path.insert(0, str(ROOT / "tools"))
        from proto_gen import engine_pb2  # noqa: PLC0415

        self.assertEqual(engine_pb2.PROTOCOL_VERSION_CURRENT, 1)

        expected_to = {
            "set_card", "set_setup", "audition", "note", "set_devices", "shutdown",
            "render_piece", "cancel_render", "play", "seek", "stop", "play_piece", "stop_piece",
        }
        actual_to = {f.name for f in engine_pb2.ToEngine.DESCRIPTOR.oneofs_by_name["kind"].fields}
        self.assertEqual(actual_to, expected_to)

        expected_from = {
            "hello", "heartbeat", "card_status", "catalog", "genres", "setup_applied",
            "midi_activity", "devices", "freeze", "render_progress", "render_done",
            "render_failed", "position", "error",
        }
        actual_from = {f.name for f in engine_pb2.FromEngine.DESCRIPTOR.oneofs_by_name["kind"].fields}
        self.assertEqual(actual_from, expected_from)

        # Round-trip a rich RenderPiece + RenderDone to verify optional/oneof/repeated fields.
        req = engine_pb2.ToEngine(
            render_piece=engine_pb2.RenderPiece(
                id="r1",
                length_s=60.0,
                wav_path="/tmp/a.wav",
                recipe=engine_pb2.Recipe(
                    genre="techno-dub",
                    seed=12345,
                    picks=[
                        engine_pb2.SoundPick(part=1, path="SYNTHS/002 Basic Square Bass.XML"),
                        engine_pb2.SoundPick(lane=0, path="SAMPLES/DRUMS/Kick/909 Kick.wav"),
                    ],
                ),
            )
        )
        decoded_req = engine_pb2.ToEngine.FromString(req.SerializeToString())
        self.assertEqual(decoded_req.WhichOneof("kind"), "render_piece")
        self.assertFalse(decoded_req.render_piece.recipe.HasField("entropy"))
        self.assertFalse(decoded_req.render_piece.recipe.HasField("tempo"))
        self.assertEqual(decoded_req.render_piece.recipe.picks[0].WhichOneof("target"), "part")
        self.assertEqual(decoded_req.render_piece.recipe.picks[1].WhichOneof("target"), "lane")

        done = engine_pb2.FromEngine(
            render_done=engine_pb2.RenderDone(
                id="r1",
                wav_path="/tmp/a.wav",
                duration_s=60.0,
                recipe=engine_pb2.Recipe(
                    genre="techno-dub",
                    seed=12345,
                    entropy=12345,
                    macros=[25, 30, 20, 15],
                    tempo=124.5,
                    key=9,
                    scale=1,
                    swing=10,
                    scale_name="Minor",
                ),
                sections=[engine_pb2.SectionMarker(name="INTRO", time_s=0.0)],
                peaks=[engine_pb2.PeakPair(min=-0.5, max=0.5)],
                notes=[engine_pb2.TimelineNote(part=1, start_s=0.0, length_s=0.25, pitch=36, velocity=100)],
                warnings=["missing FX sample"],
                peak_voices=12,
            )
        )
        decoded_done = engine_pb2.FromEngine.FromString(done.SerializeToString())
        self.assertEqual(decoded_done.render_done.peak_voices, 12)
        self.assertAlmostEqual(decoded_done.render_done.recipe.tempo, 124.5)
        self.assertEqual(list(decoded_done.render_done.recipe.macros), [25, 30, 20, 15])


if __name__ == "__main__":
    unittest.main()
