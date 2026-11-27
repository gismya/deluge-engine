// Host platform layer API (spec §3.4, §3.5): virtual clock, simulated SSI DMA, allocator budget/eviction,
// freeze handling, and headless firmware scheduler startup.
#pragma once

#include <cstddef>
#include <cstdint>

namespace deluge::hid {
class Display;
}

namespace deluge::engine::platform {

// ---- Virtual clock (spec §3.5)
// getTimerValue() advances the virtual clock by ticksPerRead (default 33 = ~1 us at 33.33 MHz) per read.
// Never change the default 33 without rerendering the goldens.
constexpr uint32_t kDefaultTicksPerRead = 33;

void resetClock();
void setTicksPerRead(uint32_t ticks);
uint32_t ticksPerRead();
uint64_t virtualTicks();
double virtualSeconds();

// Pacing (--pace F): holds virtual time to F * wall time; 0 (default) runs free.
void setPace(double pace);
double pace();

// Testability seam for pacing: override wall clock (nanoseconds) and sleep (nanoseconds).
// Passing nullptr restores std::chrono::steady_clock / std::this_thread::sleep_for.
using WallClockNsFn = uint64_t (*)();
using SleepNsFn = void (*)(uint64_t ns);
void setPaceHooks(WallClockNsFn clockFn, SleepNsFn sleepFn);

// ---- Simulated SSI DMA following the virtual clock (44.1 kHz)
using AudioSinkFn = void (*)(const int32_t* frame);

void resetDma();
void setDmaFollowsClock(bool enable);
bool dmaFollowsClock();
void setAudioSink(AudioSinkFn sink);
uint64_t dmaFrames();
uint64_t dmaOverruns();

// ---- Allocator: stealable byte budget and LRU eviction (spec §3.5)
constexpr size_t kDefaultStealableBudgetBytes = 1024ull * 1024 * 1024; // 1 GiB

void setStealableBudget(size_t bytes);
size_t stealableBudget();
size_t stealableBytesUsed();
uint64_t stealableEvictions();

// ---- Freezes (spec §3.5)
// FREEZE_WITH_ERROR and display->freezeWithError report code, what was loaded, and a backtrace, then _Exit(70).
constexpr int kFreezeExitCode = 70;
using FreezeCallbackFn = void (*)(const char* code, const char* loaded, const char* backtrace);

void setFreezeLoadedContext(const char* loaded);
const char* freezeLoadedContext();
void setFreezeCallback(FreezeCallbackFn cb);
[[noreturn]] void handleFreeze(const char* code);
deluge::hid::Display* createHostDisplay();

// ---- Startup & engine thread setup (spec §3.3, §3.4)
// Sets FPCR.FZ (flush denormals to zero) on the calling thread.
void enableFlushToZero();

// Runs the host init list (matching deluge_main's engine half, without PIC/OLED-DMA/USB/startup song),
// installs HostDisplay, sets FPCR.FZ, and calls registerTasks().
void bootFirmware();

// Runs the firmware's task scheduler: durationSeconds == 0 runs forever (startTaskManager());
// durationSeconds > 0 runs for that much virtual time and returns.
void runScheduler(double durationSeconds = 0.0);

} // namespace deluge::engine::platform
