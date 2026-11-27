#!/usr/bin/env python3
"""Generate (or verify) committed Python and Dart protobuf bindings from proto/engine.proto (spec §7.1).

    python3 tools/gen_proto.py            regenerate tools/proto_gen/ and gui/lib/proto/
    python3 tools/gen_proto.py --check    fail if regenerating would change any committed file

Tool versions are pinned in proto/versions.json. C++ protobuf code is generated at build time by CMake.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import proto_env  # noqa: E402

DEFAULT_PROTO = ROOT / "proto/engine.proto"
DEFAULT_PYTHON_OUT = ROOT / "tools/proto_gen"
DEFAULT_DART_OUT = ROOT / "gui/lib/proto"

INIT_PY_CONTENT = '"""Generated protobuf bindings for proto/engine.proto (do not edit; run tools/gen_proto.py)."""\n'


def generate_into(proto_path, py_dir, dart_dir):
    proto_path = Path(proto_path).resolve()
    py_dir = Path(py_dir)
    dart_dir = Path(dart_dir)
    py_dir.mkdir(parents=True, exist_ok=True)
    dart_dir.mkdir(parents=True, exist_ok=True)

    protoc = proto_env.ensure_protoc()
    protoc_gen_dart = proto_env.ensure_protoc_gen_dart()

    # Pass PUB_CACHE matching the cached protoc_plugin so Dart resolves its snapshot cleanly.
    env = dict(os.environ, PUB_CACHE=str(protoc_gen_dart.parent.parent))

    cmd = [
        str(protoc),
        f"--proto_path={proto_path.parent}",
        f"--python_out={py_dir}",
        f"--plugin=protoc-gen-dart={protoc_gen_dart}",
        f"--dart_out={dart_dir}",
        str(proto_path),
    ]
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        raise RuntimeError(f"protoc failed (exit {r.returncode}):\n{r.stdout}{r.stderr}")

    (py_dir / "__init__.py").write_text(INIT_PY_CONTENT)


def _snapshot_tree(root):
    root = Path(root)
    if not root.exists():
        return {}
    files = {}
    for p in sorted(root.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(root).as_posix()
        if "__pycache__/" in rel or rel.endswith(".pyc"):
            continue
        files[rel] = p.read_bytes()
    return files


def _diff_dirs(label, expected_dir, actual_dir):
    expected = _snapshot_tree(expected_dir)
    actual = _snapshot_tree(actual_dir)
    diffs = []
    for rel in sorted(set(expected) | set(actual)):
        if rel not in actual:
            diffs.append(f"  missing  {label}/{rel}")
        elif rel not in expected:
            diffs.append(f"  extra    {label}/{rel}")
        elif expected[rel] != actual[rel]:
            diffs.append(f"  changed  {label}/{rel}")
    return diffs


def _sync_dir(src_dir, dst_dir):
    src_dir = Path(src_dir)
    dst_dir = Path(dst_dir)
    expected = _snapshot_tree(src_dir)
    dst_dir.mkdir(parents=True, exist_ok=True)
    # Remove stale files first (excluding __pycache__).
    for rel in list(_snapshot_tree(dst_dir)):
        if rel not in expected:
            os.remove(dst_dir / rel)
    for rel, data in expected.items():
        target = dst_dir / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="verify committed generated files match proto/engine.proto")
    ap.add_argument("--proto", type=Path, default=DEFAULT_PROTO)
    ap.add_argument("--python-out", type=Path, default=DEFAULT_PYTHON_OUT)
    ap.add_argument("--dart-out", type=Path, default=DEFAULT_DART_OUT)
    args = ap.parse_args(argv)

    with tempfile.TemporaryDirectory(prefix="deluge_gen_proto_") as tmp:
        tmp_py = Path(tmp) / "py"
        tmp_dart = Path(tmp) / "dart"
        try:
            generate_into(args.proto, tmp_py, tmp_dart)
        except Exception as e:
            print(f"gen_proto: {e}", file=sys.stderr)
            return 1

        if args.check:
            diffs = []
            diffs.extend(_diff_dirs(str(args.python_out), tmp_py, args.python_out))
            diffs.extend(_diff_dirs(str(args.dart_out), tmp_dart, args.dart_out))
            if diffs:
                print("Generated protobuf files are out of date. Run `python3 tools/gen_proto.py`:", file=sys.stderr)
                for line in diffs:
                    print(line, file=sys.stderr)
                return 1
            print("gen_proto: Python and Dart bindings are up to date.")
            return 0

        _sync_dir(tmp_py, args.python_out)
        _sync_dir(tmp_dart, args.dart_out)
        print(f"gen_proto: wrote {args.python_out} and {args.dart_out}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
