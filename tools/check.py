#!/usr/bin/env python3
"""Run every check CI runs (spec §11). Run it before pushing.

    python3 tools/check.py                    everything
    python3 tools/check.py --only guards      one step or more (comma-separated): see STEPS
    python3 tools/check.py --firmware-dir ~/source/deluge-generative-wt   build against another firmware checkout

Steps, in order (each has a timeout, and the first failure stops the run):
  guards         the factory-content guard, the protobuf codegen check, the tool tests, the startup text-hash guard
  asan           configure and build build/asan (ASan + UBSan, -O1), check its includes, run platform, storage, smoke and protocol tests
  release        the same for build/release (-O2)
  pointer-keys   the firmware's PointerKeyTests (tests/unit/pointer_keys), built natively: 64-bit, which the
                 firmware's own CI never runs (it builds its tests -m32)

Logs go to build/check/. Needs cmake (3.25+) and, if found, ninja. When they aren't on PATH, the firmware's dbt
toolchain (firmware/toolchain/current, or ~/source/deluge-generative/toolchain/current) is used.
"""

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / "build/check"
sys.path.insert(0, str(ROOT / "tools"))
import proto_env  # noqa: E402

CONFIGURE_TIMEOUT_S = 900  # the first configure clones argon and etl
BUILD_TIMEOUT_S = 3600
TEST_TIMEOUT_S = 900

FACTORY_SUFFIXES = (".wav", ".img")


class StepFailed(Exception):
    pass


def factory_violations(repo):
    """Tracked files that may hold factory content: anything under build/, any WAV, any card image. References in
    this repo are metrics, not audio; CC0 audio comes from the firmware's pack/, and fixtures that must be audio are
    generated at test time (spec §2)."""
    out = subprocess.run(["git", "-C", str(repo), "ls-files", "-z"], check=True, capture_output=True, text=True)
    paths = [p for p in out.stdout.split("\0") if p]
    return sorted(p for p in paths if p.lower().startswith("build/") or p.lower().endswith(FACTORY_SUFFIXES))


def find_tool(name, subdir):
    found = shutil.which(name)
    if found:
        return found
    for base in (ROOT / "firmware/toolchain/current", Path.home() / "source/deluge-generative/toolchain/current"):
        candidate = base / subdir / name
        if candidate.exists():
            return str(candidate)
    return None


def run(cmd, log, timeout, cwd=ROOT, env=None):
    LOGS.mkdir(parents=True, exist_ok=True)
    path = LOGS / log
    t0 = time.monotonic()
    with open(path, "w") as f:
        f.write("$ " + " ".join(str(c) for c in cmd) + "\n")
        f.flush()
        try:
            r = subprocess.run([str(c) for c in cmd], cwd=cwd, env=env, stdout=f, stderr=subprocess.STDOUT,
                               timeout=timeout)
        except subprocess.TimeoutExpired:
            raise StepFailed(f"{log}: timed out after {timeout} s (log: {path})")
    if r.returncode != 0:
        tail = path.read_text(errors="replace").splitlines()[-30:]
        raise StepFailed(f"{log}: exit {r.returncode} after {time.monotonic() - t0:.0f} s (log: {path})\n"
                         + "\n".join("    " + line for line in tail))
    print(f"  ok  {log} ({time.monotonic() - t0:.0f} s)")


class Checker:
    def __init__(self, firmware_dir, jobs):
        self.firmware_dir = Path(firmware_dir).resolve() if firmware_dir else ROOT / "firmware"
        self.jobs = jobs
        self.cmake = find_tool("cmake", "cmake/bin")
        self.ninja = find_tool("ninja", "ninja-build/bin")
        if not self.cmake:
            raise StepFailed("cmake not found (PATH, or the firmware's dbt toolchain)")
        # The tests read the firmware (pack/, fat_image.py, deluge.cpp, the RZ/A1 headers) from here too.
        self.env = dict(os.environ, DELUGE_FIRMWARE_DIR=str(self.firmware_dir))
        if self.ninja:
            self.env["PATH"] = str(Path(self.ninja).parent) + os.pathsep + self.env.get("PATH", "")
        self._proto_python = None

    def proto_python(self):
        if self._proto_python is None:
            try:
                self._proto_python = proto_env.ensure_python_protobuf()
            except Exception as e:
                raise StepFailed(f"python protobuf environment: {e}") from e
        return self._proto_python

    def generator(self):
        return ["-G", "Ninja"] if self.ninja else []

    def build_command(self, build_dir, target=None):
        cmd = [self.cmake, "--build", build_dir, "--parallel", str(self.jobs)]
        return cmd + (["--target", target] if target else [])

    # ---- steps
    def guards(self):
        bad = factory_violations(ROOT)
        if bad:
            raise StepFailed("factory-content guard: tracked files that must never be committed (build output, "
                             "*.wav, *.img):\n" + "\n".join("    " + p for p in bad))
        print("  ok  factory-content guard")
        run([sys.executable, "tools/gen_proto.py", "--check"], "proto-check.log", 180, env=self.env)
        run([self.proto_python(), "-m", "unittest", "discover", "-s", "tests/tools", "-t", "."], "tool-tests.log",
            TEST_TIMEOUT_S, env=self.env)
        run([sys.executable, "tools/startup_guard.py", "--source", self.firmware_dir / "src/deluge/deluge.cpp"],
            "startup-guard.log", 60)

    def engine(self, name, cmake_args):
        build_dir = ROOT / "build" / name
        run([self.cmake, "-S", ROOT, "-B", build_dir, *self.generator(), f"-DDELUGE_FIRMWARE_DIR={self.firmware_dir}",
             *cmake_args], f"{name}-configure.log", CONFIGURE_TIMEOUT_S, env=self.env)
        run(self.build_command(build_dir), f"{name}-build.log", BUILD_TIMEOUT_S, env=self.env)
        self.check_includes(build_dir)
        env = dict(self.env, DELUGE_ENGINE_BUILD=str(build_dir))
        run([sys.executable, "-m", "unittest", "discover", "-v", "-s", "tests/platform", "-t", "."],
            f"{name}-platform.log", TEST_TIMEOUT_S, env=env)
        run([sys.executable, "-m", "unittest", "discover", "-v", "-s", "tests/storage", "-t", "."],
            f"{name}-storage.log", TEST_TIMEOUT_S, env=env)
        run([sys.executable, "-m", "unittest", "discover", "-v", "-s", "tests/smoke", "-t", "."],
            f"{name}-smoke.log", TEST_TIMEOUT_S, env=env)
        run([self.proto_python(), "-m", "unittest", "discover", "-v", "-s", "tests/protocol", "-t", "."],
            f"{name}-protocol.log", TEST_TIMEOUT_S, env=env)

    def check_includes(self, build_dir):
        """No translation unit may read the firmware's own register headers: the generated host ones replace them
        (spec §3.3). Read from ninja's dependency log, so it needs a Ninja build."""
        if not self.ninja:
            print("  --  include check skipped (needs ninja)")
            return
        deps = subprocess.run([self.ninja, "-C", str(build_dir), "-t", "deps"], capture_output=True, text=True,
                              timeout=120, check=True).stdout
        # Resolved on both sides: ninja logs paths as the compiler saw them (symlinks, "..").
        firmware_headers = os.path.realpath(self.firmware_dir / "src/RZA1/system") + "/iodefine"
        bad = sorted({path for path in (os.path.realpath(line.strip()) for line in deps.splitlines()
                                        if line.startswith(" ") and line.strip())
                      if path.startswith(firmware_headers)})
        if bad:
            raise StepFailed("include check: the firmware's own register headers were compiled in, not the host "
                             "ones:\n" + "\n".join("    " + b for b in bad))
        print(f"  ok  include check ({build_dir.name})")

    def pointer_keys(self):
        build_dir = ROOT / "build/firmware-tests"
        run([self.cmake, "-S", self.firmware_dir / "tests", "-B", build_dir, *self.generator(),
             "-DCMAKE_BUILD_TYPE=Debug"], "pointer-keys-configure.log", CONFIGURE_TIMEOUT_S, env=self.env)
        run(self.build_command(build_dir, "PointerKeyTests"), "pointer-keys-build.log", BUILD_TIMEOUT_S, env=self.env)
        binary = next(build_dir.rglob("PointerKeyTests"), None)
        if binary is None:
            raise StepFailed("pointer-keys: no PointerKeyTests binary after the build")
        run([binary], "pointer-keys-run.log", TEST_TIMEOUT_S)


STEPS = {
    "guards": lambda c: c.guards(),
    "asan": lambda c: c.engine("asan", ["-DCMAKE_BUILD_TYPE=Debug", "-DDELUGE_SANITIZE=ON"]),
    "release": lambda c: c.engine("release", ["-DCMAKE_BUILD_TYPE=Release", "-DDELUGE_SANITIZE=OFF"]),
    "pointer-keys": lambda c: c.pointer_keys(),
}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="comma-separated steps: " + ", ".join(STEPS))
    ap.add_argument("--firmware-dir", help="build against this firmware checkout instead of the submodule")
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    a = ap.parse_args(argv)
    steps = a.only.split(",") if a.only else list(STEPS)
    unknown = [s for s in steps if s not in STEPS]
    if unknown:
        ap.error(f"unknown step(s): {', '.join(unknown)}")
    t0 = time.monotonic()
    try:
        checker = Checker(a.firmware_dir, a.jobs)
        for step in steps:
            print(f"== {step}")
            STEPS[step](checker)
    except StepFailed as e:
        print(f"FAIL {e}", file=sys.stderr)
        return 1
    print(f"PASS ({', '.join(steps)}) in {time.monotonic() - t0:.0f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
