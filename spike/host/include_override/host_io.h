// Peripheral register blocks live in host RAM (see spike/scripts/gen_io_overrides.py and host_io.c).
// Windows: 0xE8000000-0xE8FFFFFF at offset 0, 0xFC000000-0xFCFFFFFF at 16 MiB, 0x3FE00000-0x3FFFFFFF at 32 MiB.
#pragma once
#ifdef __cplusplus
extern "C" {
#endif
extern char host_io_space[];
#ifdef __cplusplus
}
#endif
#define HOST_IO_OFFSET(a)                                                                                              \
	((a) >= 0xFC000000u ? (a) - 0xFC000000u + 0x1000000u                                                               \
	                    : ((a) >= 0xE8000000u ? (a) - 0xE8000000u : (a) - 0x3FE00000u + 0x2000000u))
#define HOST_IO(a) ((unsigned long)(host_io_space + HOST_IO_OFFSET(a)))
