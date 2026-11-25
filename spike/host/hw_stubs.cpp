// Host stand-ins for the RZ/A1 drivers the firmware links against (src/deluge/drivers, src/RZA1, OSLikeStuff timers).
// Most are no-ops. The ones with behaviour: the SSI audio ring (host_audio_* below), the OS timers, and the
// SPI-flash settings store (reads 0xFF like an erased chip, so FlashStorage falls back to defaults).
#include "RZA1/system/r_typedefs.h"
#include "definitions.h"
#include "OSLikeStuff/timers_interrupts/clock_type.h"
#include "fatfs/diskio.h"
#include "fatfs/ff.h"
#include <arpa/inet.h>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <mach/mach_time.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

extern "C" {
#include "RZA1/ostm/ostm.h"
#include "RZA1/uart/sio_char.h"
#include "drivers/uart/uart.h"
}

// ---- Audio: SSI TX/RX rings. The firmware's AudioEngine reads the DMA position to decide how much to render;
// the host advances host_audio_tx_read_frame as it consumes frames.
int32_t ssiTxBuffer[SSI_TX_BUFFER_NUM_SAMPLES * NUM_MONO_OUTPUT_CHANNELS] __attribute__((aligned(CACHE_LINE_SIZE)));
int32_t ssiRxBuffer[SSI_RX_BUFFER_NUM_SAMPLES * NUM_MONO_INPUT_CHANNELS] __attribute__((aligned(CACHE_LINE_SIZE)));
extern "C" {
uint32_t host_audio_tx_read_frame = 0; // 0..SSI_TX_BUFFER_NUM_SAMPLES-1
uint32_t host_audio_rx_write_frame = 0;

void ssiInit(uint8_t, uint8_t) {
}
// With host_dma_follows_clock, the "DMA" read position is a pure function of the virtual clock (44.1 kHz of
// DELUGE_CLOCKS_PER ticks), and every frame it passes is handed to host_audio_sink as played. Otherwise the driver
// moves host_audio_tx_read_frame itself (render_preset).
bool host_dma_follows_clock = false;
void (*host_audio_sink)(const int32_t* frame) = nullptr;
uint64_t host_dma_frames = 0;   // frames the DMA has read since boot
uint64_t host_dma_overruns = 0; // times the DMA lapped the ring between two reads of its position (lost audio)
extern uint64_t host_virtual_ticks;
static void advanceDma() {
	const uint64_t now = host_virtual_ticks * 44100 / DELUGE_CLOCKS_PER;
	if (now - host_dma_frames > SSI_TX_BUFFER_NUM_SAMPLES) {
		host_dma_overruns++;
	}
	for (; host_dma_frames < now; host_dma_frames++) {
		if (host_audio_sink) {
			host_audio_sink(&ssiTxBuffer[(host_dma_frames % SSI_TX_BUFFER_NUM_SAMPLES) * NUM_MONO_OUTPUT_CHANNELS]);
		}
	}
	host_audio_tx_read_frame = host_dma_frames % SSI_TX_BUFFER_NUM_SAMPLES;
}
void* getTxBufferCurrentPlace() {
	if (host_dma_follows_clock) {
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
}

extern "C" {

// ---- OS timers (RZA1/ostm): free-running 33.33 MHz up-counters, from mach_absolute_time.
static uint64_t timerBase[8];
static uint64_t hostTicks33MHz() {
	static mach_timebase_info_data_t tb;
	if (tb.denom == 0) {
		mach_timebase_info(&tb);
	}
	uint64_t ns = mach_absolute_time() * tb.numer / tb.denom;
	return ns * 3333 / 100000; // 33.33 ticks per microsecond
}
// Virtual clock (host_virtual_clock): every read moves it on by host_ticks_per_read, so time passes only as the
// firmware polls it, the same way on every run whatever the host's speed. With host_pace > 0 it is held back to
// host_pace virtual seconds per wall-clock second (1 = real time), for a client that times itself by the wall clock.
bool host_virtual_clock = false;
uint32_t host_ticks_per_read = 33; // about 1 us of virtual time per read
double host_pace = 0;
uint64_t host_virtual_ticks = 0;
static uint64_t paceWallStart = 0;
static void pace() {
	static mach_timebase_info_data_t tb;
	if (tb.denom == 0) {
		mach_timebase_info(&tb);
	}
	uint64_t wallNs = mach_absolute_time() * tb.numer / tb.denom;
	if (paceWallStart == 0) {
		paceWallStart = wallNs - (uint64_t)(host_virtual_ticks / (DELUGE_CLOCKS_PERf * host_pace) * 1e9);
	}
	double virtualS = host_virtual_ticks / DELUGE_CLOCKS_PERf;
	double wallS = (wallNs - paceWallStart) * 1e-9 * host_pace;
	if (virtualS > wallS + 0.001) {
		usleep((useconds_t)((virtualS - wallS) / host_pace * 1e6));
	}
}
static uint64_t hostTicks() {
	if (!host_virtual_clock) {
		return hostTicks33MHz();
	}
	host_virtual_ticks += host_ticks_per_read;
	static uint32_t reads = 0;
	if (host_pace > 0 && (++reads & 255) == 0) {
		pace();
	}
	return host_virtual_ticks;
}
uint32_t getTimerValue(int timerNo) {
	return (uint32_t)(hostTicks() - timerBase[timerNo & 7]);
}
void setTimerValue(int, uint32_t) {
}
void enableTimer(int timerNo) {
	timerBase[timerNo & 7] = host_virtual_clock ? host_virtual_ticks : hostTicks33MHz();
}
void disableTimer(int) {
}
void setOperatingMode(int, enum OSTimerOperatingMode, bool) {
}

// ---- Interrupts. The host engine is single-threaded for now.
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

// ---- UART. PIC: nothing arrives. DIN MIDI: with host_midi_udp_open(), raw MIDI bytes in UDP datagrams both ways,
// as delugemu's MIDI bridge carries them, so deluge_probe.py --udp LISTEN:SEND talks to the Engine unchanged.
struct UartItem uartItems[NUM_UART_ITEMS];
uint8_t picTxBuffer[PIC_TX_BUFFER_SIZE];
char midiTxBuffer[MIDI_TX_BUFFER_SIZE];
static int midiSock = -1;
static sockaddr_in midiPeer;
static uint8_t midiRx[65536];
static uint32_t midiRxHead = 0, midiRxTail = 0;
static uint32_t midiRxTime;
uint64_t host_midi_bytes_in = 0, host_midi_bytes_out = 0;
bool host_midi_print_events = false; // with no UDP link: print test-port event lines to stderr

// The probe's spec: it binds LISTEN and sends to SEND, so the Engine binds SEND and sends to LISTEN.
bool host_midi_udp_open(int probeListen, int probeSend) {
	midiSock = socket(AF_INET, SOCK_DGRAM, 0);
	sockaddr_in me{};
	me.sin_family = AF_INET;
	me.sin_port = htons(probeSend);
	me.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	if (midiSock < 0 || bind(midiSock, (sockaddr*)&me, sizeof(me)) != 0) {
		std::perror("host_midi_udp_open");
		return false;
	}
	fcntl(midiSock, F_SETFL, O_NONBLOCK);
	midiPeer = me;
	midiPeer.sin_port = htons(probeListen);
	return true;
}

uint8_t uartGetChar(int32_t, char*) {
	return 0;
}
// host_midi_inject(): MIDI bytes from the host itself (no UDP link), read by the firmware's DIN parser as if they came
// in on the DIN port. A driver calls it from a firmware task (one thread).
static uint8_t midiInject[4096];
static uint32_t midiInjectHead = 0, midiInjectTail = 0;
extern "C" bool host_midi_inject(const uint8_t* bytes, uint32_t n) {
	if (midiInjectTail + n > sizeof(midiInject)) {
		if (midiInjectHead != midiInjectTail) {
			return false;
		}
		midiInjectHead = midiInjectTail = 0;
	}
	std::memcpy(midiInject + midiInjectTail, bytes, n);
	midiInjectTail += n;
	host_midi_bytes_in += n;
	return true;
}
uint32_t* uartGetCharWithTiming(int32_t item, char* out) {
	if (item == TIMING_CAPTURE_ITEM_MIDI && midiInjectHead != midiInjectTail) {
		*out = (char)midiInject[midiInjectHead++];
		if (midiInjectHead == midiInjectTail) {
			midiInjectHead = midiInjectTail = 0;
		}
		midiRxTime = getTimerValue(0);
		return &midiRxTime;
	}
	if (item != TIMING_CAPTURE_ITEM_MIDI || midiSock < 0) {
		return nullptr;
	}
	if (midiRxHead == midiRxTail) {
		ssize_t n = recv(midiSock, midiRx, sizeof(midiRx), 0);
		if (n <= 0) {
			return nullptr;
		}
		midiRxHead = 0;
		midiRxTail = (uint32_t)n;
		host_midi_bytes_in += n;
	}
	*out = (char)midiRx[midiRxHead++];
	midiRxTime = getTimerValue(0);
	return &midiRxTime;
}
void uartPutCharBack(int32_t) {
}
// bufferMIDIUart() wraps the write position with PIC_TX_BUFFER_SIZE (sio_char.h), so the stand-in does too.
static uint32_t txFullness(int32_t item) {
	return (uint32_t)(uartItems[item].txBufferWritePos - uartItems[item].txBufferReadPos) & (PIC_TX_BUFFER_SIZE - 1);
}
void uartFlushIfNotSending(int32_t item) {
	if (item == UART_ITEM_MIDI && midiSock < 0 && host_midi_print_events) {
		// No link: print the test port's event frames (F0 00 21 7B 01 03 40 01 <ascii> F7) to stderr.
		static uint8_t frame[512];
		static uint32_t len = 0;
		uint32_t n = txFullness(item);
		for (uint32_t i = 0; i < n; i++) {
			uint8_t b = (uint8_t)midiTxBuffer[(uartItems[item].txBufferReadPos + i) & (PIC_TX_BUFFER_SIZE - 1)];
			if (b == 0xF0) {
				len = 0;
			}
			if (len < sizeof(frame)) {
				frame[len++] = b;
			}
			if (b == 0xF7 && len > 9 && frame[5] == 0x03 && frame[6] == 0x40) {
				std::fprintf(stderr, "event %.*s\n", (int)(len - 9), (const char*)frame + 8);
			}
		}
	}
	if (item == UART_ITEM_MIDI && midiSock >= 0) {
		uint8_t out[PIC_TX_BUFFER_SIZE];
		uint32_t n = txFullness(item);
		for (uint32_t i = 0; i < n; i++) {
			out[i] = (uint8_t)midiTxBuffer[(uartItems[item].txBufferReadPos + i) & (PIC_TX_BUFFER_SIZE - 1)];
		}
		if (n > 0) {
			sendto(midiSock, out, n, 0, (sockaddr*)&midiPeer, sizeof(midiPeer));
			host_midi_bytes_out += n;
		}
	}
	uartItems[item].txBufferReadPos = uartItems[item].txBufferWritePos;
}
int32_t uartGetTxBufferFullnessByItem(int32_t item) {
	return (int32_t)txFullness(item);
}
int32_t uartGetTxBufferSpace(int32_t item) {
	return PIC_TX_BUFFER_SIZE - 1 - (int32_t)txFullness(item);
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

}


extern "C" {
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

// ---- Serial flash (settings): an erased chip.
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
}
