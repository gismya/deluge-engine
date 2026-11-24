// Host stand-ins for the RZ/A1 drivers the firmware links against (src/deluge/drivers, src/RZA1, OSLikeStuff timers).
// Most are no-ops. The ones with behaviour: the SSI audio ring (host_audio_* below), the OS timers, and the
// SPI-flash settings store (reads 0xFF like an erased chip, so FlashStorage falls back to defaults).
#include "RZA1/system/r_typedefs.h"
#include "definitions.h"
#include "fatfs/diskio.h"
#include "fatfs/ff.h"
#include <cstdio>
#include <cstring>
#include <mach/mach_time.h>

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
void* getTxBufferCurrentPlace() {
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
uint32_t getTimerValue(int timerNo) {
	return (uint32_t)(hostTicks33MHz() - timerBase[timerNo & 7]);
}
void setTimerValue(int, uint32_t) {
}
void enableTimer(int timerNo) {
	timerBase[timerNo & 7] = hostTicks33MHz();
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

// ---- UART (PIC and DIN MIDI): nothing ever arrives.
struct UartItem uartItems[NUM_UART_ITEMS];
uint8_t picTxBuffer[PIC_TX_BUFFER_SIZE];
char midiTxBuffer[MIDI_TX_BUFFER_SIZE];
uint8_t uartGetChar(int32_t, char*) {
	return 0;
}
uint32_t* uartGetCharWithTiming(int32_t, char*) {
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
