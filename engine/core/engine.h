// Single-threaded, deterministic Engine API (E4, spec §3.7 & §3.9).
//
// Pure C++ header: includes neither firmware headers nor protobuf headers, so front ends that link protobuf/RTTI
// (e.g. `deluge-engine`) can call Engine without inheriting the firmware target's `-fno-rtti`, `-ffast-math`, or
// `host_prefix.h` macros.
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <initializer_list>
#include <memory>
#include <string>
#include <string_view>

namespace deluge::engine::core {

constexpr uint32_t kSampleRate = 44100;
constexpr uint32_t kChannels = 2;

enum class PresetKind {
	Auto, // inferred from path ("KITS/..." case-insensitively -> Kit, else Synth)
	Synth,
	Kit,
};

struct Callbacks {
	// Called on firmware freeze right before _Exit(70).
	std::function<void(std::string_view code, std::string_view loaded, std::string_view backtrace)> onFreeze;
	// Called on recoverable Engine errors (preset load failure, test-port parse/queue error, etc.).
	std::function<void(std::string_view message)> onError;
	// Called when the firmware emits a TestPort event line (trailing newline stripped).
	std::function<void(std::string_view event)> onTestEvent;
	// Called during render() whenever the active voice count changes.
	std::function<void(int32_t voices)> onVoiceCount;
};

struct Config {
	std::string cardFolder;    // Card folder to build/refresh into a cached FAT32 image (if non-empty)
	std::string cardImagePath; // Pre-built FAT32 card image (used if cardFolder is empty; else DELUGE_SD_IMAGE)
	std::string cardCacheDir;  // Optional cache directory override for buildOrRefreshCardImage()
	double pace = 0.0;         // Virtual clock pace (0 = offline free-running, 1 = real time)
	size_t stealableBudgetBytes = 0; // 0 = platform default (1 GiB)
	bool cardReadModel = true;       // true = 300 us + 40 us/sector (spec §3.6); false = instant
	Callbacks callbacks;
	std::function<void(uint32_t done, uint32_t total)> onCardProgress;
};

struct PresetLoadResult {
	bool ok = false;
	std::string error;
	PresetKind kind = PresetKind::Synth;
	std::string path;
	int32_t drumCount = 0; // for Kits: number of drums in the loaded Kit
};

enum class TestLineStatus {
	Queued,
	QueueFull,
	ParseError,
	BadKey,
	NotBooted,
};

class Engine {
public:
	Engine();
	~Engine();

	Engine(const Engine&) = delete;
	Engine& operator=(const Engine&) = delete;

	// Builds/refreshes the card image on a dedicated thread (if cardFolder is set), opens it read-only,
	// boots the firmware headless, configures MIDI follow for single-preset routing, and attaches the
	// TestPort event sink and freeze callback.
	// Only one booted Engine may exist per process (the firmware is all globals).
	bool boot(const Config& config, std::string* errorOut = nullptr);
	bool isBooted() const;

	// Loads a Synth or Kit preset from the card image, swapping cleanly if another preset is already loaded.
	// On failure, invokes callbacks.onError and leaves any previously loaded preset intact.
	PresetLoadResult loadPreset(std::string_view cardPath, PresetKind kind = PresetKind::Auto);

	// Feeds raw MIDI bytes into the DIN UART stand-in so the firmware's own MIDI parser handles them (spec §3.7).
	// When midiFollowAnyChannel() is true (default for single-preset mode), channel voice status bytes are routed
	// to the MIDI follow channel so any MIDI channel 1..16 plays the loaded preset (spec §5).
	bool midi(const uint8_t* bytes, size_t len);
	bool midi(std::initializer_list<uint8_t> bytes);

	void setMidiFollowAnyChannel(bool enable);
	bool midiFollowAnyChannel() const;

	// Injects one text line directly into TestPort::injectReceived() immediately (spec §3.7).
	TestLineStatus testLine(std::string_view line);

	// Schedules a test-port line to be injected deterministically during render() once virtualSeconds() >= atVirtualSeconds.
	void scheduleTestLine(double atVirtualSeconds, std::string line);
	void clearScheduledTestLines();

	// Advances the firmware scheduler until `frames` stereo int32 frames (2 * frames int32_t samples) have been
	// produced into `interleavedOut` (or discarded when `interleavedOut == nullptr`).
	size_t render(int32_t* interleavedOut, size_t frames);

	void setCallbacks(Callbacks callbacks);

	// Inspection & metrics
	double virtualSeconds() const;
	uint64_t totalFramesRendered() const;
	uint64_t dmaOverruns() const;
	int32_t voiceCount() const;
	int32_t peakVoiceCount() const;
	void resetPeakVoiceCount();
	std::string loadedPresetPath() const;
	std::string cardImagePath() const;

private:
	struct Impl;
	std::unique_ptr<Impl> impl_;
};

} // namespace deluge::engine::core
