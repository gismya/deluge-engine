// Host RAM standing in for the RZ/A1 peripheral register space (see include_override/host_io.h).
char host_io_space[0x2200000] __attribute__((aligned(4096)));
