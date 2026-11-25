// Force-included (-include) first in every firmware and host translation unit.
#pragma once

// Compile in place (spec §3.3): src/definitions.h includes its sibling "RZA1/cpu_specific.h", which beats any -I
// directory. Including the generated host version first defines its include guard (SYSTEM_CPU_SPECIFIC_H_), so the
// firmware's own copy becomes a no-op. The generated folder is first on the include path, so this finds it.
#include "RZA1/cpu_specific.h"
#ifndef UNCACHED_MIRROR_OFFSET
#error "host_prefix.h: the host cpu_specific.h was not the one included"
#endif
#if UNCACHED_MIRROR_OFFSET != 0
#error "host_prefix.h: the firmware's cpu_specific.h was included instead of the generated host one"
#endif

// src/arm_neon_shim.h re-declares the 32-bit NEON types for clangd; on arm64 they clash with <arm_neon.h>, which has
// them all. Defining its guard turns the shim into a no-op.
#if defined(__aarch64__)
#include <arm_neon.h>
#define ARM_NEON_SHIM_H
#endif
