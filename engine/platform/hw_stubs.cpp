// Host stand-ins (spec §3.5), ported from the spike's hw_stubs.cpp (task/perform-in-engine):
// the RZ/A1 drivers the firmware links against (src/deluge/drivers, src/RZA1, OSLikeStuff timers).
// Most are no-ops. The ones with behaviour: the virtual clock with optional pacing, the SSI audio ring whose
// simulated DMA position follows the virtual clock, and the SPI-flash settings store (reads 0xFF like an erased chip,
// so FlashStorage falls back to defaults).
#include "OSLikeStuff/timers_interrupts/clock_type.h"
#include "RZA1/system/r_typedefs.h"
#include "definitions.h"
#include "definitions_cxx.hpp"
#include "fatfs/diskio.h"
#include "fatfs/ff.h"
#include "platform/host_platform.h"
#include <chrono>
#include <cstdio>
#include <cstring>
#include <thread>

extern "C" {
#include "RZA1/ostm/ostm.h"
#include "RZA1/uart/sio_char.h"
#include "drivers/uart/uart.h"
}

namespace {

using deluge::engine::platform::AudioSinkFn;
using deluge::engine::platform::SleepNsFn;
using deluge::engine::platform::WallClockNsFn;

uint64_t steadyClockNs() {
	auto now = std::chrono::steady_clock::now().time_since_epoch();
	return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(now).count());
}

void defaultSleepNs(uint64_t ns) {
	std::this_thread::sleep_for(std::chrono::nanoseconds(ns));
}

WallClockNsFn gWallClockFn = steadyClockNs;
SleepNsFn gSleepFn = defaultSleepNs;

uint64_t gTimerBase[8] = {};
uint32_t gTicksPerRead = deluge::engine::platform::kDefaultTicksPerRead;
double gPace = 0.0;
bool gPaceAnchored = false;
uint64_t gPaceWallStartNs = 0;
uint64_t gPaceVirtualStartTicks = 0;
uint32_t gPaceReads = 0;

bool gDmaFollowsClock = false;
AudioSinkFn gAudioSink = nullptr;
uint64_t gDmaBaseTicks = 0;
uint64_t gDmaFrames = 0;
uint64_t gDmaOverruns = 0;

uint64_t clockToDmaFrame(uint64_t ticks) {
	return static_cast<uint64_t>((static_cast<unsigned __int128>(ticks) * kSampleRate) / DELUGE_CLOCKS_PER);
}

void paceClock(uint64_t currentVirtualTicks) {
	const uint64_t wallNs = gWallClockFn();
	if (!gPaceAnchored) {
		gPaceAnchored = true;
		gPaceWallStartNs = wallNs;
		gPaceVirtualStartTicks = currentVirtualTicks;
		return;
	}
	const double virtualElapsedS = static_cast<double>(currentVirtualTicks - gPaceVirtualStartTicks) / DELUGE_CLOCKS_PERf;
	const double wallElapsedS = static_cast<double>(wallNs - gPaceWallStartNs) * 1e-9;
	const double targetWallS = virtualElapsedS / gPace;
	if (targetWallS > wallElapsedS + 0.001) {
		const uint64_t sleepNs = static_cast<uint64_t>((targetWallS - wallElapsedS) * 1e9);
		gSleepFn(sleepNs);
	}
}

} // namespace

// ---- Audio: SSI TX/RX rings. The firmware's AudioEngine reads the DMA position to decide how much to render.
// With dmaFollowsClock enabled, the simulated DMA read position is a pure function of the virtual clock
// (44.1 kHz of DELUGE_CLOCKS_PER ticks), and every frame it passes is handed to the audio sink as played.
int32_t ssiTxBuffer[SSI_TX_BUFFER_NUM_SAMPLES * NUM_MONO_OUTPUT_CHANNELS] __attribute__((aligned(CACHE_LINE_SIZE)));
int32_t ssiRxBuffer[SSI_RX_BUFFER_NUM_SAMPLES * NUM_MONO_INPUT_CHANNELS] __attribute__((aligned(CACHE_LINE_SIZE)));

extern "C" {
uint32_t host_audio_tx_read_frame = 0; // 0..SSI_TX_BUFFER_NUM_SAMPLES-1
uint32_t host_audio_rx_write_frame = 0;
uint64_t host_virtual_ticks = 0;

static void advanceDma() {
	const uint64_t elapsedTicks = host_virtual_ticks >= gDmaBaseTicks ? host_virtual_ticks - gDmaBaseTicks : 0;
	const uint64_t now = clockToDmaFrame(elapsedTicks);
	if (now > gDmaFrames && now - gDmaFrames > SSI_TX_BUFFER_NUM_SAMPLES) {
		gDmaOverruns++;
	}
	for (; gDmaFrames < now; gDmaFrames++) {
		if (gAudioSink != nullptr) {
			gAudioSink(&ssiTxBuffer[(gDmaFrames % SSI_TX_BUFFER_NUM_SAMPLES) * NUM_MONO_OUTPUT_CHANNELS]);
		}
	}
	host_audio_tx_read_frame = static_cast<uint32_t>(gDmaFrames % SSI_TX_BUFFER_NUM_SAMPLES);
}

void ssiInit(uint8_t, uint8_t) {
}
void* getTxBufferCurrentPlace() {
	if (gDmaFollowsClock) {
		advanceDma();
	}
	return &ssiTxBuffer[host_audio_tx_read_frame * NUM_MONO_OUTPUT_CHANNELS];
}
void* getRxBufferCurrentPlace() {
	return &ssiRxBuffer[host_audio_rx_write_frame * NUM_MONO_INPUT_CHANNELS];
}
int32_t* getTxBufferStart() {
	return &ssiTxBuffer[0];
}
int32_t* getTxBufferEnd() {
	return &ssiTxBuffer[SSI_TX_BUFFER_NUM_SAMPLES * NUM_MONO_OUTPUT_CHANNELS];
}
int32_t* getRxBufferStart() {
	return &ssiRxBuffer[0];
}
int32_t* getRxBufferEnd() {
	return &ssiRxBuffer[SSI_RX_BUFFER_NUM_SAMPLES * NUM_MONO_INPUT_CHANNELS];
}
void clearTxBuffer() {
	std::memset(ssiTxBuffer, 0, sizeof(ssiTxBuffer));
}

// ---- OS timers (RZA1/ostm): deterministic virtual clock (spec §3.5).
// Every read moves it on by gTicksPerRead (default 33 ticks = ~1 us at 33.33 MHz), so time passes only as the
// firmware polls it, identical on every run whatever the host's speed. With gPace > 0 it is held back to
// gPace virtual seconds per wall-clock second (1 = real time), for wall-clock probe scripts.
uint32_t getTimerValue(int timerNo) {
	host_virtual_ticks += gTicksPerRead;
	if (gPace > 0.0 && (++gPaceReads & 255u) == 0u) {
		paceClock(host_virtual_ticks);
	}
	return static_cast<uint32_t>(host_virtual_ticks - gTimerBase[timerNo & 7]);
}
void setTimerValue(int timerNo, uint32_t value) {
	gTimerBase[timerNo & 7] = host_virtual_ticks - value;
}
void enableTimer(int timerNo) {
	gTimerBase[timerNo & 7] = host_virtual_ticks;
}
void disableTimer(int) {
}
void setOperatingMode(int, enum OSTimerOperatingMode, bool) {
}

// ---- Interrupts. The host engine is single-threaded on the engine thread.
volatile uint32_t intc_func_active = 0;
void ENTER_CRITICAL_SECTION() {
}
void EXIT_CRITICAL_SECTION() {
}
void clearIRQInterrupt(int) {
}
void setIRQInterruptBothEdges(int) {
}
void setupAndEnableInterrupt(void (*)(uint32_t), uint16_t, uint8_t) {
}
int32_t R_INTC_Enable(uint16_t) {
	return 0;
}

// ---- GPIO
void setPinMux(uint8_t, uint8_t, uint8_t) {
}
void setPinAsInput(uint8_t, uint8_t) {
}
void setPinAsOutput(uint8_t, uint8_t) {
}
void setOutputState(uint8_t, uint8_t, uint16_t) {
}
uint16_t readInput(uint8_t, uint8_t) {
	return 0;
}
void enableInputBuffer(uint8_t, uint8_t) {
}

// ---- UART (PIC and DIN MIDI): DIN MIDI bytes injected by the host are consumed by MidiEngine::checkIncomingSerialMidi
// through uartGetCharWithTiming(TIMING_CAPTURE_ITEM_MIDI, ...).
constexpr size_t kDinMidiRingSize = 65536; // power of two
uint8_t gDinMidiRing[kDinMidiRingSize];
size_t gDinMidiHead = 0;
size_t gDinMidiTail = 0;
uint32_t gDinMidiRxTime = 0;

struct UartItem uartItems[NUM_UART_ITEMS];
uint8_t picTxBuffer[PIC_TX_BUFFER_SIZE];
char midiTxBuffer[MIDI_TX_BUFFER_SIZE];
uint8_t uartGetChar(int32_t, char*) {
	return 0;
}
uint32_t* uartGetCharWithTiming(int32_t item, char* out) {
	if (item == TIMING_CAPTURE_ITEM_MIDI && gDinMidiHead != gDinMidiTail) {
		*out = static_cast<char>(gDinMidiRing[gDinMidiHead & (kDinMidiRingSize - 1)]);
		++gDinMidiHead;
		gDinMidiRxTime = getTimerValue(0);
		return &gDinMidiRxTime;
	}
	return nullptr;
}
void uartPutCharBack(int32_t) {
}
void uartFlushIfNotSending(int32_t item) {
	uartItems[item].txBufferReadPos = uartItems[item].txBufferWritePos;
}
int32_t uartGetTxBufferFullnessByItem(int32_t) {
	return 0;
}
int32_t uartGetTxBufferSpace(int32_t) {
	return 1024;
}
void uartSetBaudRate(uint8_t, uint32_t) {
}
void uartPrint(char const* s) {
	std::fputs(s, stderr);
}
void uartPrintln(char const* s) {
	std::fprintf(stderr, "%s\n", s);
}
void uartPrintNumber(int32_t n) {
	std::fprintf(stderr, "%d\n", n);
}
void uartPrintlnFloat(float f) {
	std::fprintf(stderr, "%f\n", f);
}
void putchar_(char c) {
	std::fputc(c, stderr);
}

// ---- Trigger clock input
uint32_t triggerClockRisingEdgeTimes[TRIGGER_CLOCK_INPUT_NUM_TIMES_STORED];
uint32_t triggerClockRisingEdgesReceived = 0;
uint32_t triggerClockRisingEdgesProcessed = 0;

// ---- OLED / SPI / CV
volatile uint8_t oledFrameQueueReadPos = 0;
uint8_t oledFrameQueueWritePos = 0;
int oledWaitingForMessage = 256;
volatile bool spiBusCurrentlySending = false;
void oledAcknowledgementReceived(uint8_t) {
}
void oledDMAInit() {
}
void oledMainInit() {
}
void oledRoutine() {
}
void enqueueOLEDFrame(const uint8_t*) {
}
void setupSPIInterrupts() {
}
void R_RSPI_Create(uint8_t, uint32_t, uint8_t, uint8_t) {
}
void R_RSPI_Start(uint8_t) {
}
void R_RSPI_SendBasic32(uint8_t, uint32_t) {
}
void enqueueCVMessage(int, uint32_t) {
}

// ---- Serial flash (settings): an erased chip, so FlashStorage falls back to defaults.
int32_t R_SFLASH_ByteRead(uint32_t, uint8_t* buf, int32_t size, uint32_t, uint32_t, uint8_t, uint8_t) {
	std::memset(buf, 0xFF, size);
	return 0;
}
int32_t R_SFLASH_ByteProgram(uint32_t, uint8_t*, int32_t, uint32_t, uint32_t, uint8_t, uint8_t) {
	return 0;
}
int32_t R_SFLASH_EraseSector(uint32_t, uint32_t, uint32_t, uint8_t, uint8_t) {
	return 0;
}
void initSPIBSC() {
}

// ---- Caches
void invalidate_range_all_caches(uintptr_t, uintptr_t) {
}
void L2CacheUnlockData(void) {
}
} // extern "C"

namespace deluge::engine::platform {

void resetClock() {
	host_virtual_ticks = 0;
	std::memset(gTimerBase, 0, sizeof(gTimerBase));
	gPaceAnchored = false;
	gPaceWallStartNs = 0;
	gPaceVirtualStartTicks = 0;
	gPaceReads = 0;
	gDmaBaseTicks = 0;
}

void setTicksPerRead(uint32_t ticks) {
	gTicksPerRead = ticks > 0 ? ticks : 1;
}

uint32_t ticksPerRead() {
	return gTicksPerRead;
}

uint64_t virtualTicks() {
	return host_virtual_ticks;
}

double virtualSeconds() {
	return static_cast<double>(host_virtual_ticks) / DELUGE_CLOCKS_PERf;
}

void setPace(double p) {
	gPace = p > 0.0 ? p : 0.0;
	gPaceAnchored = false;
	gPaceWallStartNs = 0;
	gPaceVirtualStartTicks = host_virtual_ticks;
	gPaceReads = 0;
}

double pace() {
	return gPace;
}

void setPaceHooks(WallClockNsFn clockFn, SleepNsFn sleepFn) {
	gWallClockFn = clockFn != nullptr ? clockFn : steadyClockNs;
	gSleepFn = sleepFn != nullptr ? sleepFn : defaultSleepNs;
	gPaceAnchored = false;
	gPaceWallStartNs = 0;
	gPaceVirtualStartTicks = host_virtual_ticks;
	gPaceReads = 0;
}

void resetDma() {
	gDmaBaseTicks = host_virtual_ticks;
	gDmaFrames = 0;
	gDmaOverruns = 0;
	host_audio_tx_read_frame = 0;
}

void setDmaFollowsClock(bool enable) {
	gDmaFollowsClock = enable;
}

bool dmaFollowsClock() {
	return gDmaFollowsClock;
}

void setAudioSink(AudioSinkFn sink) {
	gAudioSink = sink;
}

uint64_t dmaFrames() {
	return gDmaFrames;
}

uint64_t dmaOverruns() {
	return gDmaOverruns;
}

bool injectDinMidi(const uint8_t* bytes, size_t len) {
	if (len == 0) {
		return true;
	}
	if (bytes == nullptr) {
		return false;
	}
	const size_t used = gDinMidiTail - gDinMidiHead;
	if (len > kDinMidiRingSize - used) {
		return false;
	}
	for (size_t i = 0; i < len; ++i) {
		gDinMidiRing[gDinMidiTail & (kDinMidiRingSize - 1)] = bytes[i];
		++gDinMidiTail;
	}
	return true;
}

size_t pendingDinMidiBytes() {
	return gDinMidiTail - gDinMidiHead;
}

void clearDinMidi() {
	gDinMidiHead = 0;
	gDinMidiTail = 0;
}

} // namespace deluge::engine::platform
