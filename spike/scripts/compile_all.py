#!/usr/bin/env python3
"""Compile firmware sources with host Apple clang (arm64), one object per file, and log errors.

Usage: compile_all.py <outdir> [--only REGEX] [--extra-flag F ...] [--set NAME]
Writes <outdir>/obj/*.o, <outdir>/log/<file>.log and <outdir>/summary.txt.
"""
import argparse
import concurrent.futures as cf
import os
import re
import subprocess
import sys
from pathlib import Path

FW_ORIG = Path(os.environ.get("DELUGE_FW", Path.home() / ".cache/deluge-engine/firmware"))
FW = FW_ORIG  # replaced in main() by the patched tree: a copy of the firmware's src/ with spike/overlay on top
DEPS = Path(os.environ.get("DELUGE_DEPS", "/Users/larsjohansson/source/deluge-generative/build/_deps"))
SPIKE = Path(__file__).resolve().parent.parent

OVERLAY = SPIKE / "overlay"  # patched copies of firmware files: each is a seam/fix the firmware would need
INCLUDES = [
    SPIKE / "host/include_override",  # host replacements for hardware headers, searched first
    FW / "src/OSLikeStuff",
    FW / "src",
    SPIKE / "gen",
    FW / "src/deluge",
    DEPS / "argon-src/include",
    FW / "src/fatfs",
    FW / "src/NE10/inc",
    FW / "src/lib",
]
SYSTEM_INCLUDES = [DEPS / "etl-src/include"]

COMMON = [
    "-arch", "arm64", "-O1", "-g", "-fsigned-char", "-ffast-math", "-D_GNU_SOURCE", "-DUSE_TASK_MANAGER", "-DDELUGE_HOST=1",
    "-ferror-limit=0", "-fno-color-diagnostics", "-Wno-everything",
    # Downgrades clang's hard error on pointer-to-uint32_t casts to a warning (truncating at run time).
    "-fms-extensions",
    # ELF section names (PLACE_SDRAM_BSS etc. in src/definitions.h) are invalid on Mach-O; aligned(1) is a no-op.
    "-D__section__(x)=aligned(1)",
    "-include", str(SPIKE / "host/force/host_prefix.h"),
]
PER_FILE = {
    "src/deluge/dsp/dx/env.cpp": ["-include", str(SPIKE / "host/force/dx_unity.h")],
}
CXX = ["/usr/bin/clang++", "-std=gnu++23", "-fno-rtti", "-fno-threadsafe-statics"]
C = ["/usr/bin/clang", "-std=gnu2x"]


# Hardware-only or replaced by host code in spike/host.
EXCLUDE = [
    r"^src/deluge/drivers/", r"^src/main\.c$", r"^src/(malloc|memmove|sys_stubs)\.c$", r"^src/(terminate|cpp_handler)\.cpp$",
    r"^src/OSLikeStuff/timers_interrupts/timers_interrupts\.c$", r"^src/OSLikeStuff/fault_handler/",
    r"^src/deluge/memory/(general_memory_allocator|memory_region)\.cpp$",
]


def sources(set_name):
    deluge = FW / "src/deluge"
    out = []
    if set_name in ("all", "deluge"):
        out += sorted(p for p in deluge.rglob("*") if p.suffix in (".c", ".cpp"))
    if set_name == "all":
        for sub in ("OSLikeStuff", "fatfs", "lib"):
            out += sorted(p for p in (FW / "src" / sub).rglob("*") if p.suffix in (".c", ".cpp"))
        # NE10: the sources src/NE10/CMakeLists.txt lists (minus its .s headers)
        ne10 = (FW / "src/NE10/CMakeLists.txt").read_text()
        out += [FW / "src/NE10" / m for m in re.findall(r"^\s+(\S+\.(?:c|cpp))\s*$", ne10, re.M)]
        out += [FW / "src" / f for f in ("main.c", "malloc.c", "terminate.cpp", "memmove.c", "cpp_handler.cpp", "sys_stubs.c")]
    out = [p for p in out if not any(re.search(e, str(p.relative_to(FW))) for e in EXCLUDE)]
    return out


def compile_one(src, outdir, extra):
    rel = src.relative_to(FW) if src.is_relative_to(FW) else Path("host") / src.name
    obj = outdir / "obj" / (str(rel).replace("/", "__") + ".o")
    log = outdir / "log" / (str(rel).replace("/", "__") + ".log")
    base = CXX if src.suffix == ".cpp" else C
    cmd = base + COMMON + extra + PER_FILE.get(str(rel), [])
    cmd += [f"-I{p}" for p in INCLUDES] + [f"-isystem{p}" for p in SYSTEM_INCLUDES]
    cmd += ["-c", str(src), "-o", str(obj)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    log.write_text(r.stderr)
    nerr = len(re.findall(r": (?:fatal )?error:", r.stderr))
    return str(rel), r.returncode, nerr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir")
    ap.add_argument("--only", default=None)
    ap.add_argument("--exclude", default=None)
    ap.add_argument("--set", default="all")
    ap.add_argument("--extra", action="append", default=[])
    ap.add_argument("--link", default=None, help="link every object into this executable")
    a = ap.parse_args()
    outdir = Path(a.outdir)
    global FW, INCLUDES
    tree = outdir / "tree"
    subprocess.run(["rsync", "-a", "--delete", f"{FW_ORIG}/src", f"{tree}/"], check=True)
    subprocess.run(["rsync", "-a", f"{OVERLAY}/src", f"{tree}/"], check=True)
    INCLUDES = [Path(str(p).replace(str(FW_ORIG), str(tree))) for p in INCLUDES]
    FW = tree
    (outdir / "obj").mkdir(parents=True, exist_ok=True)
    (outdir / "log").mkdir(parents=True, exist_ok=True)
    srcs = sources(a.set)
    if a.set == "all":
        srcs += sorted(p for p in (SPIKE / "host").glob("*") if p.suffix in (".c", ".cpp"))
    if a.only:
        srcs = [s for s in srcs if re.search(a.only, str(s))]
    if a.exclude:
        srcs = [s for s in srcs if not re.search(a.exclude, str(s))]
    results = []
    with cf.ThreadPoolExecutor(max_workers=os.cpu_count()) as ex:
        for r in ex.map(lambda s: compile_one(s, outdir, a.extra), srcs):
            results.append(r)
    ok = [r for r in results if r[1] == 0]
    bad = sorted((r for r in results if r[1] != 0), key=lambda r: -r[2])
    with open(outdir / "summary.txt", "w") as f:
        f.write(f"total {len(results)} ok {len(ok)} failed {len(bad)} errors {sum(r[2] for r in bad)}\n")
        for r in bad:
            f.write(f"{r[2]:5d} {r[0]}\n")
    print(open(outdir / "summary.txt").read()[:4000])
    if a.link and not bad:
        objs = sorted(str(p) for p in (outdir / "obj").glob("*.o"))
        r = subprocess.run(["/usr/bin/clang++", "-arch", "arm64", "-Wl,-dead_strip", *objs, "-o", a.link],
                           capture_output=True, text=True)
        (outdir / "link.log").write_text(r.stderr)
        undef = sorted(set(re.findall(r'^\s+"([^"]+)", referenced from', r.stderr, re.M)))
        print(f"link rc={r.returncode} undefined={len(undef)}")
        for u in undef:
            print("  ", u)


if __name__ == "__main__":
    sys.exit(main())
