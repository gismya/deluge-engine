// Storage & card-image tests (E3, spec §3.6):
//   --unit <pack_dir> <temp_dir>              builder, incremental refresh, device format, pack preset/sample,
//                                             write overlay, read-time model, DMA overrun prevention
//   --concurrent-reader <img_path> <tag>      mounts shared image read-only, reads pack preset & sample, writes
//                                             process-local overlay file and reads it back
//   --verify-disk-clean <img_path>            mounts image read-only and verifies no overlay files leaked onto disk
//   --build-only <card_dir> <cache_dir>       builds or refreshes card image from <card_dir> (used for local checks)
#include "OSLikeStuff/scheduler_api.h"
#include "definitions_cxx.hpp"
#include "fatfs/diskio.h"
#include "fatfs/ff.h"
#include "model/instrument/instrument.h"
#include "model/song/song.h"
#include "platform/card_image.h"
#include "platform/host_platform.h"
#include "storage/audio/audio_file_manager.h"
#include "storage/cluster/cluster.h"
#include "storage/storage_manager.h"
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <string>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>
#include <utility>
#include <vector>

extern "C" {
extern uint8_t currentlyAccessingCard;
DRESULT disk_read_without_streaming_first(BYTE pdrv, BYTE* buff, DWORD sector, UINT count);
}
extern bool sdRoutineLock;

namespace fs = std::filesystem;
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

bool writeHostFile(const fs::path& path, const std::string& content) {
	std::error_code ec;
	fs::create_directories(path.parent_path(), ec);
	std::ofstream out(path, std::ios::binary | std::ios::trunc);
	if (!out) {
		return false;
	}
	out.write(content.data(), static_cast<std::streamsize>(content.size()));
	return out.good();
}

bool readFatFile(const char* fatPath, std::string& out) {
	FIL fil;
	if (f_open(&fil, fatPath, FA_READ) != FR_OK) {
		return false;
	}
	out.clear();
	char buf[4096];
	UINT br = 0;
	for (;;) {
		if (f_read(&fil, buf, sizeof(buf), &br) != FR_OK) {
			f_close(&fil);
			return false;
		}
		if (br == 0) {
			break;
		}
		out.append(buf, br);
	}
	f_close(&fil);
	return true;
}

bool writeFatFile(const char* fatPath, const std::string& data) {
	FIL fil;
	if (f_open(&fil, fatPath, FA_CREATE_ALWAYS | FA_WRITE) != FR_OK) {
		return false;
	}
	UINT bw = 0;
	FRESULT res = f_write(&fil, data.data(), static_cast<UINT>(data.size()), &bw);
	FRESULT closeRes = f_close(&fil);
	return res == FR_OK && closeRes == FR_OK && bw == data.size();
}

bool fatFileExists(const char* fatPath) {
	FILINFO fno;
	return f_stat(fatPath, &fno) == FR_OK;
}

// Compute a fast FNV-1a 64-bit hash of the non-zero / full sectors of a file (using lseek SEEK_DATA on sparse APFS
// files so hashing a 2.2 GB sparse image takes milliseconds instead of seconds!).
uint64_t hashSparseFile(const std::string& path, uint64_t* outSize = nullptr) {
	int fd = ::open(path.c_str(), O_RDONLY);
	if (fd < 0) {
		return 0;
	}
	struct stat st {};
	if (::fstat(fd, &st) != 0) {
		::close(fd);
		return 0;
	}
	if (outSize != nullptr) {
		*outSize = static_cast<uint64_t>(st.st_size);
	}
	uint64_t h = 14695981039346656037ull;
	auto mix = [&](const uint8_t* p, size_t n) {
		for (size_t i = 0; i < n; i++) {
			h ^= p[i];
			h *= 1099511628211ull;
		}
	};
	auto mixU64 = [&](uint64_t v) { mix(reinterpret_cast<const uint8_t*>(&v), sizeof(v)); };

	off_t pos = 0;
	std::vector<uint8_t> buf(65536);
	while (pos < st.st_size) {
		off_t dataStart = ::lseek(fd, pos, SEEK_DATA);
		if (dataStart < 0) {
			break; // remaining tail is a hole
		}
		off_t holeStart = ::lseek(fd, dataStart, SEEK_HOLE);
		if (holeStart < 0 || holeStart > st.st_size) {
			holeStart = st.st_size;
		}
		mixU64(static_cast<uint64_t>(dataStart));
		mixU64(static_cast<uint64_t>(holeStart - dataStart));
		off_t cur = dataStart;
		while (cur < holeStart) {
			size_t chunk = static_cast<size_t>(std::min<off_t>(holeStart - cur, static_cast<off_t>(buf.size())));
			ssize_t got = ::pread(fd, buf.data(), chunk, cur);
			if (got <= 0) {
				break;
			}
			mix(buf.data(), static_cast<size_t>(got));
			cur += got;
		}
		pos = holeStart;
	}
	::close(fd);
	return h;
}

// ---- Test 1: Incremental builder (build on worker thread, cache hit, edit, add, delete, dir delete)
void testIncrementalBuilder(const fs::path& tempDir) {
	fs::path cardDir = tempDir / "inc_card";
	fs::path cacheDir = tempDir / "inc_cache";

	CHECK(writeHostFile(cardDir / "SYNTHS/A.XML", "<sound>alpha-v1</sound>\n"));
	CHECK(writeHostFile(cardDir / "SYNTHS/B.XML", "<sound>beta-v1</sound>\n"));
	CHECK(writeHostFile(cardDir / "SAMPLES/SUB/ONE.WAV", std::string(40000, 'X'))); // > 1 cluster (32 KiB)
	CHECK(writeHostFile(cardDir / ".DS_Store", "ignored-macos-junk"));
	CHECK(writeHostFile(cardDir / "SYNTHS/._A.XML", "ignored-appledouble"));

	// Build on a dedicated worker thread (spec §3.6: never on engine thread).
	std::vector<std::pair<uint32_t, uint32_t>> progress;
	plat::CardImageOptions opts;
	opts.cacheDir = cacheDir.string();
	opts.onProgress = [&](uint32_t done, uint32_t total) { progress.emplace_back(done, total); };

	plat::CardImageResult r1;
	std::thread builder([&]() { r1 = plat::buildOrRefreshCardImage(cardDir.string(), opts); });
	builder.join();

	CHECK(r1.ok);
	if (!r1.ok) {
		std::fprintf(stderr, "buildOrRefreshCardImage failed: %s\n", r1.error.c_str());
		return;
	}
	CHECK(r1.fullRebuild);
	CHECK(r1.clusterBytes == plat::kCardClusterBytes);
	CHECK(r1.filesWritten == 3);
	CHECK(r1.filesRemoved == 0);
	CHECK(r1.totalFiles == 3);
	CHECK(!progress.empty());
	CHECK(progress.front().first == 0 && progress.front().second == 3);
	CHECK(progress.back().first == 3 && progress.back().second == 3);

	// Mount read-only with FatFS directly (timing off for quick check) and verify contents.
	plat::setCardReadTimingUs(0.0, 0.0);
	CHECK(plat::openCardImage(r1.imagePath));
	{
		FATFS fsObj;
		CHECK(f_mount(&fsObj, "", 1) == FR_OK);
		CHECK(fsObj.fs_type == FS_FAT32);
		CHECK(fsObj.csize == 64); // 32 KiB clusters
		std::string s;
		CHECK(readFatFile("SYNTHS/A.XML", s) && s == "<sound>alpha-v1</sound>\n");
		CHECK(readFatFile("SYNTHS/B.XML", s) && s == "<sound>beta-v1</sound>\n");
		CHECK(readFatFile("SAMPLES/SUB/ONE.WAV", s) && s.size() == 40000 && s[0] == 'X' && s.back() == 'X');
		CHECK(!fatFileExists(".DS_Store"));
		CHECK(!fatFileExists("SYNTHS/._A.XML"));
		f_mount(nullptr, "", 1);
	}
	plat::closeCardImage();

	// Second build with no changes -> cache hit, no rebuild, 0 files written.
	progress.clear();
	plat::CardImageResult r2 = plat::buildOrRefreshCardImage(cardDir.string(), opts);
	CHECK(r2.ok);
	CHECK(!r2.fullRebuild);
	CHECK(r2.filesWritten == 0);
	CHECK(r2.filesRemoved == 0);
	CHECK(r2.imagePath == r1.imagePath);

	// Modify A.XML (ensure mtime advances even on coarse filesystems by sleeping 5ms + changing size).
	std::this_thread::sleep_for(std::chrono::milliseconds(5));
	CHECK(writeHostFile(cardDir / "SYNTHS/A.XML", "<sound>alpha-v2-updated</sound>\n"));
	// Add a new file in a new directory.
	CHECK(writeHostFile(cardDir / "KITS/NEW_KIT.XML", "<kit>hello</kit>\n"));
	// Delete SAMPLES/SUB/ONE.WAV and its now-empty directory SAMPLES/SUB.
	std::error_code ec;
	fs::remove(cardDir / "SAMPLES/SUB/ONE.WAV", ec);
	fs::remove(cardDir / "SAMPLES/SUB", ec);

	progress.clear();
	plat::CardImageResult r3 = plat::buildOrRefreshCardImage(cardDir.string(), opts);
	CHECK(r3.ok);
	if (!r3.ok) {
		std::fprintf(stderr, "incremental refresh failed: %s\n", r3.error.c_str());
		return;
	}
	CHECK(!r3.fullRebuild); // MUST be incremental, not a full rebuild!
	CHECK(r3.filesWritten == 2); // A.XML updated + NEW_KIT.XML added
	CHECK(r3.filesRemoved == 1); // ONE.WAV deleted
	CHECK(r3.dirsRemoved >= 1);  // SAMPLES/SUB removed
	CHECK(r3.totalFiles == 3);   // A.XML, B.XML, NEW_KIT.XML
	CHECK(!progress.empty() && progress.back().first == 3 && progress.back().second == 3);

	// Verify refreshed image contents.
	CHECK(plat::openCardImage(r3.imagePath));
	{
		FATFS fsObj;
		CHECK(f_mount(&fsObj, "", 1) == FR_OK);
		std::string s;
		CHECK(readFatFile("SYNTHS/A.XML", s) && s == "<sound>alpha-v2-updated</sound>\n");
		CHECK(readFatFile("SYNTHS/B.XML", s) && s == "<sound>beta-v1</sound>\n");
		CHECK(readFatFile("KITS/NEW_KIT.XML", s) && s == "<kit>hello</kit>\n");
		CHECK(!fatFileExists("SAMPLES/SUB/ONE.WAV"));
		CHECK(!fatFileExists("SAMPLES/SUB"));
		f_mount(nullptr, "", 1);
	}
	plat::closeCardImage();
	plat::setCardReadTimingUs(plat::kDefaultCardReadCommandUs, plat::kDefaultCardReadSectorUs);
}

// ---- Test 2: macOS 26 hdiutil device format fallback route
void testDeviceFormatRoute(const fs::path& tempDir) {
	fs::path cardDir = tempDir / "devfmt_card";
	fs::path cacheDir = tempDir / "devfmt_cache";
	CHECK(writeHostFile(cardDir / "SYNTHS/DEV.XML", "<sound>via-hdiutil</sound>\n"));

	plat::CardImageOptions opts;
	opts.cacheDir = cacheDir.string();
	opts.forceDeviceFormat = true;
	plat::CardImageResult r = plat::buildOrRefreshCardImage(cardDir.string(), opts);
	CHECK(r.ok);
	if (!r.ok) {
		std::fprintf(stderr, "device format route failed: %s\n", r.error.c_str());
		return;
	}
	CHECK(r.fullRebuild);
	CHECK(r.clusterBytes == plat::kCardClusterBytes);

	plat::setCardReadTimingUs(0.0, 0.0);
	CHECK(plat::openCardImage(r.imagePath));
	{
		FATFS fsObj;
		CHECK(f_mount(&fsObj, "", 1) == FR_OK);
		CHECK(fsObj.fs_type == FS_FAT32);
		CHECK(fsObj.csize == 64);
		std::string s;
		CHECK(readFatFile("SYNTHS/DEV.XML", s) && s == "<sound>via-hdiutil</sound>\n");
		f_mount(nullptr, "", 1);
	}
	plat::closeCardImage();
	plat::setCardReadTimingUs(plat::kDefaultCardReadCommandUs, plat::kDefaultCardReadSectorUs);
}

// ---- Test 3: Pack image build + firmware boot + preset & sample loading + write overlay + read-time model
// Global state for the scheduler read-time model + DMA overrun check.
std::atomic<bool> gReadTriggered{false};
std::atomic<bool> gReadDone{false};
bool gSawCurrentlyAccessingCardDuringYield = false;
uint64_t gReadVirtualTicksDelta = 0;
uint64_t gReadDmaFramesDelta = 0;
uint64_t gReadOverrunsDelta = 0;
uint64_t gReadBusyWaitsDelta = 0;

void observeCardFlagTask() {
	if (currentlyAccessingCard != 0) {
		gSawCurrentlyAccessingCardDuringYield = true;
	}
}

void timedReadTask() {
	if (gReadTriggered.exchange(true)) {
		return;
	}
	// Perform a 64-sector (32 KiB cluster) raw read inside the running scheduler, just like AudioFileManager::loadCluster.
	uint8_t buf[64 * 512];
	uint64_t ticksBefore = plat::virtualTicks();
	uint64_t framesBefore = plat::dmaFrames();
	uint64_t overrunsBefore = plat::dmaOverruns();
	uint64_t busyBefore = plat::diskStats().busyWaitCalls;

	DRESULT res = disk_read_without_streaming_first(0, buf, 0, 64);
	CHECK(res == RES_OK);

	gReadVirtualTicksDelta = plat::virtualTicks() - ticksBefore;
	gReadDmaFramesDelta = plat::dmaFrames() - framesBefore;
	gReadOverrunsDelta = plat::dmaOverruns() - overrunsBefore;
	gReadBusyWaitsDelta = plat::diskStats().busyWaitCalls - busyBefore;
	gReadDone.store(true);
}

void testPackFirmwareOverlayAndReadModel(const fs::path& packDir, const fs::path& tempDir) {
	// Verify default read-time model is ON: 300 us + 40 us/sector.
	CHECK(plat::cardReadCommandUs() == plat::kDefaultCardReadCommandUs);
	CHECK(plat::cardReadSectorUs() == plat::kDefaultCardReadSectorUs);

	// 1. Build card image from firmware/pack/ on a worker thread BEFORE bootFirmware().
	fs::path cacheDir = tempDir / "pack_cache";
	plat::CardImageOptions opts;
	opts.cacheDir = cacheDir.string();
	plat::CardImageResult built;
	std::thread builder([&]() { built = plat::buildOrRefreshCardImage(packDir.string(), opts); });
	builder.join();
	CHECK(built.ok);
	if (!built.ok) {
		std::fprintf(stderr, "pack build failed: %s\n", built.error.c_str());
		return;
	}
	CHECK(built.totalFiles >= 30);

	// Snapshot disk image hash & mtime before mounting/writing.
	uint64_t sizeBefore = 0;
	uint64_t hashBefore = hashSparseFile(built.imagePath, &sizeBefore);
	struct stat stBefore {};
	CHECK(::stat(built.imagePath.c_str(), &stBefore) == 0);
	CHECK(hashBefore != 0 && sizeBefore == built.imageBytes);

	// 2. Open read-only and boot the firmware.
	CHECK(plat::openCardImage(built.imagePath));
	plat::resetClock();
	plat::setPace(0.0);
	plat::bootFirmware();
	CHECK(Cluster::size == plat::kCardClusterBytes); // 32 KiB clusters from FAT32 BPB

	// 3. Load a CC0 pack synth preset through StorageManager.
	const char* synthPath = "SYNTHS/GENERATIVE/GEN Sine Sub.XML";
	FilePointer fp;
	CHECK(StorageManager::fileExists(synthPath, &fp));
	String name;
	String dir;
	name.set("GEN Sine Sub.XML");
	dir.set("SYNTHS/GENERATIVE");
	Instrument* inst = nullptr;
	Error loadErr =
	    StorageManager::loadInstrumentFromFile(currentSong, nullptr, OutputType::SYNTH, true, &inst, &fp, &name, &dir);
	CHECK(loadErr == Error::NONE && inst != nullptr);

	// 4. Load a CC0 pack WAV sample (multi-cluster: ~700 KB = ~22 clusters of 32 KiB) via AudioFileManager
	//    and stream clusters via raw sector reads (disk_read_without_streaming_first).
	String samplePath;
	samplePath.set("SAMPLES/FX/Riser/GEN Riser 1.wav");
	Error sampleErr = Error::NONE;
	uint64_t readsBeforeSample = plat::diskStats().readCalls;
	AudioFile* audioFile = audioFileManager.getAudioFileFromFilename(samplePath, true, &sampleErr, nullptr,
	                                                                 AudioFileType::SAMPLE);
	CHECK(sampleErr == Error::NONE && audioFile != nullptr);
	audioFileManager.loadAnyEnqueuedClusters(128, false);
	CHECK(plat::diskStats().readCalls > readsBeforeSample);

	// 5. Write overlay test: write a new file, overwrite an existing file, create a dir, read back in same process,
	//    and verify the image file on disk is 100% untouched!
	CHECK(f_mkdir("OVERLAY_DIR") == FR_OK);
	const std::string writtenPayload = "overlay-write-test-payload-0123456789abcdef\n";
	CHECK(writeFatFile("OVERLAY_DIR/NEW.TXT", writtenPayload));
	std::string readBack;
	CHECK(readFatFile("OVERLAY_DIR/NEW.TXT", readBack));
	CHECK(readBack == writtenPayload);

	// Overwrite an existing file in the overlay and read back the modified version.
	const std::string overwrittenPayload = "overwritten-in-memory-only\n";
	CHECK(writeFatFile("LICENSES.md", overwrittenPayload));
	CHECK(readFatFile("LICENSES.md", readBack));
	CHECK(readBack == overwrittenPayload);
	CHECK(plat::writeOverlaySectorCount() > 0);

	// Disk image MUST be bit-for-bit unchanged (same hash, same size, same mtime)!
	uint64_t sizeAfter = 0;
	uint64_t hashAfter = hashSparseFile(built.imagePath, &sizeAfter);
	struct stat stAfter {};
	CHECK(::stat(built.imagePath.c_str(), &stAfter) == 0);
	CHECK(sizeAfter == sizeBefore);
	CHECK(hashAfter == hashBefore);
	CHECK(stAfter.st_mtimespec.tv_sec == stBefore.st_mtimespec.tv_sec
	      && stAfter.st_mtimespec.tv_nsec == stBefore.st_mtimespec.tv_nsec);

	// 6. Read-time model + DMA overrun prevention inside the running scheduler.
	plat::resetDma();
	plat::setDmaFollowsClock(true);
	gReadTriggered.store(false);
	gReadDone.store(false);
	gSawCurrentlyAccessingCardDuringYield = false;
	addRepeatingTask(observeCardFlagTask, 5, 0.0002, 0.0002, 0.0005, "obs_card", RESOURCE_NONE);
	addRepeatingTask(timedReadTask, 25, 0.002, 0.005, 0.01, "timed_read", RESOURCE_SD | RESOURCE_SD_ROUTINE);

	plat::runScheduler(0.05); // 50 ms virtual time

	CHECK(gReadDone.load());
	// 300 us + 64 * 40 us = 2860 us = ~95,323 ticks at 33.33 MHz.
	const uint64_t expectedMinTicks =
	    static_cast<uint64_t>((300.0 + 64.0 * 40.0) * DELUGE_CLOCKS_PERf / 1e6);
	CHECK(gReadVirtualTicksDelta >= expectedMinTicks);
	// During the 2.86 ms wait, yieldingRoutineWithTimeoutForSD yielded to AudioEngine -> ~126 DMA frames, 0 overruns!
	CHECK(gSawCurrentlyAccessingCardDuringYield);
	CHECK(gReadDmaFramesDelta >= 100);
	CHECK(gReadOverrunsDelta == 0);
	CHECK(gReadBusyWaitsDelta == 0);
	CHECK(plat::dmaOverruns() == 0);
	CHECK(currentlyAccessingCard == 0);
	CHECK(sdRoutineLock == false);

	plat::setDmaFollowsClock(false);
}

int runConcurrentReader(const char* imagePath, const char* tag) {
	if (!plat::openCardImage(imagePath)) {
		std::fprintf(stderr, "concurrent-reader[%s]: failed to open %s\n", tag, imagePath);
		return 1;
	}
	plat::resetClock();
	plat::setPace(0.0);
	plat::bootFirmware();
	if (Cluster::size != plat::kCardClusterBytes) {
		std::fprintf(stderr, "concurrent-reader[%s]: bad Cluster::size %zu\n", tag, Cluster::size);
		return 1;
	}

	// Read a preset and a multi-cluster sample from the shared image.
	std::string preset;
	if (!readFatFile("SYNTHS/GENERATIVE/GEN Sine Sub.XML", preset) || preset.find("<sound") == std::string::npos) {
		std::fprintf(stderr, "concurrent-reader[%s]: failed reading preset\n", tag);
		return 1;
	}
	std::string sample;
	if (!readFatFile("SAMPLES/FX/Riser/GEN Riser 1.wav", sample) || sample.size() < 65536
	    || sample.compare(0, 4, "RIFF") != 0) {
		std::fprintf(stderr, "concurrent-reader[%s]: failed reading sample\n", tag);
		return 1;
	}

	// Write a process-local file into our own write overlay and read it back.
	std::string localName = std::string("PROC_") + tag + ".TXT";
	std::string payload = std::string("written-by-") + tag + "\n";
	if (!writeFatFile(localName.c_str(), payload)) {
		std::fprintf(stderr, "concurrent-reader[%s]: overlay write failed\n", tag);
		return 1;
	}
	std::string readBack;
	if (!readFatFile(localName.c_str(), readBack) || readBack != payload) {
		std::fprintf(stderr, "concurrent-reader[%s]: overlay read-back mismatch\n", tag);
		return 1;
	}

	// Verify we do NOT see the other process's overlay file.
	std::string otherTag = (std::strcmp(tag, "A") == 0) ? "B" : "A";
	if (fatFileExists((std::string("PROC_") + otherTag + ".TXT").c_str())) {
		std::fprintf(stderr, "concurrent-reader[%s]: leaked overlay from %s\n", tag, otherTag.c_str());
		return 1;
	}

	std::fprintf(stderr, "concurrent-reader[%s]: ok (overlay sectors=%zu)\n", tag, plat::writeOverlaySectorCount());
	return 0;
}

int runVerifyDiskClean(const char* imagePath) {
	plat::setCardReadTimingUs(0.0, 0.0);
	if (!plat::openCardImage(imagePath)) {
		std::fprintf(stderr, "verify-disk-clean: failed to open %s\n", imagePath);
		return 1;
	}
	FATFS fsObj;
	if (f_mount(&fsObj, "", 1) != FR_OK) {
		std::fprintf(stderr, "verify-disk-clean: f_mount failed\n");
		return 1;
	}
	bool bad = fatFileExists("OVERLAY_DIR/NEW.TXT") || fatFileExists("PROC_A.TXT") || fatFileExists("PROC_B.TXT");
	f_mount(nullptr, "", 1);
	plat::closeCardImage();
	if (bad) {
		std::fprintf(stderr, "verify-disk-clean: overlay file leaked to disk image!\n");
		return 1;
	}
	return 0;
}

int runBuildOnly(const char* cardDir, const char* cacheDir) {
	plat::CardImageOptions opts;
	opts.cacheDir = cacheDir;
	uint32_t lastTotal = 0;
	opts.onProgress = [&](uint32_t done, uint32_t total) { lastTotal = total; (void)done; };
	plat::CardImageResult r = plat::buildOrRefreshCardImage(cardDir, opts);
	if (!r.ok) {
		std::fprintf(stderr, "build-only failed: %s\n", r.error.c_str());
		return 1;
	}
	std::fprintf(stdout, "%s\n", r.imagePath.c_str());
	std::fprintf(stderr, "built %s: fullRebuild=%d filesWritten=%u filesRemoved=%u totalFiles=%u clusterBytes=%u lastTotal=%u\n",
	             r.imagePath.c_str(), r.fullRebuild ? 1 : 0, r.filesWritten, r.filesRemoved, r.totalFiles,
	             r.clusterBytes, lastTotal);
	return 0;
}

} // namespace

int main(int argc, char** argv) {
	if (argc < 2) {
		std::fprintf(stderr,
		             "usage: test_storage --unit <pack_dir> <temp_dir> | "
		             "--concurrent-reader <img_path> <tag> | "
		             "--verify-disk-clean <img_path> | "
		             "--build-only <card_dir> <cache_dir>\n");
		std::_Exit(2);
	}
	const char* mode = argv[1];
	if (std::strcmp(mode, "--unit") == 0 && argc >= 4) {
		fs::path packDir = argv[2];
		fs::path tempDir = argv[3];
		testIncrementalBuilder(tempDir);
		testDeviceFormatRoute(tempDir);
		testPackFirmwareOverlayAndReadModel(packDir, tempDir);
		std::fprintf(stderr, "test_storage --unit: %d failures\n", gFailures);
		std::fflush(nullptr);
		std::_Exit(gFailures == 0 ? 0 : 1);
	}
	if (std::strcmp(mode, "--concurrent-reader") == 0 && argc >= 4) {
		int status = runConcurrentReader(argv[2], argv[3]);
		std::fflush(nullptr);
		std::_Exit(status);
	}
	if (std::strcmp(mode, "--verify-disk-clean") == 0 && argc >= 3) {
		int status = runVerifyDiskClean(argv[2]);
		std::fflush(nullptr);
		std::_Exit(status);
	}
	if (std::strcmp(mode, "--build-only") == 0 && argc >= 4) {
		int status = runBuildOnly(argv[2], argv[3]);
		std::fflush(nullptr);
		std::_Exit(status);
	}
	std::fprintf(stderr, "unknown mode or missing arguments: %s\n", mode);
	std::_Exit(2);
}
