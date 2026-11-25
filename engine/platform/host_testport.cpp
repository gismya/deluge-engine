// Host stand-ins that the test port (ENABLE_SYSEX_TEST, on in every Engine build: spec §2) links against.
#include "drivers/dmac/dmac.h"

// The DMA channels a chainloading firmware left running (dmac.c records them at boot): none on the host, so the test
// port's "report boot_dma" says running=0.
struct DmaBootState dmaBootStates[NUM_DMA_CHANNELS];
