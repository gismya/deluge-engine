// Host replacement for src/RZA1/diskio.c: FatFS sectors come from a FAT32 disk image file.
// The firmware reads sample data with raw sector reads (disk_read_without_streaming_first + clst2sect), so the
// real ff.c has to sit on a real FAT volume; a file-level shim would not be enough.
#include "fatfs/diskio.h"
#include "fatfs/ff.h"
#include <stdio.h>
#include <stdlib.h>

extern void loadAnyEnqueuedClustersRoutine(void);
extern bool yieldingRoutineWithTimeoutForSD(bool (*until)(void), double timeoutSeconds);
extern uint32_t getTimerValue(int timerNo);
extern uint64_t host_virtual_ticks;
extern bool host_virtual_clock;

// Card timing (virtual clock only): each read waits out a modelled transfer the way the RZ/A1 SD driver waits for
// its DMA (sd_dev_low.c:1116, yieldingRoutineWithTimeoutForSD), so audio, buttons and the test port run meanwhile.
// 0 (the default) keeps reads instant.
uint32_t host_card_ticks_per_command = 0;
uint32_t host_card_ticks_per_sector = 0;
static uint64_t cardDoneAt;
static bool cardTransferDone(void) {
	getTimerValue(0); // a read moves the virtual clock on
	return host_virtual_ticks >= cardDoneAt;
}
extern void logAudioAction(char const* string);

uint8_t currentlyAccessingCard = 0;
static FILE* image;
static BYTE diskStatus = STA_NOINIT;

DSTATUS disk_initialize(BYTE pdrv) {
	(void)pdrv;
	if (!image) {
		const char* path = getenv("DELUGE_SD_IMAGE");
		image = path ? fopen(path, "rb") : NULL;
	}
	diskStatus = image ? STA_PROTECT : (STA_NOINIT | STA_NODISK);
	return diskStatus;
}

DSTATUS disk_status(BYTE pdrv) {
	(void)pdrv;
	return diskStatus;
}

DRESULT disk_read_without_streaming_first(BYTE pdrv, BYTE* buff, DWORD sector, UINT count) {
	(void)pdrv;
	if (!image) {
		return RES_NOTRDY;
	}
	if (fseeko(image, (off_t)sector * 512, SEEK_SET) != 0 || fread(buff, 512, count, image) != count) {
		return RES_ERROR;
	}
	if (host_virtual_clock && (host_card_ticks_per_command || host_card_ticks_per_sector)) {
		cardDoneAt = host_virtual_ticks + host_card_ticks_per_command + (uint64_t)count * host_card_ticks_per_sector;
		yieldingRoutineWithTimeoutForSD(cardTransferDone, 1.0);
	}
	return RES_OK;
}

DRESULT disk_read(BYTE pdrv, BYTE* buff, LBA_t sector, UINT count) {
	loadAnyEnqueuedClustersRoutine(); // as the firmware's diskio does: SD streaming first
	return disk_read_without_streaming_first(pdrv, buff, (DWORD)sector, count);
}

DRESULT disk_write(BYTE pdrv, const BYTE* buff, LBA_t sector, UINT count) {
	(void)pdrv;
	(void)buff;
	(void)sector;
	(void)count;
	return RES_WRPRT; // read-only for the spike
}

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void* buff) {
	(void)pdrv;
	(void)buff;
	return cmd == CTRL_SYNC ? RES_OK : RES_PARERR;
}

DWORD get_fattime(void) {
	return ((DWORD)(2026 - 1980) << 25) | (1u << 21) | (1u << 16);
}

void disk_timerproc(UINT msPassed) {
	(void)msPassed;
}
