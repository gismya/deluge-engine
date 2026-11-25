// Host replacement for src/RZA1/diskio.c: FatFS sectors come from a FAT32 card image file, read-only, named by the
// DELUGE_SD_IMAGE environment variable. Ported from the spike. E3 replaces it: the card image builder, the read-time
// model and the write overlay (spec §3.6).
// The firmware reads sample data with raw sector reads (disk_read_without_streaming_first + clst2sect), so the
// real ff.c has to sit on a real FAT volume; a file-level shim would not be enough.
#include "fatfs/diskio.h"
#include "fatfs/ff.h"
#include <stdio.h>
#include <stdlib.h>

extern void loadAnyEnqueuedClustersRoutine(void);
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
	return RES_WRPRT; // read-only until E3 adds the write overlay
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
