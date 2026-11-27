"""Protocol end-to-end tests (E10, spec §7.1, §7.2, §7.4, §7.5, §7.7).

Drives `deluge-engine serve --audio null` via `tools/engine_client.py` over a Unix domain socket.

    DELUGE_ENGINE_BUILD=build/release python3 -m unittest tests/protocol/test_protocol.py
"""

import os
import socket
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import engine_client  # noqa: E402
from proto_gen import engine_pb2  # noqa: E402

TIMEOUT_S = 20


def build_dir():
    return Path(os.environ.get("DELUGE_ENGINE_BUILD", ROOT / "build/release"))


def engine_binary():
    return build_dir() / "deluge-engine"


def unit_binary():
    return build_dir() / "test_protocol_unit"


class ProtocolUnitTests(unittest.TestCase):
    def test_cpp_unit_suite(self):
        r = subprocess.run([str(unit_binary())], capture_output=True, text=True, timeout=TIMEOUT_S)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


class ProtocolServeTests(unittest.TestCase):
    def test_hello_heartbeats_for_two_seconds_and_clean_shutdown(self):
        """Ticket #26 acceptance: start with --audio null, read Hello, count heartbeats for 2 s, shutdown exit 0."""
        with engine_client.EngineClient(engine_binary(), audio="null") as client:
            hello = client.hello
            self.assertEqual(hello.protocol_version, engine_pb2.PROTOCOL_VERSION_CURRENT)
            self.assertEqual(hello.protocol_version, 1)
            self.assertTrue(hello.engine_version, "engine_version should be non-empty")
            self.assertTrue(hello.firmware_commit, "firmware_commit should be non-empty")
            self.assertEqual(list(hello.capabilities), [])

            heartbeats = []
            deadline = time.monotonic() + 2.1
            while time.monotonic() < deadline:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                try:
                    msg = client.recv(timeout=min(remaining, 0.5))
                except TimeoutError:
                    continue
                self.assertEqual(msg.WhichOneof("kind"), "heartbeat")
                self.assertEqual(msg.heartbeat.voices, 0)
                self.assertEqual(msg.heartbeat.underruns, 0)
                heartbeats.append(msg.heartbeat)

            # 4 Hz over ~2.1 s => expect roughly 7-9 heartbeats (allow CI scheduling slack: 5..14).
            self.assertGreaterEqual(len(heartbeats), 5, f"too few heartbeats in 2.1 s: {len(heartbeats)}")
            self.assertLessEqual(len(heartbeats), 14, f"too many heartbeats in 2.1 s: {len(heartbeats)}")

            rc = client.shutdown(timeout=5.0)
            self.assertEqual(rc, 0, client.stderr_text())
            self.assertFalse(Path(client.socket_path).exists(), "serve should unlink its socket on clean shutdown")

    def test_unimplemented_messages_reply_with_error_naming_command(self):
        cases = [
            ("set_card", engine_pb2.ToEngine(set_card=engine_pb2.SetCard(folder="/tmp/card"))),
            ("set_setup", engine_pb2.ToEngine(set_setup=engine_pb2.SetSetup())),
            ("audition", engine_pb2.ToEngine(audition=engine_pb2.Audition(path="SYNTHS/A.XML", note=60, velocity=100, ms=200))),
            ("note", engine_pb2.ToEngine(note=engine_pb2.Note(channel=1, note=60, velocity=100, on=True))),
            ("set_devices", engine_pb2.ToEngine(set_devices=engine_pb2.SetDevices())),
            ("render_piece", engine_pb2.ToEngine(render_piece=engine_pb2.RenderPiece(id="r1", length_s=10.0, wav_path="/tmp/x.wav"))),
            ("cancel_render", engine_pb2.ToEngine(cancel_render=engine_pb2.CancelRender(id="r1"))),
            ("play", engine_pb2.ToEngine(play=engine_pb2.Play(wav_path="/tmp/x.wav", position_s=0.0))),
            ("seek", engine_pb2.ToEngine(seek=engine_pb2.Seek(position_s=1.0))),
            ("stop", engine_pb2.ToEngine(stop=engine_pb2.Stop())),
            ("play_piece", engine_pb2.ToEngine(play_piece=engine_pb2.PlayPiece())),
            ("stop_piece", engine_pb2.ToEngine(stop_piece=engine_pb2.StopPiece())),
        ]
        with engine_client.EngineClient(engine_binary(), audio="null") as client:
            for name, req in cases:
                client.send(req)
                reply, _ = client.recv_until(lambda m: m.WhichOneof("kind") != "heartbeat", timeout=5.0)
                self.assertEqual(reply.WhichOneof("kind"), "error", f"{name} got {reply}")
                self.assertEqual(reply.error.command, name)
                self.assertIn(name, reply.error.message.lower())
            self.assertEqual(client.shutdown(timeout=5.0), 0)

    def test_trace_logs_messages_in_protobuf_text_format(self):
        with engine_client.EngineClient(engine_binary(), audio="null", trace=True) as client:
            client.send(engine_pb2.ToEngine(set_card=engine_pb2.SetCard(folder="/tmp/trace-card")))
            reply, _ = client.recv_until(lambda m: m.WhichOneof("kind") == "error", timeout=5.0)
            self.assertEqual(reply.error.command, "set_card")
            # Wait for at least one heartbeat so trace output includes it.
            hb, _ = client.recv_until(lambda m: m.WhichOneof("kind") == "heartbeat", timeout=5.0)
            self.assertEqual(hb.WhichOneof("kind"), "heartbeat")
            rc = client.shutdown(timeout=5.0)
            self.assertEqual(rc, 0)
            stderr = client.stderr_text()
            self.assertIn("hello {", stderr)
            self.assertIn("protocol_version: 1", stderr)
            self.assertIn("set_card {", stderr)
            self.assertIn("/tmp/trace-card", stderr)
            self.assertIn("error {", stderr)
            self.assertIn("heartbeat {", stderr)
            self.assertIn("shutdown {", stderr)

    def test_oversized_frame_is_rejected_cleanly(self):
        with tempfile.TemporaryDirectory(prefix="deluge_sock_", dir="/tmp") as d:
            sock_path = str(Path(d) / "eng.sock")
            proc = subprocess.Popen(
                [str(engine_binary()), "serve", "--socket", sock_path, "--audio", "null"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                sock = engine_client.connect_with_retry(sock_path, timeout=5.0)
                try:
                    # Read initial Hello
                    hello_msg = engine_client.read_frame(sock, engine_pb2.FromEngine, timeout=5.0)
                    self.assertEqual(hello_msg.WhichOneof("kind"), "hello")
                    # Send frame length exceeding 16 MiB limit (spec §7.1)
                    sock.sendall(struct.pack("<I", engine_client.MAX_FRAME_BYTES + 1))
                    # Expect an ErrorReply or clean disconnect, never a crash/signal.
                    try:
                        msg = engine_client.read_frame(sock, engine_pb2.FromEngine, timeout=5.0)
                        while msg.WhichOneof("kind") == "heartbeat":
                            msg = engine_client.read_frame(sock, engine_pb2.FromEngine, timeout=5.0)
                        self.assertEqual(msg.WhichOneof("kind"), "error")
                    except EOFError:
                        pass
                finally:
                    sock.close()
                rc = proc.wait(timeout=5.0)
                self.assertGreaterEqual(rc, 0, f"engine crashed with signal {-rc}: {proc.stderr.read()}")
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait(timeout=5.0)

    def test_cli_usage_errors(self):
        r = subprocess.run([str(engine_binary()), "serve"], capture_output=True, text=True, timeout=TIMEOUT_S)
        self.assertEqual(r.returncode, 2)
        r2 = subprocess.run([str(engine_binary()), "unknown-cmd"], capture_output=True, text=True, timeout=TIMEOUT_S)
        self.assertEqual(r2.returncode, 2)


if __name__ == "__main__":
    unittest.main()
