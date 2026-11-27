#!/usr/bin/env python3
"""Python client for the deluge-engine Unix domain socket protocol (spec §7.1, §7.2).

Starts `deluge-engine serve`, connects with retries, reads Hello, sends ToEngine frames,
receives FromEngine frames, and shuts the Engine down cleanly.
"""

import argparse
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

_TOOLS_DIR = Path(__file__).resolve().parent
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))

if __name__ == "__main__":
    try:
        import google.protobuf  # noqa: F401
    except ModuleNotFoundError:
        import proto_env
        py = proto_env.ensure_python_protobuf()
        os.execv(py, [py, *sys.argv])

try:
    from proto_gen import engine_pb2 as pb  # noqa: E402
except ModuleNotFoundError as exc:
    raise ModuleNotFoundError(
        "google.protobuf is required for tools/engine_client.py; "
        "install tools/requirements.txt or run with proto_env.ensure_python_protobuf()"
    ) from exc

MAX_FRAME_BYTES = 16 * 1024 * 1024  # spec §7.1
MAX_UNIX_SOCKET_PATH_BYTES = 100    # spec §7.1: pick under $TMPDIR if < 100 bytes, else /tmp


class ProtocolError(RuntimeError):
    pass


def make_socket_path(prefix="deluge-engine"):
    """Create a short temporary directory and Unix socket path (< 100 bytes per spec §7.1)."""
    tmpdir = os.environ.get("TMPDIR", "/tmp")
    candidate_dir = tempfile.TemporaryDirectory(prefix=f"{prefix}-", dir=tmpdir)
    candidate_path = os.path.join(candidate_dir.name, "e.sock")
    if len(candidate_path.encode("utf-8")) < MAX_UNIX_SOCKET_PATH_BYTES:
        return candidate_path, candidate_dir
    candidate_dir.cleanup()
    fallback_dir = tempfile.TemporaryDirectory(prefix="de-", dir="/tmp")
    return os.path.join(fallback_dir.name, "e.sock"), fallback_dir


def encode_frame(msg):
    payload = msg.SerializeToString()
    if len(payload) > MAX_FRAME_BYTES:
        raise ProtocolError(f"outgoing frame too large: {len(payload)} > {MAX_FRAME_BYTES}")
    return struct.pack("<I", len(payload)) + payload


def write_frame(sock, msg):
    sock.sendall(encode_frame(msg))


def _recv_exact(sock, n, deadline):
    chunks = []
    remaining = n
    while remaining > 0:
        timeout = deadline - time.monotonic()
        if timeout <= 0:
            raise TimeoutError("timed out waiting for protocol frame")
        sock.settimeout(timeout)
        try:
            data = sock.recv(remaining)
        except socket.timeout as exc:
            raise TimeoutError("timed out waiting for protocol frame") from exc
        if not data:
            raise EOFError("engine closed the socket")
        chunks.append(data)
        remaining -= len(data)
    return b"".join(chunks)


def read_frame(sock, msg_cls=pb.FromEngine, timeout=5.0):
    deadline = time.monotonic() + timeout
    header = _recv_exact(sock, 4, deadline)
    (length,) = struct.unpack("<I", header)
    if length > MAX_FRAME_BYTES:
        raise ProtocolError(f"incoming frame exceeds 16 MiB limit: {length}")
    payload = _recv_exact(sock, length, deadline) if length else b""
    msg = msg_cls()
    msg.ParseFromString(payload)
    return msg


def connect_with_retry(socket_path, timeout=5.0, proc=None):
    """Connect to the Engine's Unix domain socket, retrying up to `timeout` seconds (spec §7.1)."""
    deadline = time.monotonic() + timeout
    last_err = None
    while True:
        if proc is not None and proc.poll() is not None:
            raise ProtocolError(f"deluge-engine exited early with status {proc.returncode} before accepting")
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.connect(str(socket_path))
            return sock
        except OSError as exc:
            sock.close()
            last_err = exc
            if time.monotonic() >= deadline:
                raise TimeoutError(f"failed to connect to {socket_path} within {timeout:.1f}s: {last_err}") from exc
            time.sleep(0.02)


class EngineClient:
    """Context-managed client for a single `deluge-engine serve` process."""

    def __init__(
        self,
        binary,
        *,
        audio="null",
        card=None,
        socket_path=None,
        trace=False,
        connect_timeout=5.0,
        check_version=True,
        extra_args=None,
    ):
        self.binary = Path(binary)
        self.audio = audio
        self.card = Path(card) if card is not None else None
        self._owns_socket_dir = socket_path is None
        self._socket_dir = None
        self.socket_path = str(socket_path) if socket_path is not None else None
        self.trace = trace
        self.connect_timeout = connect_timeout
        self.check_version = check_version
        self.extra_args = list(extra_args) if extra_args else []

        self.proc = None
        self.sock = None
        self.hello = None
        self._stderr_file = None

    def start(self):
        if self.socket_path is None:
            self.socket_path, self._socket_dir = make_socket_path()

        cmd = [str(self.binary), "serve", "--socket", self.socket_path, "--audio", self.audio]
        if self.card is not None:
            cmd.extend(["--card", str(self.card)])
        if self.trace:
            cmd.append("--trace")
        cmd.extend(self.extra_args)

        # Write stderr to a temporary file so verbose --trace output never blocks on a full pipe.
        self._stderr_file = tempfile.TemporaryFile(mode="w+b")
        self.proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                     stderr=self._stderr_file)
        try:
            self.sock = connect_with_retry(self.socket_path, timeout=self.connect_timeout, proc=self.proc)
            first = self.recv(timeout=self.connect_timeout)
            if first.WhichOneof("kind") != "hello":
                raise ProtocolError(f"expected Hello as first message, got {first.WhichOneof('kind')!r}")
            self.hello = first.hello
            if self.check_version and self.hello.protocol_version != pb.PROTOCOL_VERSION_CURRENT:
                raise ProtocolError(
                    f"protocol_version mismatch: engine={self.hello.protocol_version}, "
                    f"client={pb.PROTOCOL_VERSION_CURRENT}"
                )
            return self.hello
        except Exception:
            stderr = self.stderr_text()
            self.close()
            if stderr:
                raise ProtocolError(f"failed starting engine ({cmd}):\n{stderr}")
            raise

    def send(self, msg):
        if self.sock is None:
            raise ProtocolError("client is not connected")
        write_frame(self.sock, msg)

    def recv(self, timeout=5.0):
        if self.sock is None:
            raise ProtocolError("client is not connected")
        return read_frame(self.sock, pb.FromEngine, timeout=timeout)

    def recv_until(self, predicate, timeout=5.0):
        """Read messages until `predicate(msg)` is true; returns (matched_msg, skipped_msgs)."""
        deadline = time.monotonic() + timeout
        skipped = []
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("timed out waiting for matching message")
            msg = self.recv(timeout=remaining)
            if predicate(msg):
                return msg, skipped
            skipped.append(msg)

    def shutdown(self, timeout=5.0):
        """Send Shutdown, wait for clean process exit, and return the exit code."""
        if self.sock is not None:
            try:
                self.send(pb.ToEngine(shutdown=pb.Shutdown()))
            except OSError:
                pass
            try:
                self.sock.close()
            finally:
                self.sock = None
        if self.proc is None:
            return 0
        try:
            return self.proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5.0)
            raise

    def stderr_text(self):
        if self._stderr_file is None:
            return ""
        self._stderr_file.flush()
        self._stderr_file.seek(0)
        return self._stderr_file.read().decode("utf-8", errors="replace")

    def close(self):
        if self.sock is not None:
            try:
                self.sock.close()
            finally:
                self.sock = None
        if self.proc is not None:
            if self.proc.poll() is None:
                self.proc.terminate()
                try:
                    self.proc.wait(timeout=2.0)
                except subprocess.TimeoutExpired:
                    self.proc.kill()
                    self.proc.wait(timeout=5.0)
            self.proc = None
        if self._stderr_file is not None:
            self._stderr_file.close()
            self._stderr_file = None
        if self._socket_dir is not None:
            self._socket_dir.cleanup()
            self._socket_dir = None

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, exc_type, exc, tb):
        try:
            if self.proc is not None and self.proc.poll() is None and self.sock is not None:
                self.shutdown(timeout=5.0)
        finally:
            self.close()
        return False


def main(argv=None):
    ap = argparse.ArgumentParser(description="Smoke-drive `deluge-engine serve` over its Unix socket.")
    ap.add_argument("--binary", required=True, help="path to deluge-engine binary")
    ap.add_argument("--audio", default="null", help="audio backend (default: null)")
    ap.add_argument("--seconds", type=float, default=2.0, help="how long to listen for heartbeats")
    ap.add_argument("--trace", action="store_true", help="pass --trace to the Engine")
    args = ap.parse_args(argv)

    with EngineClient(args.binary, audio=args.audio, trace=args.trace) as client:
        print(f"Hello: v{client.hello.protocol_version} engine={client.hello.engine_version} "
              f"fw={client.hello.firmware_commit} caps={list(client.hello.capabilities)}")
        count = 0
        deadline = time.monotonic() + args.seconds
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            try:
                msg = client.recv(timeout=min(remaining, 0.5))
            except TimeoutError:
                continue
            if msg.WhichOneof("kind") == "heartbeat":
                count += 1
        rc = client.shutdown(timeout=5.0)
        print(f"Heartbeats in {args.seconds:.1f}s: {count}, shutdown exit={rc}")
        return rc


if __name__ == "__main__":
    sys.exit(main())
