// Host RAM for the register blocks (host_io.h) and the firmware's throwaway write target (host_memory.h).
#include "host_io.h"
#include "host_memory.h"

char host_io_space[0x2200000] __attribute__((aligned(4096)));
// A voice writes at most one render window (128 frames, 2 channels, 3 bytes) past the start; 64 KiB is plenty.
char host_unused_memory_space[0x10000] __attribute__((aligned(16)));
