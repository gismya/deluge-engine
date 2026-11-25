#!/usr/bin/env python3
"""Generate the host versions of the firmware's RZ/A1 headers into a build folder.

    gen_host_headers.py FIRMWARE_SRC OUT_DIR

Writes, under OUT_DIR:
- RZA1/system/iodefine.h and RZA1/system/iodefines/*.h: every peripheral address (0xE8......, 0xFC......,
  0x3FE00000-0x3FFFFFFF) on a #define line points into host RAM through HOST_IO() (host_io.h, host_memory.c), so firmware code
  outside drivers/ that touches a register reads zeros and writes land in RAM instead of faulting.
- RZA1/cpu_specific.h: UNCACHED_MIRROR_OFFSET is 0 (the host has no uncached mirror) and UNUSED_MEMORY_SPACE_ADDRESS
  is a host scratch buffer (voice_sample.cpp writes through it).

The firmware tree is never written. OUT_DIR goes first on the include path, and the host prefix header pre-includes
the generated cpu_specific.h (spec §3.3).

Fails (exit 1), writing nothing, if a raw peripheral address (0xE8/0xFC/0x3F......) survives in the output outside
comments: a header shape this script doesn't know, or an address outside the mapped windows, would otherwise fault at
run time, far from the cause.
"""

import re
import sys
from pathlib import Path

# Addresses in the windows host_io.h maps: 0xE8000000-0xE8FFFFFF, 0xFC000000-0xFCFFFFFF, 0x3FE00000-0x3FFFFFFF.
ADDRESS = re.compile(r"\b(0x(?:E8[0-9A-Fa-f]{6}|FC[0-9A-Fa-f]{6}|3F[EFef][0-9A-Fa-f]{5}))(uL|UL|u|U)?\b")
# Any peripheral-looking address left unwrapped, inside the windows or not (a lower 0x3F address would underflow
# HOST_IO_OFFSET, so it must fail here rather than be rewritten).
RAW_ADDRESS = re.compile(r"(?<!HOST_IO\()\b(0x(?:3F|E8|FC)[0-9A-Fa-f]{6})(uL|UL|u|U)?\b")
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
    bad, outputs = [], {}
    for f in [system / "iodefine.h", *sorted((system / "iodefines").glob("*.h"))]:
        text = host_iodefine(f.read_text(errors="replace"), f.name == "iodefine.h")
        rel = f.relative_to(src)
        bad += [f"{rel}: {a[0]}" for a in surviving_addresses(text)]
        outputs[out / rel] = text
    outputs[out / "RZA1/cpu_specific.h"] = host_cpu_specific((src / "RZA1/cpu_specific.h").read_text())
    # Check before writing: a failed run must leave no new header that a retried build takes as up to date.
    if bad:
        print("gen_host_headers: raw peripheral addresses survive in the host headers:", file=sys.stderr)
        print("\n".join("  " + b for b in bad), file=sys.stderr)
        return 1
    for dest, text in outputs.items():
        write(dest, text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
