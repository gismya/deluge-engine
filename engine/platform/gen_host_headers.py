#!/usr/bin/env python3
"""Generate the host versions of the firmware's RZ/A1 headers into a build folder.

    gen_host_headers.py FIRMWARE_SRC OUT_DIR

Writes, under OUT_DIR:
- RZA1/system/iodefine.h and RZA1/system/iodefines/*.h: every peripheral address (0xE8......, 0xFC......,
  0x3F......) on a #define line points into host RAM through HOST_IO() (host_io.h, host_io.c), so firmware code
  outside drivers/ that touches a register reads zeros and writes land in RAM instead of faulting.
- RZA1/cpu_specific.h: UNCACHED_MIRROR_OFFSET is 0 (the host has no uncached mirror) and UNUSED_MEMORY_SPACE_ADDRESS
  is a host scratch buffer (voice_sample.cpp writes through it).

The firmware tree is never written. OUT_DIR goes first on the include path, and the host prefix header pre-includes
the generated cpu_specific.h (spec §3.3).

Fails (exit 1) if a raw peripheral address survives in the output, outside comments: a header shape this script
doesn't know would otherwise fault at run time, far from the cause.
"""

import re
import sys
from pathlib import Path

ADDRESS = re.compile(r"\b(0x(?:3F|E8|FC)[0-9A-Fa-f]{6})(uL|UL|u|U)?\b")
RAW_ADDRESS = re.compile(r"(?<!HOST_IO\()" + ADDRESS.pattern)
COMMENT = re.compile(r"/\*.*?\*/|//.*$", re.S | re.M)


def host_iodefine(text, is_top):
    lines = []
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith("#define"):
            line = ADDRESS.sub(lambda m: f"HOST_IO({m.group(1)}u)", line)
        lines.append(line)
    out = "".join(lines)
    if is_top:
        return out.replace(
            '#include "RZA1/system/r_typedefs.h"',
            '#include "RZA1/system/r_typedefs.h"\n#include "host_io.h"',
        )
    return '#include "host_io.h"\n' + out


def host_cpu_specific(text):
    text, n1 = re.subn(r"(#define UNCACHED_MIRROR_OFFSET\s+)0x40000000\b", r"\g<1>0", text)
    text, n2 = re.subn(
        r"(#define UNUSED_MEMORY_SPACE_ADDRESS\s+)0x08000000\b",
        r"\g<1>((uintptr_t)host_unused_memory_space)",
        text,
    )
    if n1 != 1 or n2 != 1:
        raise SystemExit("gen_host_headers: cpu_specific.h no longer has the UNCACHED_MIRROR_OFFSET and "
                         "UNUSED_MEMORY_SPACE_ADDRESS lines this script rewrites")
    return '#include "host_memory.h"\n' + text


def surviving_addresses(text):
    """Raw peripheral addresses left in code (comments stripped)."""
    return RAW_ADDRESS.findall(COMMENT.sub("", text))


def write(dest, text):
    """Writes only a changed file, so an incremental build keeps its objects."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists() or dest.read_text(errors="replace") != text:
        dest.write_text(text)


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, out = Path(argv[1]), Path(argv[2])
    system = src / "RZA1/system"
    bad = []
    for f in [system / "iodefine.h", *sorted((system / "iodefines").glob("*.h"))]:
        text = host_iodefine(f.read_text(errors="replace"), f.name == "iodefine.h")
        rel = f.relative_to(src)
        for a in surviving_addresses(text):
            bad.append(f"{rel}: {a[0]}")
        write(out / rel, text)
    write(out / "RZA1/cpu_specific.h", host_cpu_specific((src / "RZA1/cpu_specific.h").read_text()))
    if bad:
        print("gen_host_headers: raw peripheral addresses survive in the host headers:", file=sys.stderr)
        print("\n".join("  " + b for b in bad), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
