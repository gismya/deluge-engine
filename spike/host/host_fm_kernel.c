// Scalar port of src/deluge/dsp/dx/neon_fm_kernel.s (ARMv7 NEON assembly, can't build for arm64).
// Same arithmetic in the same order: integer phase, float cubic-in-t^2 sine, float gain ramp stepped per 4 samples,
// truncating float->q24 conversion, ones-complement sign via XOR. ARMv7 NEON flushes denormals and never fuses
// multiply-add; the pragmas keep clang from fusing or reassociating (the build uses -ffast-math).
#include <stdint.h>

#pragma clang fp contract(off)
#pragma clang fp reassociate(off)

static const float c0 = -0.01880853017455781f, c1 = 0.25215252666796095f, c2 = -1.2333439964934032f, c3 = 1.0f;

static int32_t cvt_s32_q24(float f) {
	float s = f * 16777216.0f; // exact: power of two
	if (s >= 2147483647.0f) {
		return INT32_MAX;
	}
	if (s <= -2147483648.0f) {
		return INT32_MIN;
	}
	return (int32_t)s; // vcvt with fbits rounds toward zero
}

void neon_fm_kernel(const int32_t* in, const int32_t* busin, int32_t* out, int count, int32_t phase0, int32_t freq,
                    int32_t gain1, int32_t dgain) {
	float gainLane[4];
	for (int j = 0; j < 4; j++) {
		gainLane[j] = (float)(int32_t)((uint32_t)gain1 + (uint32_t)dgain * j) / 16777216.0f;
	}
	const float gainStep = (float)dgain / 4194304.0f; // vcvt.f32.s32 #22
	uint32_t phase = (uint32_t)phase0;
	for (int i = 0; i < count; i++) {
		int lane = i & 3;
		if (i > 0 && lane == 0) {
			for (int j = 0; j < 4; j++) {
				gainLane[j] = gainLane[j] + gainStep;
			}
		}
		uint32_t x = (uint32_t)in[i] + phase;
		int32_t signMask = (x & 0x800000) ? -1 : 0;
		float t = (float)((int32_t)(x & 0x7fffff) - 0x400000) / 4194304.0f;
		float t2 = t * t;
		float p = c1 + t2 * c0;
		p = c2 + t2 * p;
		p = c3 + t2 * p;
		float y = p * gainLane[lane];
		out[i] = (cvt_s32_q24(y) ^ signMask) + busin[i];
		phase += (uint32_t)freq;
	}
}
