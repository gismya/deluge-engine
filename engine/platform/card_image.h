// Card image builder, host sector device, read-time model, and write overlay (E3, spec §3.6).
//
// The Deluge firmware reads sample data via raw FAT32 cluster sector reads (disk_read_without_streaming_first +
// clst2sect), so the Engine builds a FAT32 card image (32 KiB clusters) from a card folder using newfs_msdos and the
// linked FatFS, caches it under ~/Library/Caches/deluge-engine/cards/, and refreshes it incrementally from a
// path/size/mtime manifest before the firmware boots.
//
// At runtime, the sector device opens the image read-only (safe for concurrent processes). Firmware writes go to an
// in-memory sector overlay dropped at exit, and reads wait out a modelled transfer time (300 us + 40 us per sector
// of virtual time by default) through yieldingRoutineWithTimeoutForSD().
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>

namespace deluge::engine::platform {

// ---- Geometry & timing defaults (spec §3.6)
constexpr uint32_t kCardSectorBytes = 512;
constexpr uint32_t kCardClusterSectors = 64; // 32 KiB clusters, matching delugemu/scripts/mksd.sh
constexpr uint32_t kCardClusterBytes = kCardSectorBytes * kCardClusterSectors;

constexpr double kDefaultCardReadCommandUs = 300.0;
constexpr double kDefaultCardReadSectorUs = 40.0;

// ---- Sector device, write overlay, and read-time model (host_diskio.cpp)
// Opens a FAT32 card image read-only for the firmware's FatFS, clearing any prior write overlay and marking the
// drive uninitialized so StorageManager::initSD() mounts it and updates Cluster::size.
bool openCardImage(const std::string& imagePath);
void closeCardImage();
bool isCardImageOpen();
std::string cardImagePath();
uint64_t cardImageSectorCount();

// Modelled SD read time (virtual clock, via yieldingRoutineWithTimeoutForSD). Enabled by default at 300 us + 40 us
// per 512-byte sector. Passing (0, 0) disables modelled read waits.
void setCardReadTimingUs(double commandUs, double sectorUs);
double cardReadCommandUs();
double cardReadSectorUs();

// In-memory write overlay: changed sectors belong to this process and are never written to the image file on disk.
size_t writeOverlaySectorCount();
void clearWriteOverlay();

struct DiskStats {
	uint64_t readCalls = 0;
	uint64_t sectorsRead = 0;
	uint64_t writeCalls = 0;
	uint64_t sectorsWritten = 0;
	uint64_t modeledWaitCalls = 0;
	uint64_t busyWaitCalls = 0; // reads where sdRoutineLock was already true (busy-wait instead of yielding)
};
DiskStats diskStats();
void resetDiskStats();

// ---- Card image builder & incremental refresh (card_image.cpp)
// Default cache root: ~/Library/Caches/deluge-engine/cards.
std::string defaultCardCacheDir();

using CardProgressFn = std::function<void(uint32_t done, uint32_t total)>;

struct CardImageOptions {
	std::string cacheDir;        // empty -> defaultCardCacheDir()
	CardProgressFn onProgress;   // optional progress callback: (done, total) work items
	bool forceRebuild = false;   // ignore existing cached image/manifest and format fresh
	bool forceDeviceFormat = false; // format via hdiutil raw-disk attach (macOS 26 fallback route)
};

struct CardImageResult {
	bool ok = false;
	std::string error;
	std::string imagePath;
	std::string manifestPath;
	uint64_t imageBytes = 0;
	uint32_t clusterBytes = 0;
	bool fullRebuild = false;
	uint32_t filesWritten = 0;
	uint32_t filesRemoved = 0;
	uint32_t dirsCreated = 0;
	uint32_t dirsRemoved = 0;
	uint32_t totalFiles = 0;
};

// Builds or incrementally refreshes the cached FAT32 card image for `cardFolder` using newfs_msdos and the linked
// FatFS. Must run before the firmware boots (and never concurrently with firmware FatFS access); safe to run on a
// dedicated worker thread. Serializes concurrent builders on the same cache entry via flock.
CardImageResult buildOrRefreshCardImage(const std::string& cardFolder, const CardImageOptions& options = {});

namespace detail {

// RAII scope switching host_diskio into direct read/write mode for the card image builder (bypasses overlay,
// read-time model, and loadAnyEnqueuedClustersRoutine). Restores prior closed/runtime state on destruction.
class ScopedDirectCardBuild {
public:
	explicit ScopedDirectCardBuild(const std::string& imagePath);
	~ScopedDirectCardBuild();

	ScopedDirectCardBuild(const ScopedDirectCardBuild&) = delete;
	ScopedDirectCardBuild& operator=(const ScopedDirectCardBuild&) = delete;

	bool isOpen() const { return open_; }
	bool sync();
	std::string error() const { return error_; }

private:
	bool open_ = false;
	std::string error_;
};

} // namespace detail

} // namespace deluge::engine::platform
