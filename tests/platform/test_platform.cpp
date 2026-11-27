// Unit tests for the host platform layer (E2, spec §3.4 & §3.5):
//   --unit                        in-process tests (clock, pacing, DMA, allocator/LRU/F3, FZ, flash, scheduler)
//   --pace-real                   verifies real steady_clock + sleep_for pacing
//   --freeze-macro CODE [LOADED]  triggers FREEZE_WITH_ERROR(CODE) and expects exit 70
//   --freeze-display CODE         triggers display->freezeWithError(CODE) and expects exit 70
//   --freeze-callback CODE        verifies FreezeCallbackFn runs before exit 70
//   --freeze-s002                 triggers real firmware String S002 freeze and expects exit 70
#include "OSLikeStuff/scheduler_api.h"
#include "OSLikeStuff/timers_interrupts/clock_type.h"
#include "definitions.h"
#include "definitions_cxx.hpp"
#include "hid/display/display.h"
#include "memory/general_memory_allocator.h"
#include "memory/stealable.h"
#include "model/song/song.h"
#include "platform/host_platform.h"
#include "util/d_string.h"
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>
#include <vector>

extern "C" {
#include "RZA1/ostm/ostm.h"
void* getTxBufferCurrentPlace();
extern int32_t ssiTxBuffer[];
int32_t R_SFLASH_ByteRead(uint32_t, uint8_t* buf, int32_t size, uint32_t, uint32_t, uint8_t, uint8_t);
}
extern bool sdRoutineLock;

namespace plat = deluge::engine::platform;

namespace {

int gFailures = 0;

void checkImpl(bool cond, const char* expr, int line) {
	if (!cond) {
		std::fprintf(stderr, "FAIL line %d: %s\n", line, expr);
		gFailures++;
	}
}
#define CHECK(expr) checkImpl((expr), #expr, __LINE__)

// ---- Fake wall clock for deterministic pacing tests
uint64_t gFakeWallNs = 1'000'000'000ull; // non-zero start
uint64_t gTotalSleptNs = 0;
uint32_t gSleepCalls = 0;

uint64_t fakeClockNs() {
	return gFakeWallNs;
}
void fakeSleepNs(uint64_t ns) {
	gTotalSleptNs += ns;
	gSleepCalls++;
	gFakeWallNs += ns;
}

// ---- Test 1: Virtual clock & pacing
void testVirtualClock() {
	plat::setPaceHooks(nullptr, nullptr);
	plat::resetClock();
	CHECK(plat::ticksPerRead() == 33);
	CHECK(plat::virtualTicks() == 0);
	CHECK(plat::pace() == 0.0);

	// Each read advances by 33 ticks.
	CHECK(getTimerValue(0) == 33);
	CHECK(getTimerValue(0) == 66);
	CHECK(getTimerValue(0) == 99);
	CHECK(plat::virtualTicks() == 99);

	// enableTimer resets only that timer's base.
	enableTimer(1);
	CHECK(getTimerValue(1) == 33);
	CHECK(getTimerValue(0) == 165); // 99 + 33 + 33

	enableTimer(0);
	CHECK(getTimerValue(0) == 33);

	// Custom ticks-per-read.
	plat::setTicksPerRead(100);
	CHECK(plat::ticksPerRead() == 100);
	uint64_t before = plat::virtualTicks();
	uint32_t v0 = getTimerValue(0);
	CHECK(plat::virtualTicks() == before + 100);
	CHECK(v0 == 133);

	// Restore default 33.
	plat::setTicksPerRead(plat::kDefaultTicksPerRead);
	plat::resetClock();
}

void testClockPacing() {
	plat::resetClock();
	plat::setPaceHooks(fakeClockNs, fakeSleepNs);

	// Unpaced (pace == 0): 10000 reads (~10 ms virtual) never sleep.
	gFakeWallNs = 1'000'000'000ull;
	gTotalSleptNs = 0;
	gSleepCalls = 0;
	plat::setPace(0.0);
	for (int i = 0; i < 10000; i++) {
		getTimerValue(0);
	}
	CHECK(gSleepCalls == 0);
	CHECK(gTotalSleptNs == 0);

	// Pace = 1.0: 10000 reads * 33 ticks = 330,000 ticks = 9.901 ms virtual -> ~9.9 ms sleep.
	plat::resetClock();
	gFakeWallNs = 2'000'000'000ull;
	gTotalSleptNs = 0;
	gSleepCalls = 0;
	plat::setPace(1.0);
	for (int i = 0; i < 10000; i++) {
		getTimerValue(0);
	}
	double expectedNs1 = (10000.0 * 33.0 / DELUGE_CLOCKS_PERf) * 1e9;
	CHECK(gSleepCalls > 0);
	CHECK(std::fabs((double)gTotalSleptNs - expectedNs1) < 2'000'000.0); // within 2 ms

	// Pace = 2.0 (2x real time): half the wall sleep for the same virtual time.
	plat::resetClock();
	gFakeWallNs = 3'000'000'000ull;
	gTotalSleptNs = 0;
	gSleepCalls = 0;
	plat::setPace(2.0);
	for (int i = 0; i < 10000; i++) {
		getTimerValue(0);
	}
	CHECK(gSleepCalls > 0);
	CHECK(std::fabs((double)gTotalSleptNs - expectedNs1 / 2.0) < 2'000'000.0);

	// Pace = 0.5 (half real time): double the wall sleep.
	plat::resetClock();
	gFakeWallNs = 4'000'000'000ull;
	gTotalSleptNs = 0;
	gSleepCalls = 0;
	plat::setPace(0.5);
	for (int i = 0; i < 10000; i++) {
		getTimerValue(0);
	}
	CHECK(gSleepCalls > 0);
	CHECK(std::fabs((double)gTotalSleptNs - expectedNs1 * 2.0) < 2'000'000.0);

	plat::setPace(0.0);
	plat::setPaceHooks(nullptr, nullptr);
	plat::resetClock();
}

// ---- Test 2: DMA position following the virtual clock
std::vector<int32_t> gCapturedFrames;
void captureSink(const int32_t* frame) {
	gCapturedFrames.push_back(frame[0]);
	gCapturedFrames.push_back(frame[1]);
}

void testDmaFollowsClock() {
	plat::resetClock();
	plat::setPace(0.0);
	plat::resetDma();
	gCapturedFrames.clear();

	// Fill ssiTxBuffer with recognizable per-slot patterns.
	for (uint32_t i = 0; i < SSI_TX_BUFFER_NUM_SAMPLES; i++) {
		ssiTxBuffer[i * 2] = static_cast<int32_t>(1000 + i);
		ssiTxBuffer[i * 2 + 1] = static_cast<int32_t>(2000 + i);
	}

	plat::setAudioSink(captureSink);
	plat::setDmaFollowsClock(true);
	CHECK(plat::dmaFollowsClock());
	CHECK(plat::dmaFrames() == 0);
	CHECK(plat::dmaOverruns() == 0);

	// Advance clock in small chunks (each < 128 frames = ~96731 ticks) across a full ring wrap (> 128 frames).
	// 1000 reads * 33 = 33,000 ticks -> ~43 frames per step. 5 steps = 218 frames.
	for (int step = 0; step < 5; step++) {
		for (int i = 0; i < 1000; i++) {
			getTimerValue(0);
		}
		void* place = getTxBufferCurrentPlace();
		uint64_t expectedFrame = (plat::virtualTicks() * kSampleRate) / DELUGE_CLOCKS_PER;
		CHECK(plat::dmaFrames() == expectedFrame);
		CHECK(place == &ssiTxBuffer[(expectedFrame % SSI_TX_BUFFER_NUM_SAMPLES) * NUM_MONO_OUTPUT_CHANNELS]);
	}
	CHECK(plat::dmaOverruns() == 0);
	CHECK(gCapturedFrames.size() == plat::dmaFrames() * 2);
	CHECK(plat::dmaFrames() > SSI_TX_BUFFER_NUM_SAMPLES);

	// Verify ring-order samples delivered to sink.
	for (uint64_t f = 0; f < plat::dmaFrames(); f++) {
		uint32_t slot = static_cast<uint32_t>(f % SSI_TX_BUFFER_NUM_SAMPLES);
		CHECK(gCapturedFrames[f * 2] == static_cast<int32_t>(1000 + slot));
		CHECK(gCapturedFrames[f * 2 + 1] == static_cast<int32_t>(2000 + slot));
	}

	// Now advance > 128 frames in one jump (e.g. 5000 reads * 33 = 165,000 ticks = 218 frames) -> 1 overrun.
	for (int i = 0; i < 5000; i++) {
		getTimerValue(0);
	}
	(void)getTxBufferCurrentPlace();
	CHECK(plat::dmaOverruns() == 1);

	plat::setAudioSink(nullptr);
	plat::setDmaFollowsClock(false);
	plat::resetDma();
	plat::resetClock();
}

// ---- Test 3: Allocator (F3 contract + byte budget + LRU eviction)
struct FakeStealable final : public Stealable {
	int id = 0;
	StealableQueue targetQueue = StealableQueue::CURRENT_SONG_SAMPLE_DATA;
	void* protectedOwner = nullptr;
	bool allowSteal = true;
	FakeStealable* siblingToFreeOnSteal = nullptr;
	std::vector<int>* stolenLog = nullptr;
	std::vector<int>* destroyedLog = nullptr;

	bool mayBeStolen(void* thingNotToStealFrom) override {
		if (!allowSteal) {
			return false;
		}
		if (protectedOwner != nullptr && thingNotToStealFrom == protectedOwner) {
			return false;
		}
		return true;
	}
	void steal(char const*) override {
		if (stolenLog != nullptr) {
			stolenLog->push_back(id);
		}
		if (siblingToFreeOnSteal != nullptr) {
			FakeStealable* sib = siblingToFreeOnSteal;
			siblingToFreeOnSteal = nullptr;
			sib->~FakeStealable();
			GeneralMemoryAllocator::get().dealloc(sib);
		}
	}
	StealableQueue getAppropriateQueue() override { return targetQueue; }
	~FakeStealable() override {
		if (destroyedLog != nullptr) {
			destroyedLog->push_back(id);
		}
	}
};

FakeStealable* makeStealable(uint32_t bytes, int id, StealableQueue q, std::vector<int>* stolenLog,
                             std::vector<int>* destroyedLog, void* dontStealFrom = nullptr) {
	void* mem = GeneralMemoryAllocator::get().allocStealable<FakeStealable>(bytes, dontStealFrom);
	if (mem == nullptr) {
		return nullptr;
	}
	auto* obj = new (mem) FakeStealable();
	obj->id = id;
	obj->targetQueue = q;
	obj->stolenLog = stolenLog;
	obj->destroyedLog = destroyedLog;
	return obj;
}

void destroyStealable(FakeStealable* obj) {
	obj->~FakeStealable();
	GeneralMemoryAllocator::get().dealloc(obj);
}

void testAllocatorF3Contract() {
	auto& gma = GeneralMemoryAllocator::get();
	CHECK(!GeneralMemoryAllocator::isNonAudioExternal(nullptr));

	void* p = gma.allocExternal(32);
	CHECK(p != nullptr);
	CHECK(GeneralMemoryAllocator::isNonAudioExternal(p));
	CHECK(gma.getAllocatedSize(p) >= 32);
	gma.deallocExternal(p);

	// Zero-size allocation still reports non-zero size (protects S002).
	void* z = gma.allocExternal(0);
	CHECK(z != nullptr);
	CHECK(gma.getAllocatedSize(z) > 0);
	gma.deallocExternal(z);

	// Real firmware String copy exercises both S001 (isNonAudioExternal) and S002 (getAllocatedSize != 0).
	String a;
	CHECK(a.set("GEN Sine Sub") == Error::NONE);
	String b;
	b.set(&a); // Would freeze S001 or S002 if F3 contract were broken!
	CHECK(std::strcmp(b.get(), "GEN Sine Sub") == 0);
	CHECK(a.getNumReasons() == 2);
	b.clear();
	CHECK(a.getNumReasons() == 1);
	a.clear();
}

void testAllocatorLruEviction() {
	auto& gma = GeneralMemoryAllocator::get();
	CHECK(plat::stealableBudget() == plat::kDefaultStealableBudgetBytes); // 1 GiB default

	const size_t savedBudget = plat::stealableBudget();
	const size_t baseUsed = plat::stealableBytesUsed();
	const uint64_t baseEvictions = plat::stealableEvictions();

	constexpr uint32_t kBlock = 4096;
	// Budget allows 2 blocks above baseUsed.
	plat::setStealableBudget(baseUsed + kBlock * 2);

	std::vector<int> stolen;
	std::vector<int> destroyed;

	// 1. LRU order within a queue: allocate A, B, queue both [A, B], touch A -> [B, A], allocate C -> B evicted.
	auto* a = makeStealable(kBlock, 1, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed);
	auto* b = makeStealable(kBlock, 2, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed);
	CHECK(a != nullptr && b != nullptr);
	CHECK(gma.getRegion(a) == MEMORY_REGION_STEALABLE);
	CHECK(plat::stealableBytesUsed() == baseUsed + kBlock * 2);

	gma.putStealableInAppropriateQueue(a);
	gma.putStealableInAppropriateQueue(b);
	// Touch A (like Cluster::addReason + removeReason): remove and re-queue -> A moves to tail (MRU).
	a->remove();
	gma.putStealableInAppropriateQueue(a);

	auto* c = makeStealable(kBlock, 3, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed);
	CHECK(c != nullptr);
	CHECK(stolen.size() == 1 && stolen[0] == 2);
	CHECK(destroyed.size() == 1 && destroyed[0] == 2);
	CHECK(plat::stealableEvictions() == baseEvictions + 1);
	CHECK(plat::stealableBytesUsed() == baseUsed + kBlock * 2);

	// 2. Queue priority: item in NO_SONG_SAMPLE_DATA (queue 0) is evicted before older item in CURRENT_SONG_SAMPLE_DATA.
	stolen.clear();
	destroyed.clear();
	c->targetQueue = StealableQueue::NO_SONG_SAMPLE_DATA;
	gma.putStealableInAppropriateQueue(c); // C is newer than A, but in lower-priority queue 0
	auto* d = makeStealable(kBlock, 4, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed);
	CHECK(d != nullptr);
	CHECK(stolen.size() == 1 && stolen[0] == 3);

	// 3. Reassessment: item queued in NO_SONG_SAMPLE_DATA whose getAppropriateQueue() is now CURRENT_SONG_SAMPLE_DATA
	// gets re-filed instead of evicted before another NO_SONG item.
	stolen.clear();
	destroyed.clear();
	plat::setStealableBudget(baseUsed + kBlock * 3);
	auto* e = makeStealable(kBlock, 5, StealableQueue::NO_SONG_SAMPLE_DATA, &stolen, &destroyed);
	CHECK(e != nullptr);
	// Queue D in NO_SONG first, then change its targetQueue to CURRENT_SONG; queue E in NO_SONG after it.
	gma.putStealableInQueue(d, StealableQueue::NO_SONG_SAMPLE_DATA);
	d->targetQueue = StealableQueue::CURRENT_SONG_SAMPLE_DATA;
	gma.putStealableInQueue(e, StealableQueue::NO_SONG_SAMPLE_DATA);
	// Now allocate F -> D should be re-filed to CURRENT_SONG, and E (still NO_SONG) should be evicted!
	auto* f = makeStealable(kBlock, 6, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed);
	CHECK(f != nullptr);
	CHECK(stolen.size() == 1 && stolen[0] == 5);

	// 4. thingNotToStealFrom respected: protect A, so D is evicted instead of A.
	stolen.clear();
	destroyed.clear();
	int ownerToken = 42;
	a->protectedOwner = &ownerToken;
	// Queue order in CURRENT_SONG: [A, D]. F is pinned (not queued).
	auto* g = makeStealable(kBlock, 7, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed, &ownerToken);
	CHECK(g != nullptr);
	CHECK(stolen.size() == 1 && stolen[0] == 4);

	// 5. Pinned items (not in queue) are never evicted, and allocation still succeeds over budget.
	stolen.clear();
	destroyed.clear();
	a->remove(); // pin A; F and G are also not queued.
	auto* h = makeStealable(kBlock, 8, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed);
	CHECK(h != nullptr);
	CHECK(stolen.empty());
	CHECK(plat::stealableBytesUsed() == baseUsed + kBlock * 4);

	// 6. Sibling destruction during steal() (like WaveTableBandData::steal) is safe (no UAF under ASan).
	stolen.clear();
	destroyed.clear();
	plat::setStealableBudget(baseUsed + kBlock * 2);
	a->protectedOwner = nullptr;
	a->siblingToFreeOnSteal = f; // stealing A also frees F (which is next in queue!)
	gma.putStealableInQueue(a, StealableQueue::NO_SONG_SAMPLE_DATA);
	gma.putStealableInQueue(f, StealableQueue::NO_SONG_SAMPLE_DATA);
	gma.putStealableInQueue(g, StealableQueue::NO_SONG_SAMPLE_DATA);
	auto* k = makeStealable(kBlock, 9, StealableQueue::CURRENT_SONG_SAMPLE_DATA, &stolen, &destroyed);
	CHECK(k != nullptr);
	// Stealing A freed both A (4K) and F (4K), then G (4K) was also needed to get 4+1->2 blocks (total <= 2*kBlock).
	CHECK(plat::stealableBytesUsed() <= baseUsed + kBlock * 2);

	// 7. shortenRight updates stealableBytesUsed.
	size_t beforeShorten = plat::stealableBytesUsed();
	gma.shortenRight(h, kBlock / 2);
	CHECK(plat::stealableBytesUsed() == beforeShorten - kBlock / 2);

	// Cleanup remaining live objects (H and K).
	destroyStealable(h);
	destroyStealable(k);
	CHECK(plat::stealableBytesUsed() == baseUsed);

	plat::setStealableBudget(savedBudget);
}

// ---- Test 4: FPCR.FZ and erased-flash defaults
void testFlushToZeroAndFlashDefaults() {
	plat::enableFlushToZero();
#if defined(__aarch64__)
	uint64_t fpcr = __builtin_arm_rsr64("fpcr");
	CHECK((fpcr & (1ull << 24)) != 0);
	volatile float subnormal = 1e-40f;
	volatile float zero = 0.0f;
	volatile float sum = subnormal + zero;
	CHECK(sum == 0.0f);
#endif

	uint8_t flashBuf[16] = {};
	CHECK(R_SFLASH_ByteRead(0, flashBuf, sizeof(flashBuf), 0, 0, 0, 0) == 0);
	for (uint8_t b : flashBuf) {
		CHECK(b == 0xFF);
	}
}

// ---- Test 5: Firmware boot and scheduler run
int gHostTaskRuns = 0;
void testHostTask() {
	gHostTaskRuns++;
}

void testBootAndScheduler() {
	plat::resetClock();
	plat::setPace(0.0);
	plat::bootFirmware();

	CHECK(display != nullptr);
	CHECK(currentSong != nullptr);
	CHECK(sdRoutineLock == false);

	plat::resetDma();
	plat::setDmaFollowsClock(true);
	gHostTaskRuns = 0;
	addRepeatingTask(testHostTask, 35, 0.002, 0.005, 0.01, "test_host", RESOURCE_NONE);

	// Run 30 ms of virtual time through the firmware's own scheduler and return.
	uint64_t startFrames = plat::dmaFrames();
	plat::runScheduler(0.03);
	uint64_t elapsedFrames = plat::dmaFrames() - startFrames;

	CHECK(gHostTaskRuns >= 2);
	CHECK(elapsedFrames >= 1000 && elapsedFrames <= 2000); // ~1323 frames at 44.1 kHz
	CHECK(plat::dmaOverruns() == 0);

	plat::setDmaFollowsClock(false);
}

void testRealWallClockPace() {
	plat::resetClock();
	plat::setPaceHooks(nullptr, nullptr);
	plat::setPace(1.0);
	auto t0 = std::chrono::steady_clock::now();
	// 50 ms virtual time = 0.05 * 33,330,000 / 33 = ~50,500 reads
	for (int i = 0; i < 50500; i++) {
		getTimerValue(0);
	}
	double elapsedMs = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
	plat::setPace(0.0);
	std::fprintf(stderr, "real pace 1.0: 50 ms virtual took %.1f ms wall\n", elapsedMs);
	CHECK(elapsedMs >= 35.0 && elapsedMs < 2000.0);
}

void onFreezeCallback(const char* code, const char* loaded, const char* bt) {
	std::fprintf(stderr, "CALLBACK code=%s loaded=%s bt_len=%zu\n", code ? code : "", loaded ? loaded : "",
	             bt ? std::strlen(bt) : 0);
	std::fflush(stderr);
}

} // namespace

int main(int argc, char** argv) {
	if (argc < 2) {
		std::fprintf(stderr, "usage: test_platform --unit | --pace-real | --freeze-macro CODE [LOADED] | "
		                     "--freeze-display CODE | --freeze-callback CODE | --freeze-s002\n");
		std::_Exit(2);
	}

	const char* mode = argv[1];
	if (std::strcmp(mode, "--unit") == 0) {
		testVirtualClock();
		testClockPacing();
		testDmaFollowsClock();
		testAllocatorF3Contract();
		testAllocatorLruEviction();
		testFlushToZeroAndFlashDefaults();
		testBootAndScheduler();
		std::fprintf(stderr, "test_platform --unit: %d failures\n", gFailures);
		std::fflush(nullptr);
		std::_Exit(gFailures == 0 ? 0 : 1);
	}
	if (std::strcmp(mode, "--pace-real") == 0) {
		testRealWallClockPace();
		std::fflush(nullptr);
		std::_Exit(gFailures == 0 ? 0 : 1);
	}
	if (std::strcmp(mode, "--freeze-macro") == 0) {
		display = plat::createHostDisplay();
		if (argc >= 4) {
			plat::setFreezeLoadedContext(argv[3]);
		}
		FREEZE_WITH_ERROR(argc >= 3 ? argv[2] : "E999");
		std::_Exit(1);
	}
	if (std::strcmp(mode, "--freeze-display") == 0) {
		display = plat::createHostDisplay();
		display->freezeWithError(argc >= 3 ? argv[2] : "B001");
		std::_Exit(1);
	}
	if (std::strcmp(mode, "--freeze-callback") == 0) {
		display = plat::createHostDisplay();
		plat::setFreezeLoadedContext("SYNTHS/CALLBACK.XML");
		plat::setFreezeCallback(onFreezeCallback);
		FREEZE_WITH_ERROR(argc >= 3 ? argv[2] : "E777");
		std::_Exit(1);
	}
	if (std::strcmp(mode, "--freeze-s002") == 0) {
		display = plat::createHostDisplay();
		plat::setFreezeLoadedContext("STRING_S002");
		// Craft a String whose refcount word (read by String::set's S002 getAllocatedSize(sm) check) is 0.
		String a;
		a.set("abc");
		*reinterpret_cast<int32_t*>(const_cast<char*>(a.get()) - 4) = 0;
		String b;
		b.set(&a); // firmware d_string.cpp:149 calls FREEZE_WITH_ERROR("S002")
		std::_Exit(1);
	}

	std::fprintf(stderr, "unknown mode: %s\n", mode);
	std::_Exit(2);
}
