// Host replacement for src/deluge/memory/general_memory_allocator.cpp and memory_region.cpp (spec §3.5), which the
// Engine leaves out of the build: they stay 32-bit on purpose.
//
// The firmware's allocator carves fixed SDRAM/on-chip regions (linker symbols, 0x0C000000..0x10000000) and keeps
// its free-list as 2x uint32_t multi-word keys {length, address}, so it can't hold a 64-bit address without a
// rework. On the host every allocation goes to malloc with the firmware's 4-byte header layout in front, so code
// that reads the header (getAllocatedSize, getRegion) still works.
//
// Stealable allocations (sample Clusters, WaveTableBandData, unused AudioFiles) are tracked against a configurable
// byte budget (default 1 GiB, spec §3.5). When a stealable allocation would exceed the budget, queued Stealables are
// evicted from CacheManager's queues in priority-tier and LRU order (front of each BidirectionalLinkedList).
#include "memory/general_memory_allocator.h"
#include "memory/memory_region.h"
#include "platform/host_platform.h"
#include <cstdlib>
#include <cstring>

namespace {

constexpr size_t kPrefix = 16; // keeps 16-byte alignment for the caller; header word sits in the last 4 bytes

size_t gStealableBudgetBytes = deluge::engine::platform::kDefaultStealableBudgetBytes;
size_t gStealableBytesUsed = 0;
uint64_t gStealableEvictions = 0;
bool gEvicting = false;
uint32_t gEvictionPass = 0;

uint32_t* headerOf(void* address) {
	return reinterpret_cast<uint32_t*>(static_cast<char*>(address) - 4);
}

void evictStealablesToFit(GeneralMemoryAllocator& gma, size_t neededBytes, void* thingNotToStealFrom) {
	if (gEvicting || gStealableBytesUsed + neededBytes <= gStealableBudgetBytes) {
		return;
	}
	gEvicting = true;
	const uint32_t passId = ++gEvictionPass;

	for (size_t q = 0; q < kNumStealableQueue && gStealableBytesUsed + neededBytes > gStealableBudgetBytes; q++) {
		const auto queueKind = static_cast<StealableQueue>(q);
		auto& list = gma.cacheManager.queue(queueKind);

		auto* node = static_cast<Stealable*>(list.getFirst());
		while (node != nullptr && gStealableBytesUsed + neededBytes > gStealableBudgetBytes) {
			auto* next = static_cast<Stealable*>(list.getNext(node));
			if (node->lastTraversalNo == passId) {
				node = next;
				continue;
			}
			if (!node->mayBeStolen(thingNotToStealFrom)) {
				node->lastTraversalNo = passId;
				node = next;
				continue;
			}
			// Re-file into a higher-priority queue if the stealable's priority rose since it was queued,
			// matching CacheManager::ReclaimMemory().
			if (q < kNumStealableQueue - 1) {
				const StealableQueue appropriate = node->getAppropriateQueue();
				if (appropriate > queueKind) {
					node->remove();
					gma.cacheManager.QueueForReclamation(appropriate, node);
					node = next;
					continue;
				}
			}

			// Unlink before stealing, then run steal() + virtual destructor + dealloc().
			// steal() may free sibling Stealables (e.g. WaveTableBandData::steal deletes its WaveTable and all
			// sibling bands), which could invalidate `next`, so restart this queue from its head (already-skipped
			// nodes are marked with passId).
			node->remove();
			node->steal("host");
			node->~Stealable();
			gma.dealloc(node);
			gStealableEvictions++;
			node = static_cast<Stealable*>(list.getFirst());
		}
	}

	gEvicting = false;
}

} // namespace

GeneralMemoryAllocator::GeneralMemoryAllocator() : lock(false) {
	for (auto& r : regions) {
		r.name = "host";
		r.cache_manager_ = nullptr;
	}
	regions[MEMORY_REGION_STEALABLE].cache_manager_ = &cacheManager;
}

void* GeneralMemoryAllocator::alloc(uint32_t requiredSize, bool, bool makeStealable, void* thingNotToStealFrom) {
	size_t size = (static_cast<size_t>(requiredSize) + 3u) & ~size_t{3};
	if (size == 0) {
		size = 4; // getAllocatedSize must stay non-zero (String S002 contract)
	}
	if (makeStealable) {
		evictStealablesToFit(*this, size, thingNotToStealFrom);
	}
	char* block = static_cast<char*>(std::malloc(kPrefix + size + 4));
	if (block == nullptr) {
		return nullptr;
	}
	void* address = block + kPrefix;
	*headerOf(address) = (makeStealable ? SPACE_HEADER_STEALABLE : SPACE_HEADER_ALLOCATED)
	                     | static_cast<uint32_t>(size & SPACE_SIZE_MASK);
	if (makeStealable) {
		gStealableBytesUsed += size;
	}
	return address;
}

void* GeneralMemoryAllocator::allocExternal(uint32_t requiredSize) {
	return alloc(requiredSize, false, false, nullptr);
}
void* GeneralMemoryAllocator::allocInternal(uint32_t requiredSize) {
	return alloc(requiredSize, true, false, nullptr);
}

void GeneralMemoryAllocator::dealloc(void* address) {
	if (address == nullptr) {
		return;
	}
	const uint32_t header = *headerOf(address);
	if ((header & SPACE_TYPE_MASK) == SPACE_HEADER_STEALABLE) {
		const uint32_t size = header & SPACE_SIZE_MASK;
		gStealableBytesUsed = gStealableBytesUsed >= size ? (gStealableBytesUsed - size) : 0;
	}
	std::free(static_cast<char*>(address) - kPrefix);
}
void GeneralMemoryAllocator::deallocExternal(void* address) {
	dealloc(address);
}

// Seam S4 (F3): String::set asks this before its S001 freeze. Every block this allocator hands out counts, so string
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
	const uint32_t oldSize = *h & SPACE_SIZE_MASK;
	const uint32_t clampedNew = newSize & SPACE_SIZE_MASK;
	if ((*h & SPACE_TYPE_MASK) == SPACE_HEADER_STEALABLE && clampedNew < oldSize) {
		const uint32_t diff = oldSize - clampedNew;
		gStealableBytesUsed = gStealableBytesUsed >= diff ? (gStealableBytesUsed - diff) : 0;
	}
	*h = (*h & SPACE_TYPE_MASK) | clampedNew;
	return clampedNew;
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

void GeneralMemoryAllocator::putStealableInQueue(Stealable* stealable, StealableQueue q) {
	if (stealable == nullptr) {
		return;
	}
	stealable->remove(); // safe if not queued; prevents list corruption on re-queue
	cacheManager.QueueForReclamation(q, stealable);
}
void GeneralMemoryAllocator::putStealableInAppropriateQueue(Stealable* stealable) {
	if (stealable == nullptr) {
		return;
	}
	putStealableInQueue(stealable, stealable->getAppropriateQueue());
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

namespace deluge::engine::platform {

void setStealableBudget(size_t bytes) {
	gStealableBudgetBytes = bytes;
}

size_t stealableBudget() {
	return gStealableBudgetBytes;
}

size_t stealableBytesUsed() {
	return gStealableBytesUsed;
}

uint64_t stealableEvictions() {
	return gStealableEvictions;
}

} // namespace deluge::engine::platform
