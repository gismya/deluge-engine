"""Pinned protobuf toolchain helpers shared by gen_proto.py and check.py (E10, spec §7.1).

Versions live in proto/versions.json:
  - protoc (exact version; uses PATH if it matches, else downloads & verifies the pinned GitHub release)
  - Dart protoc_plugin (installed into an isolated PUB_CACHE under ~/.cache/deluge-engine/proto/)
  - Python protobuf runtime (uses sys.executable if it matches, else bootstraps a cached venv)
"""

import contextlib
import fcntl
import hashlib
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSIONS_PATH = ROOT / "proto/versions.json"
CACHE_ROOT = Path.home() / ".cache/deluge-engine/proto"


def load_versions():
    return json.loads(VERSIONS_PATH.read_text())


@contextlib.contextmanager
def _cache_lock(name):
    CACHE_ROOT.mkdir(parents=True, exist_ok=True)
    lock_path = CACHE_ROOT / f"{name}.lock"
    with open(lock_path, "w") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def _protoc_version(path):
    try:
        r = subprocess.run([str(path), "--version"], capture_output=True, text=True, timeout=15)
    except OSError:
        return None
    if r.returncode != 0:
        return None
    m = re.search(r"libprotoc\s+(\S+)", r.stdout.strip())
    return m.group(1) if m else None


def _download_with_sha256(url, dest, expected_sha256):
    req = urllib.request.Request(url, headers={"User-Agent": "deluge-engine-gen-proto"})
    h = hashlib.sha256()
    with urllib.request.urlopen(req, timeout=120) as resp, open(dest, "wb") as out:
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            h.update(chunk)
            out.write(chunk)
    actual = h.hexdigest()
    if actual != expected_sha256:
        raise RuntimeError(f"SHA-256 mismatch for {url}: got {actual}, expected {expected_sha256}")


def ensure_protoc():
    """Return a Path to protoc matching the exact pinned version in proto/versions.json."""
    versions = load_versions()
    want = versions["protoc_version"]

    env_protoc = os.environ.get("PROTOC")
    if env_protoc:
        got = _protoc_version(env_protoc)
        if got == want:
            return Path(env_protoc)
        raise RuntimeError(f"PROTOC={env_protoc} has version {got!r}, expected {want!r}")

    on_path = shutil.which("protoc")
    if on_path and _protoc_version(on_path) == want:
        return Path(on_path)

    cached_dir = CACHE_ROOT / f"protoc-{want}"
    cached_bin = cached_dir / "bin/protoc"
    if cached_bin.is_file() and _protoc_version(cached_bin) == want:
        return cached_bin

    if sys.platform != "darwin":
        raise RuntimeError(
            f"protoc {want} not found on PATH and automatic download is only configured for macOS "
            f"(platform={platform.system()})"
        )

    url = f"https://github.com/protocolbuffers/protobuf/releases/download/v{want}/protoc-{want}-osx-universal_binary.zip"
    expected_sha = versions["protoc_osx_universal_sha256"]

    with _cache_lock(f"protoc-{want}"):
        if cached_bin.is_file() and _protoc_version(cached_bin) == want:
            return cached_bin
        tmp_dir = Path(tempfile.mkdtemp(prefix=f"protoc-{want}-", dir=CACHE_ROOT))
        try:
            archive = tmp_dir / "protoc.zip"
            _download_with_sha256(url, archive, expected_sha)
            extract_dir = tmp_dir / "unpacked"
            with zipfile.ZipFile(archive) as zf:
                zf.extractall(extract_dir)
            extracted_bin = extract_dir / "bin/protoc"
            if not extracted_bin.is_file():
                raise RuntimeError(f"downloaded {url} did not contain bin/protoc")
            extracted_bin.chmod(extracted_bin.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            if cached_dir.exists():
                shutil.rmtree(cached_dir)
            extract_dir.rename(cached_dir)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    got = _protoc_version(cached_bin)
    if got != want:
        raise RuntimeError(f"cached protoc at {cached_bin} reports version {got!r}, expected {want!r}")
    return cached_bin


def ensure_protoc_gen_dart():
    """Return a Path to protoc-gen-dart for the pinned protoc_plugin version."""
    versions = load_versions()
    want = versions["dart_protoc_plugin_version"]

    dart = shutil.which("dart")
    if not dart:
        raise RuntimeError("dart not found on PATH (needed to run pinned protoc_plugin for Dart codegen)")

    pub_cache = CACHE_ROOT / f"pub-cache-protoc_plugin-{want}"
    plugin_bin = pub_cache / "bin/protoc-gen-dart"
    marker = pub_cache / ".installed_version"

    if plugin_bin.is_file() and marker.is_file() and marker.read_text().strip() == want:
        return plugin_bin

    with _cache_lock(f"protoc_plugin-{want}"):
        if plugin_bin.is_file() and marker.is_file() and marker.read_text().strip() == want:
            return plugin_bin
        pub_cache.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, PUB_CACHE=str(pub_cache))
        r = subprocess.run(
            [dart, "pub", "global", "activate", "protoc_plugin", want],
            env=env,
            capture_output=True,
            text=True,
            timeout=180,
        )
        if r.returncode != 0:
            raise RuntimeError(f"dart pub global activate protoc_plugin {want} failed:\n{r.stdout}{r.stderr}")
        if not plugin_bin.is_file():
            raise RuntimeError(f"expected {plugin_bin} after dart pub global activate")
        marker.write_text(want + "\n")

    return plugin_bin


def _python_protobuf_version(python_exe):
    try:
        r = subprocess.run(
            [str(python_exe), "-c", "import google.protobuf as p; print(p.__version__)"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except OSError:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def ensure_python_protobuf():
    """Return a Python executable that has the pinned google.protobuf package installed."""
    versions = load_versions()
    want = versions["python_protobuf_version"]

    if _python_protobuf_version(sys.executable) == want:
        return sys.executable

    py_tag = f"py{sys.version_info.major}.{sys.version_info.minor}"
    venv_dir = CACHE_ROOT / f"venv-{py_tag}-pb{want}"
    venv_python = venv_dir / "bin/python"
    if venv_python.is_file() and _python_protobuf_version(venv_python) == want:
        return str(venv_python)

    with _cache_lock(f"venv-{py_tag}-pb{want}"):
        if venv_python.is_file() and _python_protobuf_version(venv_python) == want:
            return str(venv_python)
        tmp_venv = Path(tempfile.mkdtemp(prefix=f"venv-{py_tag}-pb{want}-", dir=CACHE_ROOT))
        try:
            subprocess.run([sys.executable, "-m", "venv", str(tmp_venv)], check=True,
                           capture_output=True, text=True, timeout=120)
            tmp_py = tmp_venv / "bin/python"
            r = subprocess.run(
                [str(tmp_py), "-m", "pip", "install", "--quiet", "--disable-pip-version-check",
                 f"protobuf=={want}"],
                capture_output=True,
                text=True,
                timeout=180,
            )
            if r.returncode != 0:
                raise RuntimeError(f"pip install protobuf=={want} failed:\n{r.stdout}{r.stderr}")
            if venv_dir.exists():
                shutil.rmtree(venv_dir)
            tmp_venv.rename(venv_dir)
        finally:
            shutil.rmtree(tmp_venv, ignore_errors=True)

    got = _python_protobuf_version(venv_python)
    if got != want:
        raise RuntimeError(f"venv python {venv_python} has protobuf {got!r}, expected {want!r}")
    return str(venv_python)
