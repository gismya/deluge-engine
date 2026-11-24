#!/usr/bin/env python3
"""Generate host copies of src/RZA1/system/iodefine.h and iodefines/*.h whose peripheral addresses point into a
host RAM block (host_io_space, spike/host/host_io.c) instead of the RZ/A1's fixed register addresses.

Firmware code outside drivers/ still touches registers directly (seedRandom reads MTU2 TCNT_0, the MIDI gate timer
writes TGRA, the OLED code drives DMA), and those would fault on the host. With this, reads see zeros and writes
land in RAM. Usage: gen_io_overrides.py <firmware src dir> <out include dir>
"""
import re
import sys
from pathlib import Path

src = Path(sys.argv[1]) / "RZA1/system"
out = Path(sys.argv[2]) / "RZA1/system"
(out / "iodefines").mkdir(parents=True, exist_ok=True)

addr = re.compile(r"\b(0x(?:3F|E8|FC)[0-9A-Fa-f]{6})(uL|UL|u|U)?\b")
for f in [src / "iodefine.h", *sorted((src / "iodefines").glob("*.h"))]:
    text = f.read_text(errors="replace")
    lines = []
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith("#define") and "*)" in line:
            line = addr.sub(lambda m: f"HOST_IO({m.group(1)}u)", line)
        lines.append(line)
    text = "".join(lines)
    if f.name == "iodefine.h":
        text = text.replace('#include "RZA1/system/r_typedefs.h"',
                            '#include "RZA1/system/r_typedefs.h"\n#include "host_io.h"')
    dest = out / f.relative_to(src)
    dest.write_text(text)
    if f.name != "iodefine.h":
        dest.write_text('#include "host_io.h"\n' + text)

# The uncached mirror of on-chip RAM (+0x40000000) doesn't exist on the host: buffers are used at their own address.
cpu = (Path(sys.argv[1]) / "RZA1/cpu_specific.h").read_text()
cpu = re.sub(r"(#define UNCACHED_MIRROR_OFFSET\s+)0x40000000", r"\g<1>0", cpu)
(Path(sys.argv[2]) / "RZA1/cpu_specific.h").write_text(cpu)
