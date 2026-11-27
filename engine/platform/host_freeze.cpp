// Host freeze handling (spec §3.5): FREEZE_WITH_ERROR and display->freezeWithError report the error code, what was
// loaded, and a backtrace, then exit with status 70. Never busy-waits on the PIC or timer registers.
#include "hid/display/oled.h"
#include "model/song/song.h"
#include "platform/host_platform.h"
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <execinfo.h>

namespace {

constexpr size_t kLoadedBufSize = 512;
constexpr size_t kBacktraceBufSize = 8192;
constexpr int kMaxFrames = 64;

char gLoadedContext[kLoadedBufSize] = {};
deluge::engine::platform::FreezeCallbackFn gFreezeCallback = nullptr;
std::atomic<bool> gInFreeze{false};

class HostDisplay final : public deluge::hid::display::OLED {
public:
	void freezeWithError(char const* text) override { deluge::engine::platform::handleFreeze(text); }
};

const char* resolveLoadedContext() {
	if (gLoadedContext[0] != '\0') {
		return gLoadedContext;
	}
	if (currentSong != nullptr && currentSong->name.getLength() > 0) {
		return currentSong->name.get();
	}
	return "none";
}

void formatBacktrace(char* out, size_t outSize) {
	void* frames[kMaxFrames];
	const int count = backtrace(frames, kMaxFrames);
	char** symbols = backtrace_symbols(frames, count);
	size_t pos = 0;
	for (int i = 0; i < count && pos + 1 < outSize; i++) {
		int written = 0;
		if (symbols != nullptr && symbols[i] != nullptr) {
			written = snprintf(out + pos, outSize - pos, "  %s\n", symbols[i]);
		}
		else {
			written = snprintf(out + pos, outSize - pos, "  %p\n", frames[i]);
		}
		if (written <= 0) {
			break;
		}
		const size_t step = static_cast<size_t>(written);
		pos += step < (outSize - pos) ? step : (outSize - pos - 1);
	}
	out[pos] = '\0';
	std::free(symbols);
}

} // namespace

namespace deluge::engine::platform {

void setFreezeLoadedContext(const char* loaded) {
	if (loaded == nullptr) {
		gLoadedContext[0] = '\0';
		return;
	}
	snprintf(gLoadedContext, sizeof(gLoadedContext), "%s", loaded);
}

const char* freezeLoadedContext() {
	return gLoadedContext;
}

void setFreezeCallback(FreezeCallbackFn cb) {
	gFreezeCallback = cb;
}

[[noreturn]] void handleFreeze(const char* code) {
	const char* safeCode = code != nullptr ? code : "UNKNOWN";
	if (gInFreeze.exchange(true)) {
		std::fprintf(stderr, "FREEZE_WITH_ERROR %s (re-entrant)\n", safeCode);
		std::fflush(stderr);
		std::_Exit(kFreezeExitCode);
	}

	const char* loaded = resolveLoadedContext();
	char bt[kBacktraceBufSize];
	formatBacktrace(bt, sizeof(bt));

	std::fprintf(stderr, "FREEZE_WITH_ERROR %s\nloaded: %s\nvirtual_time: %.6f s\nbacktrace:\n%s", safeCode, loaded,
	             virtualSeconds(), bt);
	std::fflush(stderr);

	if (gFreezeCallback != nullptr) {
		gFreezeCallback(safeCode, loaded, bt);
	}
	std::fflush(nullptr);
	std::_Exit(kFreezeExitCode);
}

deluge::hid::Display* createHostDisplay() {
	return new HostDisplay();
}

} // namespace deluge::engine::platform
