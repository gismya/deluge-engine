// Host replacement for src/RZA1/diskio.c (E3, spec §3.6):
//   - Sector device over a FAT32 card image opened read-only (O_RDONLY + pread, safe for concurrent processes).
//   - In-memory write overlay: firmware writes go to a per-process map of changed 512-byte sectors dropped at exit.
//   - Modelled read time (on by default: 300 us + 40 us per sector of virtual time) waited out through the firmware's
//     own yieldingRoutineWithTimeoutForSD(), with currentlyAccessingCard held for the transfer (matching RZA1/diskio.c)
//     so audio/UI tasks run meanwhile without nested cluster loads re-entering the SD routine and causing DMA overruns.
//   - Scoped direct read/write mode for the card image builder (card_image.cpp) before the firmware boots.
#include "OSLikeStuff/timers_interrupts/clock_type.h"
#include "fatfs/diskio.h"
#include "fatfs/ff.h"
#include "platform/card_image.h"
#include "platform/host_platform.h"
#include <array>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <mutex>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <unordered_map>

extern "C" {
void loadAnyEnqueuedClustersRoutine(void);
void logAudioAction(char const* string);
bool yieldingRoutineWithTimeoutForSD(bool (*until)(void), double timeoutSeconds);
uint32_t getTimerValue(int timerNo);
extern uint64_t host_virtual_ticks;
}
extern bool sdRoutineLock;

namespace {

using SectorData = std::array<uint8_t, deluge::engine::platform::kCardSectorBytes>;

// Runtime (read-only image + in-memory write overlay + read-time model).
int gRuntimeFd = -1;
uint64_t gRuntimeSectorCount = 0;
BYTE gRuntimeStatus = STA_NOINIT | STA_NODISK;
std::string gRuntimePath;
std::unordered_map<uint64_t, SectorData> gWriteOverlay;

// Modelled SD transfer timing (spec §3.6): default 300 us + 40 us/sector.
double gReadCommandUs = deluge::engine::platform::kDefaultCardReadCommandUs;
double gReadSectorUs = deluge::engine::platform::kDefaultCardReadSectorUs;
uint64_t gReadCommandTicks =
    static_cast<uint64_t>(deluge::engine::platform::kDefaultCardReadCommandUs * DELUGE_CLOCKS_PERf / 1e6);
uint64_t gReadSectorTicks =
    static_cast<uint64_t>(deluge::engine::platform::kDefaultCardReadSectorUs * DELUGE_CLOCKS_PERf / 1e6);
uint64_t gCardDoneAtTicks = 0;

deluge::engine::platform::DiskStats gStats{};

// Direct read/write mode for the card image builder (before firmware boots).
std::mutex gBuildMutex;
bool gDirectBuildMode = false;
int gBuildFd = -1;
uint64_t gBuildSectorCount = 0;
BYTE gBuildStatus = STA_NOINIT | STA_NODISK;

bool cardTransferDone(void) {
	getTimerValue(0); // polling advances the deterministic virtual clock
	return host_virtual_ticks >= gCardDoneAtTicks;
}

bool preadAll(int fd, uint8_t* dst, size_t bytes, off_t offset) {
	size_t done = 0;
	while (done < bytes) {
		ssize_t n = ::pread(fd, dst + done, bytes - done, offset + static_cast<off_t>(done));
		if (n < 0) {
			if (errno == EINTR) {
				continue;
			}
			return false;
		}
		if (n == 0) {
			return false;
		}
		done += static_cast<size_t>(n);
	}
	return true;
}

bool pwriteAll(int fd, const uint8_t* src, size_t bytes, off_t offset) {
	size_t done = 0;
	while (done < bytes) {
		ssize_t n = ::pwrite(fd, src + done, bytes - done, offset + static_cast<off_t>(done));
		if (n < 0) {
			if (errno == EINTR) {
				continue;
			}
			return false;
		}
		if (n == 0) {
			return false;
		}
		done += static_cast<size_t>(n);
	}
	return true;
}

bool openRegularImageFd(const std::string& path, int flags, int& outFd, uint64_t& outSectors) {
	int fd = ::open(path.c_str(), flags);
	if (fd < 0) {
		return false;
	}
	struct stat st {};
	if (::fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_size < 512) {
		::close(fd);
		return false;
	}
	outFd = fd;
	outSectors = static_cast<uint64_t>(st.st_size) / deluge::engine::platform::kCardSectorBytes;
	return true;
}

void closeRuntimeLocked() {
	if (gRuntimeFd >= 0) {
		::close(gRuntimeFd);
		gRuntimeFd = -1;
	}
	gRuntimeSectorCount = 0;
	gRuntimePath.clear();
	gWriteOverlay.clear();
	gRuntimeStatus = STA_NOINIT | STA_NODISK;
}

} // namespace

extern "C" {

uint8_t currentlyAccessingCard = 0;

DSTATUS disk_initialize(BYTE pdrv) {
	(void)pdrv;
	if (gDirectBuildMode) {
		gBuildStatus = gBuildFd >= 0 ? 0 : (STA_NOINIT | STA_NODISK);
		return gBuildStatus;
	}
	if (gRuntimeFd < 0) {
		const char* envPath = std::getenv("DELUGE_SD_IMAGE");
		if (envPath != nullptr && envPath[0] != '\0') {
			int fd = -1;
			uint64_t sectors = 0;
			if (openRegularImageFd(envPath, O_RDONLY, fd, sectors)) {
				gRuntimeFd = fd;
				gRuntimeSectorCount = sectors;
				gRuntimePath = envPath;
				gWriteOverlay.clear();
			}
		}
	}
	// Ready and writable (writes go to the in-memory overlay, never to disk).
	gRuntimeStatus = gRuntimeFd >= 0 ? 0 : (STA_NOINIT | STA_NODISK);
	return gRuntimeStatus;
}

DSTATUS disk_status(BYTE pdrv) {
	(void)pdrv;
	return gDirectBuildMode ? gBuildStatus : gRuntimeStatus;
}

DRESULT disk_read_without_streaming_first(BYTE pdrv, BYTE* buff, DWORD sector, UINT count) {
	(void)pdrv;
	if (count == 0) {
		return RES_OK;
	}
	if (buff == nullptr) {
		return RES_PARERR;
	}

	if (gDirectBuildMode) {
		if (gBuildFd < 0) {
			return RES_NOTRDY;
		}
		const uint64_t endSector = static_cast<uint64_t>(sector) + static_cast<uint64_t>(count);
		if (endSector > gBuildSectorCount) {
			return RES_PARERR;
		}
		const size_t byteCount = static_cast<size_t>(count) * deluge::engine::platform::kCardSectorBytes;
		const off_t offset = static_cast<off_t>(sector) * deluge::engine::platform::kCardSectorBytes;
		return preadAll(gBuildFd, buff, byteCount, offset) ? RES_OK : RES_ERROR;
	}

	if (gRuntimeFd < 0) {
		return RES_NOTRDY;
	}
	const uint64_t endSector = static_cast<uint64_t>(sector) + static_cast<uint64_t>(count);
	if (endSector > gRuntimeSectorCount) {
		return RES_PARERR;
	}

	// Match firmware/src/RZA1/diskio.c:196-210: forbid nested card access and hold currentlyAccessingCard across
	// the modelled transfer wait so loadAnyEnqueuedClusters() and RESOURCE_SD tasks do not re-enter mid-transfer.
	if (currentlyAccessingCard) {
		deluge::engine::platform::handleFreeze("E259");
	}
	currentlyAccessingCard = 1;

	const size_t byteCount = static_cast<size_t>(count) * deluge::engine::platform::kCardSectorBytes;
	const off_t offset = static_cast<off_t>(sector) * deluge::engine::platform::kCardSectorBytes;
	if (!preadAll(gRuntimeFd, buff, byteCount, offset)) {
		currentlyAccessingCard = 0;
		return RES_ERROR;
	}
	if (!gWriteOverlay.empty()) {
		for (UINT i = 0; i < count; i++) {
			auto it = gWriteOverlay.find(static_cast<uint64_t>(sector) + i);
			if (it != gWriteOverlay.end()) {
				std::memcpy(buff + static_cast<size_t>(i) * deluge::engine::platform::kCardSectorBytes,
				            it->second.data(), deluge::engine::platform::kCardSectorBytes);
			}
		}
	}

	gStats.readCalls++;
	gStats.sectorsRead += count;

	const uint64_t waitTicks = gReadCommandTicks + static_cast<uint64_t>(count) * gReadSectorTicks;
	if (waitTicks > 0) {
		gStats.modeledWaitCalls++;
		if (sdRoutineLock) {
			gStats.busyWaitCalls++;
		}
		gCardDoneAtTicks = host_virtual_ticks + waitTicks;
		const double timeoutS = (static_cast<double>(waitTicks) / DELUGE_CLOCKS_PERf) * 2.0 + 1.0;
		yieldingRoutineWithTimeoutForSD(cardTransferDone, timeoutS);
	}

	currentlyAccessingCard = 0;
	return RES_OK;
}

DRESULT disk_read(BYTE pdrv, BYTE* buff, LBA_t sector, UINT count) {
	if (!gDirectBuildMode) {
		loadAnyEnqueuedClustersRoutine(); // as RZA1/diskio.c does: SD streaming first
	}
	return disk_read_without_streaming_first(pdrv, buff, static_cast<DWORD>(sector), count);
}

DRESULT disk_write(BYTE pdrv, const BYTE* buff, LBA_t sector, UINT count) {
	(void)pdrv;
	if (count == 0) {
		return RES_OK;
	}
	if (buff == nullptr) {
		return RES_PARERR;
	}

	if (gDirectBuildMode) {
		if (gBuildFd < 0) {
			return RES_NOTRDY;
		}
		const uint64_t endSector = static_cast<uint64_t>(sector) + static_cast<uint64_t>(count);
		if (endSector > gBuildSectorCount) {
			return RES_PARERR;
		}
		const size_t byteCount = static_cast<size_t>(count) * deluge::engine::platform::kCardSectorBytes;
		const off_t offset = static_cast<off_t>(sector) * deluge::engine::platform::kCardSectorBytes;
		return pwriteAll(gBuildFd, buff, byteCount, offset) ? RES_OK : RES_ERROR;
	}

	loadAnyEnqueuedClustersRoutine(); // match RZA1/diskio.c:241
	if (gRuntimeFd < 0) {
		return RES_NOTRDY;
	}
	const uint64_t endSector = static_cast<uint64_t>(sector) + static_cast<uint64_t>(count);
	if (endSector > gRuntimeSectorCount) {
		return RES_PARERR;
	}
	if (currentlyAccessingCard) {
		deluge::engine::platform::handleFreeze("E258");
	}
	currentlyAccessingCard = 1;

	for (UINT i = 0; i < count; i++) {
		SectorData& slot = gWriteOverlay[static_cast<uint64_t>(sector) + i];
		std::memcpy(slot.data(), buff + static_cast<size_t>(i) * deluge::engine::platform::kCardSectorBytes,
		            deluge::engine::platform::kCardSectorBytes);
	}
	gStats.writeCalls++;
	gStats.sectorsWritten += count;

	currentlyAccessingCard = 0;
	return RES_OK;
}

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void* buff) {
	if (pdrv != 0) {
		return RES_PARERR;
	}
	const bool ready = gDirectBuildMode ? (gBuildFd >= 0) : (gRuntimeFd >= 0);
	if (!ready) {
		return RES_NOTRDY;
	}
	const uint64_t sectors = gDirectBuildMode ? gBuildSectorCount : gRuntimeSectorCount;
	switch (cmd) {
	case CTRL_SYNC:
		return RES_OK;
	case GET_SECTOR_COUNT:
		if (buff == nullptr) {
			return RES_PARERR;
		}
		*static_cast<LBA_t*>(buff) = static_cast<LBA_t>(sectors);
		return RES_OK;
	case GET_SECTOR_SIZE:
		if (buff == nullptr) {
			return RES_PARERR;
		}
		*static_cast<WORD*>(buff) = deluge::engine::platform::kCardSectorBytes;
		return RES_OK;
	case GET_BLOCK_SIZE:
		if (buff == nullptr) {
			return RES_PARERR;
		}
		*static_cast<DWORD*>(buff) = 1;
		return RES_OK;
	default:
		return RES_PARERR;
	}
}

DWORD get_fattime(void) {
	return (static_cast<DWORD>(2026 - 1980) << 25) | (1u << 21) | (1u << 16);
}

void disk_timerproc(UINT msPassed) {
	(void)msPassed;
}

} // extern "C"

namespace deluge::engine::platform {

bool openCardImage(const std::string& imagePath) {
	closeRuntimeLocked();
	int fd = -1;
	uint64_t sectors = 0;
	if (!openRegularImageFd(imagePath, O_RDONLY, fd, sectors)) {
		return false;
	}
	gRuntimeFd = fd;
	gRuntimeSectorCount = sectors;
	gRuntimePath = imagePath;
	// Leave STA_NOINIT set (without STA_NODISK) so StorageManager::initSD() mounts the new volume and updates
	// Cluster::size via audioFileManager.firstCardRead().
	gRuntimeStatus = STA_NOINIT;
	return true;
}

void closeCardImage() {
	closeRuntimeLocked();
}

bool isCardImageOpen() {
	return gRuntimeFd >= 0;
}

std::string cardImagePath() {
	return gRuntimePath;
}

uint64_t cardImageSectorCount() {
	return gRuntimeSectorCount;
}

void setCardReadTimingUs(double commandUs, double sectorUs) {
	gReadCommandUs = commandUs > 0.0 ? commandUs : 0.0;
	gReadSectorUs = sectorUs > 0.0 ? sectorUs : 0.0;
	gReadCommandTicks = static_cast<uint64_t>(gReadCommandUs * DELUGE_CLOCKS_PERf / 1e6);
	gReadSectorTicks = static_cast<uint64_t>(gReadSectorUs * DELUGE_CLOCKS_PERf / 1e6);
}

double cardReadCommandUs() {
	return gReadCommandUs;
}

double cardReadSectorUs() {
	return gReadSectorUs;
}

size_t writeOverlaySectorCount() {
	return gWriteOverlay.size();
}

void clearWriteOverlay() {
	gWriteOverlay.clear();
}

DiskStats diskStats() {
	return gStats;
}

void resetDiskStats() {
	gStats = {};
}

namespace detail {

ScopedDirectCardBuild::ScopedDirectCardBuild(const std::string& imagePath) {
	gBuildMutex.lock();
	int fd = -1;
	uint64_t sectors = 0;
	if (!openRegularImageFd(imagePath, O_RDWR, fd, sectors)) {
		error_ = "failed to open card image for writing: " + imagePath + " (" + std::strerror(errno) + ")";
		gBuildMutex.unlock();
		return;
	}
	gBuildFd = fd;
	gBuildSectorCount = sectors;
	gBuildStatus = STA_NOINIT;
	gDirectBuildMode = true;
	open_ = true;
}

ScopedDirectCardBuild::~ScopedDirectCardBuild() {
	if (!open_) {
		return;
	}
	gDirectBuildMode = false;
	if (gBuildFd >= 0) {
		::close(gBuildFd);
		gBuildFd = -1;
	}
	gBuildSectorCount = 0;
	gBuildStatus = STA_NOINIT | STA_NODISK;
	open_ = false;
	gBuildMutex.unlock();
}

bool ScopedDirectCardBuild::sync() {
	if (!open_ || gBuildFd < 0) {
		return false;
	}
	if (::fsync(gBuildFd) != 0) {
		error_ = std::string("fsync failed: ") + std::strerror(errno);
		return false;
	}
	return true;
}

} // namespace detail

} // namespace deluge::engine::platform
