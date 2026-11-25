// Host replacement for src/deluge/memory/general_memory_allocator.cpp and memory_region.cpp (spec §3.5), which the
// Engine leaves out of the build: they stay 32-bit on purpose. Ported from the spike's host_gma.cpp. E2 adds the
// byte budget with LRU eviction for sample clusters.
//
// The firmware's allocator carves fixed SDRAM/on-chip regions (linker symbols, 0x0C000000..0x10000000) and keeps
// its free-list as 2x uint32_t multi-word keys {length, address}, so it can't hold a 64-bit address without a
// rework. On the host every allocation goes to malloc with the firmware's 4-byte header layout in front, so code
// that reads the header (getAllocatedSize) still works. Nothing is ever stolen: stealables (sample Clusters) stay
// cached until their owner frees them.
#include "memory/general_memory_allocator.h"
#include "memory/memory_region.h"
#include <cstdlib>
#include <cstring>

namespace {
constexpr size_t kPrefix = 16; // keeps 16-byte alignment for the caller; header word sits in the last 4 bytes

uint32_t* headerOf(void* address) {
	return reinterpret_cast<uint32_t*>(static_cast<char*>(address) - 4);
}
} // namespace

GeneralMemoryAllocator::GeneralMemoryAllocator() : lock(false) {
	for (auto& r : regions) {
		r.name = "host";
		r.cache_manager_ = nullptr;
	}
	regions[MEMORY_REGION_STEALABLE].cache_manager_ = &cacheManager;
}

void* GeneralMemoryAllocator::alloc(uint32_t requiredSize, bool, bool makeStealable, void*) {
	size_t size = (requiredSize + 3u) & ~3u;
	char* block = static_cast<char*>(std::malloc(kPrefix + size + 4));
	if (block == nullptr) {
		return nullptr;
	}
	void* address = block + kPrefix;
	*headerOf(address) = (makeStealable ? SPACE_HEADER_STEALABLE : SPACE_HEADER_ALLOCATED) | size;
	return address;
}

void* GeneralMemoryAllocator::allocExternal(uint32_t requiredSize) {
	return alloc(requiredSize, false, false, nullptr);
}
void* GeneralMemoryAllocator::allocInternal(uint32_t requiredSize) {
	return alloc(requiredSize, true, false, nullptr);
}

void GeneralMemoryAllocator::dealloc(void* address) {
	if (address != nullptr) {
		std::free(static_cast<char*>(address) - kPrefix);
	}
}
void GeneralMemoryAllocator::deallocExternal(void* address) {
	dealloc(address);
}

// Seam S4: String::set asks this before its S001 freeze. Every block this allocator hands out counts, so string
// copies work; the S002 check right after it needs getAllocatedSize() to be non-zero, which the header gives.
bool GeneralMemoryAllocator::isNonAudioExternal(void const* address) {
	return address != nullptr;
}

uint32_t GeneralMemoryAllocator::getAllocatedSize(void* address) {
	return *headerOf(address) & SPACE_SIZE_MASK;
}

// The allocation keeps its full malloc size; only the recorded size changes. Returns the new size.
uint32_t GeneralMemoryAllocator::shortenRight(void* address, uint32_t newSize) {
	uint32_t* h = headerOf(address);
	*h = (*h & SPACE_TYPE_MASK) | newSize;
	return newSize;
}

// Returns how much it was shortened by: never, on the host.
uint32_t GeneralMemoryAllocator::shortenLeft(void*, uint32_t, uint32_t) {
	return 0;
}

void GeneralMemoryAllocator::extend(void*, uint32_t, uint32_t, uint32_t* left, uint32_t* right, void*) {
	*left = 0;
	*right = 0;
}

uint32_t GeneralMemoryAllocator::extendRightAsMuchAsEasilyPossible(void* address) {
	return getAllocatedSize(address);
}

void GeneralMemoryAllocator::checkStack(char const*) {
}

// Firmware code checks that a Cluster lives in the stealable region; the header type says where it "would" be.
int32_t GeneralMemoryAllocator::getRegion(void* address) {
	return (*headerOf(address) & SPACE_TYPE_MASK) == SPACE_HEADER_STEALABLE ? MEMORY_REGION_STEALABLE
	                                                                         : MEMORY_REGION_EXTERNAL;
}

void GeneralMemoryAllocator::putStealableInQueue(Stealable*, StealableQueue) {
}
void GeneralMemoryAllocator::putStealableInAppropriateQueue(Stealable*) {
}

MemoryRegion::MemoryRegion() : emptySpaces(sizeof(EmptySpaceRecord)) {
}

NeighbouringMemoryGrabAttemptResult MemoryRegion::attemptToGrabNeighbouringMemory(void*, int32_t, int32_t, int32_t,
                                                                                   void*, uint32_t, bool) {
	return {};
}

extern "C" void* delugeAlloc(unsigned int requiredSize, bool mayUseOnChipRam) {
	return GeneralMemoryAllocator::get().alloc(requiredSize, mayUseOnChipRam, false, nullptr);
}
extern "C" void delugeDealloc(void* address) {
	GeneralMemoryAllocator::get().dealloc(address);
}
