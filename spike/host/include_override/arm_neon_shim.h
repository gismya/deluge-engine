// Host override: the firmware's shim re-declares the NEON types for clangd on 32-bit ARM. On arm64 the real header has them.
#pragma once
#include <arm_neon.h>
