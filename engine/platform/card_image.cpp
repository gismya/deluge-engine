// Card image builder and incremental refresher (E3, spec §3.6).
//
// Formats a sparse FAT32 image with 32 KiB clusters using macOS newfs_msdos (with an automatic hdiutil raw-disk
// fallback on macOS 26 where newfs_msdos refuses plain files), populates and incrementally refreshes it through the
// linked firmware FatFS (ff.c), caches it under ~/Library/Caches/deluge-engine/cards/, and reports progress through a
// callback. Must run before the firmware boots (safe on its own thread; serialized per cache entry via flock).
#include "fatfs/ff.h"
#include "platform/card_image.h"
#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <map>
#include <poll.h>
#include <set>
#include <spawn.h>
#include <sstream>
#include <string>
#if defined(__APPLE__)
#include <sys/clonefile.h>
#endif
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

extern char** environ;

namespace fs = std::filesystem;

namespace deluge::engine::platform {

namespace {

constexpr uint64_t kMiB = 1024ull * 1024ull;
// FAT32 with 32 KiB clusters requires at least 65,525 clusters (~2048 MiB) plus FAT tables and reserved sectors.
constexpr uint64_t kMinImageBytes = 2200ull * kMiB;
constexpr uint64_t kSizeAlignBytes = 64ull * kMiB;
constexpr size_t kCopyBufferBytes = 65536;
constexpr const char* kManifestHeader = "DELUGE_CARD_MANIFEST v1";

// File-scope FATFS for card_image.cpp (guarded by ScopedDirectCardBuild's mutex). Note: the firmware's modified ff.c
// short-circuits `f_mount(nullptr, "", 0)` when `FatFs[0]` is non-null, so unmount MUST pass opt=1 (`f_mount(nullptr,
// "", 1)`) to actually clear `FatFs[0]` before releasing the FATFS object.
FATFS gBuilderFatFs{};

void unmountFatVolume() {
	f_mount(nullptr, "", 1);
}

struct FileEntry {
	std::string relPath;
	uint64_t size = 0;
	int64_t mtimeNs = 0;
};

struct FolderScan {
	std::vector<std::string> dirs; // relative paths (using '/'), sorted shallowest-first
	std::vector<FileEntry> files;  // sorted lexicographically by relPath
	uint64_t neededDataBytes = 0;
};

struct Manifest {
	std::string source;
	uint64_t imageBytes = 0;
	uint64_t imageIno = 0;
	uint32_t clusterBytes = 0;
	std::set<std::string> dirs;
	std::map<std::string, FileEntry> files;
};

int64_t statMtimeNs(const struct stat& st) {
#if defined(__APPLE__)
	return static_cast<int64_t>(st.st_mtimespec.tv_sec) * 1'000'000'000LL
	       + static_cast<int64_t>(st.st_mtimespec.tv_nsec);
#else
	return static_cast<int64_t>(st.st_mtim.tv_sec) * 1'000'000'000LL + static_cast<int64_t>(st.st_mtim.tv_nsec);
#endif
}

size_t pathDepth(const std::string& relPath) {
	return static_cast<size_t>(std::count(relPath.begin(), relPath.end(), '/'));
}

uint64_t clustersForFileSize(uint64_t size) {
	if (size == 0) {
		return 0;
	}
	return (size + kCardClusterBytes - 1) / kCardClusterBytes;
}

uint64_t computeTargetImageBytes(uint64_t neededDataBytes) {
	// Add 25% + 64 MiB headroom for FAT tables, LFN directory clusters, and incremental updates.
	const uint64_t withHeadroom = neededDataBytes + (neededDataBytes / 4) + (64ull * kMiB);
	const uint64_t aligned = ((withHeadroom + kSizeAlignBytes - 1) / kSizeAlignBytes) * kSizeAlignBytes;
	return std::max(kMinImageBytes, aligned);
}

std::string percentEncode(const std::string& s) {
	static constexpr char kHex[] = "0123456789ABCDEF";
	std::string out;
	out.reserve(s.size());
	for (unsigned char c : s) {
		if (c == '%' || c == '\t' || c == '\n' || c == '\r') {
			out.push_back('%');
			out.push_back(kHex[c >> 4]);
			out.push_back(kHex[c & 0x0Fu]);
		}
		else {
			out.push_back(static_cast<char>(c));
		}
	}
	return out;
}

bool percentDecode(const std::string& s, std::string& out) {
	out.clear();
	out.reserve(s.size());
	auto hexVal = [](char c) -> int {
		if (c >= '0' && c <= '9') {
			return c - '0';
		}
		if (c >= 'A' && c <= 'F') {
			return 10 + (c - 'A');
		}
		if (c >= 'a' && c <= 'f') {
			return 10 + (c - 'a');
		}
		return -1;
	};
	for (size_t i = 0; i < s.size(); i++) {
		if (s[i] == '%') {
			if (i + 2 >= s.size()) {
				return false;
			}
			int hi = hexVal(s[i + 1]);
			int lo = hexVal(s[i + 2]);
			if (hi < 0 || lo < 0) {
				return false;
			}
			out.push_back(static_cast<char>((hi << 4) | lo));
			i += 2;
		}
		else {
			out.push_back(s[i]);
		}
	}
	return true;
}

std::string hashStringHex16(const std::string& s) {
	// 64-bit FNV-1a + SplitMix64 finalizer for stable, collision-resistant cache keys.
	uint64_t h = 14695981039346656037ull;
	for (unsigned char c : s) {
		h ^= c;
		h *= 1099511628211ull;
	}
	h ^= h >> 30;
	h *= 0xbf58476d1ce4e5b9ull;
	h ^= h >> 27;
	h *= 0x94d049bb133111ebull;
	h ^= h >> 31;
	char buf[17];
	std::snprintf(buf, sizeof(buf), "%016llx", static_cast<unsigned long long>(h));
	return std::string(buf);
}

std::string sanitizeName(const std::string& raw) {
	std::string out;
	for (unsigned char c : raw) {
		if (std::isalnum(c) || c == '-' || c == '_') {
			out.push_back(static_cast<char>(c));
		}
		else {
			out.push_back('_');
		}
		if (out.size() >= 32) {
			break;
		}
	}
	while (!out.empty() && out.back() == '_') {
		out.pop_back();
	}
	return out.empty() ? "card" : out;
}

class ScopedFileLock {
public:
	explicit ScopedFileLock(const fs::path& lockPath) {
		fd_ = ::open(lockPath.c_str(), O_RDWR | O_CREAT, 0644);
		if (fd_ < 0) {
			error_ = "failed to open lock file " + lockPath.string() + ": " + std::strerror(errno);
			return;
		}
		while (::flock(fd_, LOCK_EX) != 0) {
			if (errno != EINTR) {
				error_ = "flock failed on " + lockPath.string() + ": " + std::strerror(errno);
				::close(fd_);
				fd_ = -1;
				return;
			}
		}
	}
	~ScopedFileLock() {
		if (fd_ >= 0) {
			::flock(fd_, LOCK_UN);
			::close(fd_);
		}
	}
	bool locked() const { return fd_ >= 0; }
	const std::string& error() const { return error_; }

private:
	int fd_ = -1;
	std::string error_;
};

// Recursively scan cardFolder, skipping macOS metadata and hidden dot-entries.
bool scanFolder(const fs::path& root, FolderScan& scan, std::string& errorOut) {
	scan = {};
	std::vector<std::pair<fs::path, std::string>> dirStack;
	dirStack.emplace_back(root, "");

	while (!dirStack.empty()) {
		auto [hostDir, relPrefix] = std::move(dirStack.back());
		dirStack.pop_back();

		std::error_code ec;
		size_t entriesInDir = 0;
		for (const auto& entry : fs::directory_iterator(hostDir, fs::directory_options::skip_permission_denied, ec)) {
			const std::string name = entry.path().filename().string();
			if (name.empty() || name[0] == '.') {
				continue; // skip .DS_Store, ._*, .Spotlight-V100, .Trashes, .git, etc.
			}
			struct stat st {};
			if (::stat(entry.path().c_str(), &st) != 0) {
				continue; // skip broken symlinks or transient entries
			}
			const std::string relPath = relPrefix.empty() ? name : (relPrefix + "/" + name);
			entriesInDir++;

			if (S_ISDIR(st.st_mode)) {
				// Do not follow directory symlinks to prevent cycles.
				std::error_code symEc;
				if (entry.is_symlink(symEc)) {
					continue;
				}
				scan.dirs.push_back(relPath);
				dirStack.emplace_back(entry.path(), relPath);
			}
			else if (S_ISREG(st.st_mode)) {
				FileEntry fe;
				fe.relPath = relPath;
				fe.size = static_cast<uint64_t>(st.st_size);
				fe.mtimeNs = statMtimeNs(st);
				scan.neededDataBytes += clustersForFileSize(fe.size) * kCardClusterBytes;
				scan.files.push_back(std::move(fe));
			}
		}
		if (ec) {
			errorOut = "failed to read directory " + hostDir.string() + ": " + ec.message();
			return false;
		}
		// Account for directory clusters (at least 1 cluster per directory, plus 1 per ~64 entries for LFN slots).
		scan.neededDataBytes += (1 + entriesInDir / 64) * kCardClusterBytes;
	}

	std::sort(scan.dirs.begin(), scan.dirs.end(), [](const std::string& a, const std::string& b) {
		size_t da = pathDepth(a);
		size_t db = pathDepth(b);
		return da != db ? da < db : a < b;
	});
	std::sort(scan.files.begin(), scan.files.end(),
	          [](const FileEntry& a, const FileEntry& b) { return a.relPath < b.relPath; });
	return true;
}

bool readManifest(const fs::path& manifestPath, Manifest& out) {
	out = {};
	std::ifstream in(manifestPath);
	if (!in) {
		return false;
	}
	std::string line;
	if (!std::getline(in, line) || line != kManifestHeader) {
		return false;
	}
	bool hasSource = false;
	bool hasImageBytes = false;
	bool hasImageIno = false;
	bool hasClusterBytes = false;

	while (std::getline(in, line)) {
		if (line.empty()) {
			continue;
		}
		if (line.rfind("source\t", 0) == 0) {
			if (!percentDecode(line.substr(7), out.source)) {
				return false;
			}
			hasSource = true;
			continue;
		}
		if (line.rfind("image_bytes\t", 0) == 0) {
			try {
				out.imageBytes = std::stoull(line.substr(12));
			}
			catch (...) {
				return false;
			}
			hasImageBytes = true;
			continue;
		}
		if (line.rfind("image_ino\t", 0) == 0) {
			try {
				out.imageIno = std::stoull(line.substr(10));
			}
			catch (...) {
				return false;
			}
			hasImageIno = true;
			continue;
		}
		if (line.rfind("cluster_bytes\t", 0) == 0) {
			try {
				out.clusterBytes = static_cast<uint32_t>(std::stoul(line.substr(14)));
			}
			catch (...) {
				return false;
			}
			hasClusterBytes = true;
			continue;
		}

		// Record lines: "<D|F>\t<size>\t<mtimeNs>\t<encodedPath>"
		size_t t1 = line.find('\t');
		size_t t2 = t1 == std::string::npos ? std::string::npos : line.find('\t', t1 + 1);
		size_t t3 = t2 == std::string::npos ? std::string::npos : line.find('\t', t2 + 1);
		if (t1 == std::string::npos || t2 == std::string::npos || t3 == std::string::npos) {
			return false;
		}
		const std::string kind = line.substr(0, t1);
		std::string relPath;
		if (!percentDecode(line.substr(t3 + 1), relPath)) {
			return false;
		}
		if (kind == "D") {
			out.dirs.insert(std::move(relPath));
		}
		else if (kind == "F") {
			FileEntry fe;
			fe.relPath = relPath;
			try {
				fe.size = std::stoull(line.substr(t1 + 1, t2 - t1 - 1));
				fe.mtimeNs = std::stoll(line.substr(t2 + 1, t3 - t2 - 1));
			}
			catch (...) {
				return false;
			}
			out.files.emplace(fe.relPath, std::move(fe));
		}
		else {
			return false;
		}
	}
	return hasSource && hasImageBytes && hasImageIno && hasClusterBytes;
}

bool writeManifestAtomic(const fs::path& manifestPath, const std::string& canonicalSource, uint64_t imageBytes,
                         uint64_t imageIno, const FolderScan& scan, std::string& errorOut) {
	fs::path tmpPath = manifestPath;
	tmpPath += ".tmp";

	int fd = ::open(tmpPath.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd < 0) {
		errorOut = "failed to create temp manifest: " + std::string(std::strerror(errno));
		return false;
	}

	std::ostringstream oss;
	oss << kManifestHeader << '\n';
	oss << "source\t" << percentEncode(canonicalSource) << '\n';
	oss << "image_bytes\t" << imageBytes << '\n';
	oss << "image_ino\t" << imageIno << '\n';
	oss << "cluster_bytes\t" << kCardClusterBytes << '\n';
	for (const auto& d : scan.dirs) {
		oss << "D\t0\t0\t" << percentEncode(d) << '\n';
	}
	for (const auto& f : scan.files) {
		oss << "F\t" << f.size << '\t' << f.mtimeNs << '\t' << percentEncode(f.relPath) << '\n';
	}
	const std::string data = oss.str();

	size_t written = 0;
	while (written < data.size()) {
		ssize_t n = ::write(fd, data.data() + written, data.size() - written);
		if (n < 0) {
			if (errno == EINTR) {
				continue;
			}
			errorOut = "failed writing temp manifest: " + std::string(std::strerror(errno));
			::close(fd);
			std::error_code ec;
			fs::remove(tmpPath, ec);
			return false;
		}
		written += static_cast<size_t>(n);
	}
	if (::fsync(fd) != 0) {
		errorOut = "fsync manifest failed: " + std::string(std::strerror(errno));
		::close(fd);
		std::error_code ec;
		fs::remove(tmpPath, ec);
		return false;
	}
	::close(fd);

	std::error_code ec;
	fs::rename(tmpPath, manifestPath, ec);
	if (ec) {
		errorOut = "failed renaming manifest: " + ec.message();
		fs::remove(tmpPath, ec);
		return false;
	}
	return true;
}

// Run a subprocess without a shell, capturing stdout and stderr separately so warnings on stderr never pollute
// structured stdout parsing (e.g. hdiutil attach device paths).
int runProcess(const std::vector<std::string>& args, std::string& stdoutOut, std::string& stderrOut) {
	stdoutOut.clear();
	stderrOut.clear();
	int outPipe[2] = {-1, -1};
	int errPipe[2] = {-1, -1};
	if (::pipe(outPipe) != 0) {
		stderrOut = std::string("pipe(stdout) failed: ") + std::strerror(errno);
		return -1;
	}
	if (::pipe(errPipe) != 0) {
		stderrOut = std::string("pipe(stderr) failed: ") + std::strerror(errno);
		::close(outPipe[0]);
		::close(outPipe[1]);
		return -1;
	}

	posix_spawn_file_actions_t actions;
	posix_spawn_file_actions_init(&actions);
	posix_spawn_file_actions_addclose(&actions, outPipe[0]);
	posix_spawn_file_actions_addclose(&actions, errPipe[0]);
	posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO);
	posix_spawn_file_actions_adddup2(&actions, errPipe[1], STDERR_FILENO);
	posix_spawn_file_actions_addclose(&actions, outPipe[1]);
	posix_spawn_file_actions_addclose(&actions, errPipe[1]);

	std::vector<char*> argv;
	argv.reserve(args.size() + 1);
	for (const auto& a : args) {
		argv.push_back(const_cast<char*>(a.c_str()));
	}
	argv.push_back(nullptr);

	pid_t pid = -1;
	int spawnErr = ::posix_spawnp(&pid, argv[0], &actions, nullptr, argv.data(), environ);
	posix_spawn_file_actions_destroy(&actions);
	::close(outPipe[1]);
	::close(errPipe[1]);

	if (spawnErr != 0) {
		::close(outPipe[0]);
		::close(errPipe[0]);
		stderrOut = std::string("posix_spawnp(") + args[0] + ") failed: " + std::strerror(spawnErr);
		return -1;
	}

	struct pollfd fds[2];
	fds[0].fd = outPipe[0];
	fds[0].events = POLLIN;
	fds[1].fd = errPipe[0];
	fds[1].events = POLLIN;
	int openCount = 2;
	char buf[4096];

	while (openCount > 0) {
		int pr = ::poll(fds, 2, -1);
		if (pr < 0) {
			if (errno == EINTR) {
				continue;
			}
			break;
		}
		for (int i = 0; i < 2; i++) {
			if (fds[i].fd < 0 || fds[i].revents == 0) {
				continue;
			}
			if (fds[i].revents & (POLLIN | POLLHUP | POLLERR)) {
				ssize_t n = ::read(fds[i].fd, buf, sizeof(buf));
				if (n > 0) {
					(i == 0 ? stdoutOut : stderrOut).append(buf, static_cast<size_t>(n));
				}
				else if (n == 0 || (n < 0 && errno != EINTR)) {
					::close(fds[i].fd);
					fds[i].fd = -1;
					openCount--;
				}
			}
		}
	}
	if (fds[0].fd >= 0) {
		::close(fds[0].fd);
	}
	if (fds[1].fd >= 0) {
		::close(fds[1].fd);
	}

	int status = 0;
	while (::waitpid(pid, &status, 0) < 0) {
		if (errno != EINTR) {
			return -1;
		}
	}
	if (WIFEXITED(status)) {
		return WEXITSTATUS(status);
	}
	return -1;
}

bool parseHdiutilDevice(const std::string& attachStdout, std::string& deviceOut) {
	// Parse stdout line by line: accept only a line-leading "/dev/disk<N>" token (followed by whitespace or EOL),
	// and explicitly refuse /dev/disk0 (the host boot disk).
	std::istringstream lines(attachStdout);
	std::string line;
	while (std::getline(lines, line)) {
		if (!line.empty() && line.back() == '\r') {
			line.pop_back();
		}
		if (line.rfind("/dev/disk", 0) != 0) {
			continue;
		}
		size_t end = 9;
		while (end < line.size() && std::isdigit(static_cast<unsigned char>(line[end]))) {
			end++;
		}
		if (end == 9) {
			continue;
		}
		if (end < line.size() && !std::isspace(static_cast<unsigned char>(line[end]))) {
			continue; // e.g. /dev/disk4s1 partition slice, not whole raw disk
		}
		unsigned long diskNum = 0;
		try {
			diskNum = std::stoul(line.substr(9, end - 9));
		}
		catch (...) {
			continue;
		}
		if (diskNum == 0) {
			return false; // never format /dev/disk0
		}
		deviceOut = line.substr(0, end);
		return true;
	}
	return false;
}

bool formatViaHdiutilDevice(const fs::path& imagePath, std::string& errorOut) {
	std::string attachOut;
	std::string attachErr;
	int rc = runProcess(
	    {"/usr/bin/hdiutil", "attach", "-imagekey", "diskimage-class=CRawDiskImage", "-nomount", imagePath.string()},
	    attachOut, attachErr);
	if (rc != 0) {
		errorOut = "hdiutil attach failed (exit " + std::to_string(rc) + "): " + attachOut + attachErr;
		return false;
	}
	std::string device;
	if (!parseHdiutilDevice(attachOut, device)) {
		errorOut = "hdiutil attach returned no safe /dev/diskN device (stdout: " + attachOut
		           + ", stderr: " + attachErr + ")";
		return false;
	}
	const std::string rawDevice = "/dev/rdisk" + device.substr(9);

	std::string fmtOut;
	std::string fmtErr;
	int fmtRc = runProcess({"/sbin/newfs_msdos", "-F", "32", "-c", "64", "-v", "DELUGE", rawDevice}, fmtOut, fmtErr);

	// Always detach, even when newfs_msdos failed.
	std::string detachOut;
	std::string detachErr;
	int detachRc = runProcess({"/usr/bin/hdiutil", "detach", device}, detachOut, detachErr);
	if (detachRc != 0) {
		std::string forceOut;
		std::string forceErr;
		int forceRc = runProcess({"/usr/bin/hdiutil", "detach", "-force", device}, forceOut, forceErr);
		if (forceRc != 0 && fmtRc == 0) {
			errorOut = "hdiutil detach failed for " + device + ": " + detachOut + detachErr + " / " + forceOut
			           + forceErr;
			return false;
		}
	}

	if (fmtRc != 0) {
		errorOut = "newfs_msdos on " + rawDevice + " failed (exit " + std::to_string(fmtRc) + "): " + fmtOut + fmtErr;
		return false;
	}
	return true;
}

bool formatFat32SparseImage(const fs::path& imagePath, uint64_t imageBytes, bool forceDeviceFormat,
                            std::string& errorOut) {
	// Create a sparse file of imageBytes first (newfs_msdos has no -C flag on macOS).
	int fd = ::open(imagePath.c_str(), O_RDWR | O_CREAT | O_TRUNC, 0644);
	if (fd < 0) {
		errorOut = "failed to create sparse image " + imagePath.string() + ": " + std::strerror(errno);
		return false;
	}
	if (::ftruncate(fd, static_cast<off_t>(imageBytes)) != 0) {
		errorOut = "ftruncate failed on " + imagePath.string() + ": " + std::strerror(errno);
		::close(fd);
		return false;
	}
	::close(fd);

	if (forceDeviceFormat) {
		return formatViaHdiutilDevice(imagePath, errorOut);
	}

	const uint64_t sectors = imageBytes / kCardSectorBytes;
	std::string out;
	std::string err;
	int rc = runProcess({"/sbin/newfs_msdos", "-F", "32", "-c", "64", "-S", "512", "-s", std::to_string(sectors),
	                     "-h", "255", "-u", "63", "-o", "0", "-v", "DELUGE", imagePath.string()},
	                    out, err);
	if (rc == 0) {
		return true;
	}
	const std::string combined = out + err;
	// macOS 26's newfs_msdos refuses plain files ("Cannot get partition offset"): fall back to hdiutil raw disk.
	if (combined.find("Cannot get partition offset") != std::string::npos
	    || combined.find("Inappropriate ioctl for device") != std::string::npos) {
		return formatViaHdiutilDevice(imagePath, errorOut);
	}
	errorOut = "newfs_msdos failed (exit " + std::to_string(rc) + "): " + combined;
	return false;
}

std::string fresultName(FRESULT r) {
	return "FRESULT(" + std::to_string(static_cast<int>(r)) + ")";
}

bool ensureFatParentDirs(const std::string& relPath, std::string& errorOut) {
	size_t pos = 0;
	while ((pos = relPath.find('/', pos)) != std::string::npos) {
		const std::string dir = relPath.substr(0, pos);
		if (!dir.empty()) {
			FRESULT r = f_mkdir(dir.c_str());
			if (r != FR_OK && r != FR_EXIST) {
				errorOut = "f_mkdir(" + dir + ") failed: " + fresultName(r);
				return false;
			}
		}
		pos++;
	}
	return true;
}

bool copyHostFileToFat(const fs::path& hostPath, const std::string& fatPath, std::vector<uint8_t>& buf,
                       bool& outDiskFull, std::string& errorOut) {
	outDiskFull = false;
	int srcFd = ::open(hostPath.c_str(), O_RDONLY);
	if (srcFd < 0) {
		errorOut = "failed to open source file " + hostPath.string() + ": " + std::strerror(errno);
		return false;
	}

	FIL fil;
	FRESULT res = f_open(&fil, fatPath.c_str(), FA_CREATE_ALWAYS | FA_WRITE);
	if (res == FR_NO_PATH) {
		if (!ensureFatParentDirs(fatPath, errorOut)) {
			::close(srcFd);
			return false;
		}
		res = f_open(&fil, fatPath.c_str(), FA_CREATE_ALWAYS | FA_WRITE);
	}
	if (res != FR_OK) {
		::close(srcFd);
		if (res == FR_DENIED) {
			outDiskFull = true;
		}
		errorOut = "f_open(" + fatPath + ") failed: " + fresultName(res);
		return false;
	}

	bool ok = true;
	for (;;) {
		ssize_t n = ::read(srcFd, buf.data(), buf.size());
		if (n < 0) {
			if (errno == EINTR) {
				continue;
			}
			errorOut = "read(" + hostPath.string() + ") failed: " + std::strerror(errno);
			ok = false;
			break;
		}
		if (n == 0) {
			break;
		}
		UINT bw = 0;
		FRESULT wres = f_write(&fil, buf.data(), static_cast<UINT>(n), &bw);
		if (wres != FR_OK || bw != static_cast<UINT>(n)) {
			if (wres == FR_OK && bw < static_cast<UINT>(n)) {
				outDiskFull = true;
				errorOut = "card image full while writing " + fatPath;
			}
			else {
				errorOut = "f_write(" + fatPath + ") failed: " + fresultName(wres);
			}
			ok = false;
			break;
		}
	}

	::close(srcFd);
	FRESULT cres = f_close(&fil);
	if (ok && cres != FR_OK) {
		errorOut = "f_close(" + fatPath + ") failed: " + fresultName(cres);
		return false;
	}
	return ok;
}

bool tryIncrementalRefresh(const fs::path& cardRoot, const std::string& canonicalSource, const fs::path& imagePath,
                           const fs::path& manifestPath, const Manifest& oldManifest, const FolderScan& scan,
                           const CardProgressFn& onProgress, bool& outNeedFullRebuild, CardImageResult& result) {
	outNeedFullRebuild = false;

	// Compute diff between oldManifest and scan.
	std::set<std::string> newDirSet(scan.dirs.begin(), scan.dirs.end());
	std::map<std::string, FileEntry> newFileMap;
	for (const auto& f : scan.files) {
		newFileMap.emplace(f.relPath, f);
	}

	std::vector<std::string> removedFiles;
	uint64_t freedClusters = 0;
	for (const auto& [path, oldEntry] : oldManifest.files) {
		if (newFileMap.find(path) == newFileMap.end()) {
			removedFiles.push_back(path);
			freedClusters += clustersForFileSize(oldEntry.size);
		}
	}

	std::vector<std::string> removedDirs;
	for (const auto& d : oldManifest.dirs) {
		if (newDirSet.find(d) == newDirSet.end()) {
			removedDirs.push_back(d);
		}
	}
	// Delete deepest directories first so parents are empty when unlinked.
	std::sort(removedDirs.begin(), removedDirs.end(), [](const std::string& a, const std::string& b) {
		size_t da = pathDepth(a);
		size_t db = pathDepth(b);
		return da != db ? da > db : a > b;
	});

	std::vector<std::string> addedDirs;
	for (const auto& d : scan.dirs) {
		if (oldManifest.dirs.find(d) == oldManifest.dirs.end()) {
			addedDirs.push_back(d);
		}
	}

	std::vector<FileEntry> upsertFiles;
	uint64_t upsertClusters = 0;
	for (const auto& f : scan.files) {
		auto it = oldManifest.files.find(f.relPath);
		if (it == oldManifest.files.end() || it->second.size != f.size || it->second.mtimeNs != f.mtimeNs) {
			if (it != oldManifest.files.end()) {
				freedClusters += clustersForFileSize(it->second.size);
			}
			upsertClusters += clustersForFileSize(f.size);
			upsertFiles.push_back(f);
		}
	}

	// Fast cache hit: nothing changed, don't even open the image for writing.
	if (removedFiles.empty() && removedDirs.empty() && addedDirs.empty() && upsertFiles.empty()) {
		if (onProgress) {
			onProgress(0, 0);
		}
		result.ok = true;
		result.imagePath = imagePath.string();
		result.manifestPath = manifestPath.string();
		result.imageBytes = oldManifest.imageBytes;
		result.clusterBytes = kCardClusterBytes;
		result.fullRebuild = false;
		result.totalFiles = static_cast<uint32_t>(scan.files.size());
		return true;
	}

	// Never mutate card.img in place: active readers hold card.img open O_RDONLY without build.lock, and an
	// interrupted refresh must leave the prior card.img and manifest intact. Clone to card.img.tmp (O(1) COW on APFS),
	// refresh the clone, fsync, then atomically rename over card.img.
	fs::path tmpImagePath = imagePath;
	tmpImagePath += ".tmp";
	auto cleanupTmp = [&]() {
		std::error_code rmEc;
		fs::remove(tmpImagePath, rmEc);
	};
	cleanupTmp();

#if defined(__APPLE__)
	if (::clonefile(imagePath.c_str(), tmpImagePath.c_str(), 0) != 0) {
		// On filesystems without COW cloning (ENOTSUP/EXDEV) or any clone failure, fall back cleanly to a full rebuild.
		cleanupTmp();
		outNeedFullRebuild = true;
		return false;
	}
#else
	outNeedFullRebuild = true;
	return false;
#endif

	{
		detail::ScopedDirectCardBuild buildScope(tmpImagePath.string());
		if (!buildScope.isOpen()) {
			cleanupTmp();
			outNeedFullRebuild = true;
			return false;
		}

		gBuilderFatFs = {};
		if (f_mount(&gBuilderFatFs, "", 1) != FR_OK || gBuilderFatFs.fs_type != FS_FAT32
		    || gBuilderFatFs.csize != kCardClusterSectors) {
			unmountFatVolume();
			cleanupTmp();
			outNeedFullRebuild = true;
			return false;
		}

		// Verify there is enough free space on the existing image for the incoming changes.
		DWORD freeClusters = 0;
		FATFS* fsPtr = nullptr;
		if (f_getfree("", &freeClusters, &fsPtr) != FR_OK) {
			unmountFatVolume();
			cleanupTmp();
			outNeedFullRebuild = true;
			return false;
		}
		const uint64_t requiredClusters = upsertClusters + static_cast<uint64_t>(addedDirs.size()) * 2 + 64;
		if (static_cast<uint64_t>(freeClusters) + freedClusters < requiredClusters) {
			unmountFatVolume();
			cleanupTmp();
			outNeedFullRebuild = true;
			return false;
		}

		const uint32_t totalWork = static_cast<uint32_t>(removedFiles.size() + upsertFiles.size());
		uint32_t doneWork = 0;
		if (onProgress) {
			onProgress(0, totalWork);
		}

		// 1. Delete removed files.
		for (const auto& rel : removedFiles) {
			FRESULT r = f_unlink(rel.c_str());
			if (r != FR_OK && r != FR_NO_FILE && r != FR_NO_PATH) {
				result.error = "f_unlink(" + rel + ") failed: " + fresultName(r);
				unmountFatVolume();
				cleanupTmp();
				return false;
			}
			result.filesRemoved++;
			doneWork++;
			if (onProgress) {
				onProgress(doneWork, totalWork);
			}
		}

		// 2. Delete removed directories (deepest-first).
		for (const auto& rel : removedDirs) {
			FRESULT r = f_unlink(rel.c_str());
			if (r == FR_OK) {
				result.dirsRemoved++;
			}
			else if (r != FR_NO_FILE && r != FR_NO_PATH) {
				// If a directory couldn't be removed cleanly, fall back to a clean full rebuild.
				unmountFatVolume();
				cleanupTmp();
				outNeedFullRebuild = true;
				return false;
			}
		}

		// 3. Create added directories (shallowest-first).
		for (const auto& rel : addedDirs) {
			FRESULT r = f_mkdir(rel.c_str());
			if (r == FR_OK) {
				result.dirsCreated++;
			}
			else if (r != FR_EXIST) {
				result.error = "f_mkdir(" + rel + ") failed: " + fresultName(r);
				unmountFatVolume();
				cleanupTmp();
				return false;
			}
		}

		// 4. Write added and modified files.
		std::vector<uint8_t> copyBuf(kCopyBufferBytes);
		for (const auto& f : upsertFiles) {
			bool diskFull = false;
			if (!copyHostFileToFat(cardRoot / f.relPath, f.relPath, copyBuf, diskFull, result.error)) {
				unmountFatVolume();
				cleanupTmp();
				if (diskFull) {
					result.error.clear();
					outNeedFullRebuild = true;
				}
				return false;
			}
			result.filesWritten++;
			doneWork++;
			if (onProgress) {
				onProgress(doneWork, totalWork);
			}
		}

		unmountFatVolume();
		if (!buildScope.sync()) {
			result.error = buildScope.error();
			cleanupTmp();
			return false;
		}
	}

	std::error_code renEc;
	fs::rename(tmpImagePath, imagePath, renEc);
	if (renEc) {
		result.error = "failed renaming refreshed card image: " + renEc.message();
		cleanupTmp();
		return false;
	}

	struct stat newImgSt {};
	if (::stat(imagePath.c_str(), &newImgSt) != 0) {
		result.error = "stat after refresh rename failed: " + std::string(std::strerror(errno));
		return false;
	}
	if (!writeManifestAtomic(manifestPath, canonicalSource, oldManifest.imageBytes,
	                         static_cast<uint64_t>(newImgSt.st_ino), scan, result.error)) {
		return false;
	}

	result.ok = true;
	result.imagePath = imagePath.string();
	result.manifestPath = manifestPath.string();
	result.imageBytes = oldManifest.imageBytes;
	result.clusterBytes = kCardClusterBytes;
	result.fullRebuild = false;
	result.totalFiles = static_cast<uint32_t>(scan.files.size());
	return true;
}

bool doFullRebuild(const fs::path& cardRoot, const std::string& canonicalSource, const fs::path& imagePath,
                   const fs::path& manifestPath, const FolderScan& scan, const CardImageOptions& options,
                   CardImageResult& result) {
	const uint64_t imageBytes = computeTargetImageBytes(scan.neededDataBytes);
	fs::path tmpImagePath = imagePath;
	tmpImagePath += ".tmp";

	auto cleanupTmp = [&]() {
		std::error_code ec;
		fs::remove(tmpImagePath, ec);
	};

	if (!formatFat32SparseImage(tmpImagePath, imageBytes, options.forceDeviceFormat, result.error)) {
		cleanupTmp();
		return false;
	}

	{
		detail::ScopedDirectCardBuild buildScope(tmpImagePath.string());
		if (!buildScope.isOpen()) {
			result.error = buildScope.error();
			cleanupTmp();
			return false;
		}

		gBuilderFatFs = {};
		FRESULT mres = f_mount(&gBuilderFatFs, "", 1);
		if (mres != FR_OK) {
			result.error = "f_mount on freshly formatted image failed: " + fresultName(mres);
			unmountFatVolume();
			cleanupTmp();
			return false;
		}
		if (gBuilderFatFs.fs_type != FS_FAT32 || gBuilderFatFs.csize != kCardClusterSectors) {
			result.error = "unexpected FAT geometry: fs_type=" + std::to_string(gBuilderFatFs.fs_type)
			               + " csize=" + std::to_string(gBuilderFatFs.csize);
			unmountFatVolume();
			cleanupTmp();
			return false;
		}

		const uint32_t totalWork = static_cast<uint32_t>(scan.files.size());
		uint32_t doneWork = 0;
		if (options.onProgress) {
			options.onProgress(0, totalWork);
		}

		for (const auto& d : scan.dirs) {
			FRESULT r = f_mkdir(d.c_str());
			if (r != FR_OK && r != FR_EXIST) {
				result.error = "f_mkdir(" + d + ") failed: " + fresultName(r);
				unmountFatVolume();
				cleanupTmp();
				return false;
			}
			result.dirsCreated++;
		}

		std::vector<uint8_t> copyBuf(kCopyBufferBytes);
		for (const auto& f : scan.files) {
			bool diskFull = false;
			if (!copyHostFileToFat(cardRoot / f.relPath, f.relPath, copyBuf, diskFull, result.error)) {
				unmountFatVolume();
				cleanupTmp();
				return false;
			}
			result.filesWritten++;
			doneWork++;
			if (options.onProgress) {
				options.onProgress(doneWork, totalWork);
			}
		}

		unmountFatVolume();
		if (!buildScope.sync()) {
			result.error = buildScope.error();
			cleanupTmp();
			return false;
		}
	}

	std::error_code ec;
	fs::rename(tmpImagePath, imagePath, ec);
	if (ec) {
		result.error = "failed renaming temp card image: " + ec.message();
		cleanupTmp();
		return false;
	}

	struct stat newImgSt {};
	if (::stat(imagePath.c_str(), &newImgSt) != 0) {
		result.error = "stat after rebuild rename failed: " + std::string(std::strerror(errno));
		return false;
	}
	if (!writeManifestAtomic(manifestPath, canonicalSource, imageBytes, static_cast<uint64_t>(newImgSt.st_ino), scan,
	                         result.error)) {
		return false;
	}

	result.ok = true;
	result.imagePath = imagePath.string();
	result.manifestPath = manifestPath.string();
	result.imageBytes = imageBytes;
	result.clusterBytes = kCardClusterBytes;
	result.fullRebuild = true;
	result.totalFiles = static_cast<uint32_t>(scan.files.size());
	return true;
}

} // namespace

std::string defaultCardCacheDir() {
	const char* home = std::getenv("HOME");
	if (home != nullptr && home[0] != '\0') {
		return std::string(home) + "/Library/Caches/deluge-engine/cards";
	}
	return "/tmp/deluge-engine-cards";
}

CardImageResult buildOrRefreshCardImage(const std::string& cardFolder, const CardImageOptions& options) {
	CardImageResult result;
	std::error_code ec;
	fs::path rootPath = fs::weakly_canonical(fs::path(cardFolder), ec);
	if (ec || !fs::exists(rootPath, ec) || !fs::is_directory(rootPath, ec)) {
		result.error = "card folder does not exist or is not a directory: " + cardFolder;
		return result;
	}
	const std::string canonicalSource = rootPath.string();

	const fs::path cacheRoot = options.cacheDir.empty() ? fs::path(defaultCardCacheDir()) : fs::path(options.cacheDir);
	const std::string entryName = sanitizeName(rootPath.filename().string()) + "-" + hashStringHex16(canonicalSource);
	const fs::path entryDir = cacheRoot / entryName;
	fs::create_directories(entryDir, ec);
	if (ec) {
		result.error = "failed to create card cache directory " + entryDir.string() + ": " + ec.message();
		return result;
	}

	// Serialize builders targeting the same cache entry across processes.
	ScopedFileLock lock(entryDir / "build.lock");
	if (!lock.locked()) {
		result.error = lock.error();
		return result;
	}

	// Scan inside build.lock so a process that waited on the lock never diffs a stale scan against a newer manifest.
	FolderScan scan;
	if (!scanFolder(rootPath, scan, result.error)) {
		return result;
	}

	const fs::path imagePath = entryDir / "card.img";
	const fs::path manifestPath = entryDir / "manifest.tsv";

	// Attempt incremental refresh when we have a matching cached image and manifest.
	if (!options.forceRebuild && !options.forceDeviceFormat && fs::is_regular_file(imagePath, ec)) {
		Manifest oldManifest;
		struct stat imgSt {};
		if (readManifest(manifestPath, oldManifest) && oldManifest.source == canonicalSource
		    && oldManifest.clusterBytes == kCardClusterBytes && ::stat(imagePath.c_str(), &imgSt) == 0
		    && static_cast<uint64_t>(imgSt.st_size) == oldManifest.imageBytes
		    && static_cast<uint64_t>(imgSt.st_ino) == oldManifest.imageIno) {
			bool needFullRebuild = false;
			if (tryIncrementalRefresh(rootPath, canonicalSource, imagePath, manifestPath, oldManifest, scan,
			                          options.onProgress, needFullRebuild, result)) {
				return result;
			}
			if (!needFullRebuild) {
				return result;
			}
			// Fall through to clean full rebuild (reset counters first).
			result = {};
		}
	}

	doFullRebuild(rootPath, canonicalSource, imagePath, manifestPath, scan, options, result);
	return result;
}

} // namespace deluge::engine::platform
