"""gen_host_headers.py: host register headers, and its guard against raw peripheral addresses."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "engine/platform/gen_host_headers.py"
FIRMWARE_SRC = Path(os.environ.get("DELUGE_FIRMWARE_DIR", ROOT / "firmware")) / "src"

CPU_SPECIFIC = """#ifndef SYSTEM_CPU_SPECIFIC_H_
#define SYSTEM_CPU_SPECIFIC_H_
#define UNUSED_MEMORY_SPACE_ADDRESS 0x08000000
#define UNCACHED_MIRROR_OFFSET 0x40000000
#endif
"""
TOP = '#include "RZA1/system/r_typedefs.h"\n#include "iodefines/x_iodefine.h"\n'


def fake_firmware(root, peripheral_header):
    system = root / "RZA1/system"
    (system / "iodefines").mkdir(parents=True)
    (root / "RZA1/cpu_specific.h").write_text(CPU_SPECIFIC)
    (system / "iodefine.h").write_text(TOP)
    (system / "iodefines/x_iodefine.h").write_text(peripheral_header)


def run(src, out):
    return subprocess.run([sys.executable, str(SCRIPT), str(src), str(out)], capture_output=True, text=True)


class GenHostHeaders(unittest.TestCase):
    def test_register_blocks_move_to_host_ram(self):
        with tempfile.TemporaryDirectory() as d:
            src, out = Path(d) / "src", Path(d) / "out"
            fake_firmware(src, "#define MTU2 (*(struct st_mtu2 *)0xFCFF0000uL) /* MTU2 at 0xFCFF0000 */\n"
                               "#define PORTn_BASE\t0xFCFE3000\n")
            r = run(src, out)
            self.assertEqual(r.returncode, 0, r.stderr)
            text = (out / "RZA1/system/iodefines/x_iodefine.h").read_text()
            self.assertIn("(*(struct st_mtu2 *)HOST_IO(0xFCFF0000u))", text)
            self.assertIn("PORTn_BASE\tHOST_IO(0xFCFE3000u)", text)
            self.assertIn('#include "host_io.h"', (out / "RZA1/system/iodefine.h").read_text())
            cpu = (out / "RZA1/cpu_specific.h").read_text()
            self.assertIn("#define UNCACHED_MIRROR_OFFSET 0\n", cpu)
            self.assertIn("#define UNUSED_MEMORY_SPACE_ADDRESS ((uintptr_t)host_unused_memory_space)", cpu)

    def test_fails_when_a_raw_address_survives(self):
        # An address on a macro's continuation line isn't on a #define line, so it isn't rewritten.
        with tempfile.TemporaryDirectory() as d:
            src, out = Path(d) / "src", Path(d) / "out"
            fake_firmware(src, "#define DMAC0 \\\n    (*(struct st_dmac *)0xE8200000uL)\n")
            r = run(src, out)
            self.assertEqual(r.returncode, 1)
            self.assertIn("0xE8200000", r.stderr)

    def test_fails_on_an_address_outside_the_mapped_windows(self):
        # host_io.h maps 0x3FE00000-0x3FFFFFFF only; a lower 0x3F address would underflow its offset.
        with tempfile.TemporaryDirectory() as d:
            src, out = Path(d) / "src", Path(d) / "out"
            fake_firmware(src, "#define ODD (*(struct st_odd *)0x3F000000uL)\n")
            r = run(src, out)
            self.assertEqual(r.returncode, 1)
            self.assertIn("0x3F000000", r.stderr)

    def test_writes_nothing_when_it_fails(self):
        # A retried build must not find a broken header that looks up to date.
        with tempfile.TemporaryDirectory() as d:
            src, out = Path(d) / "src", Path(d) / "out"
            fake_firmware(src, "#define DMAC0 \\\n    (*(struct st_dmac *)0xE8200000uL)\n")
            self.assertEqual(run(src, out).returncode, 1)
            self.assertFalse(out.exists() and any(p.is_file() for p in out.rglob("*")))

    def test_the_pinned_firmware_leaves_no_raw_address(self):
        with tempfile.TemporaryDirectory() as d:
            r = run(FIRMWARE_SRC, Path(d))
            self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()
