// Host memory the generated RZA1/cpu_specific.h points at (gen_host_headers.py).
#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// UNUSED_MEMORY_SPACE_ADDRESS: voice_sample.cpp writes a stolen cache's samples here to throw them away.
extern char host_unused_memory_space[];
#ifdef __cplusplus
}
#endif
