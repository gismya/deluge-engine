// Engine core implementation (E4, spec §3.7 & §3.9).
// Compiled in `engine_core_obj` with firmware headers and flags; exposes only the pure C++ API in `core/engine.h`.
#include "core/engine.h"

#include "OSLikeStuff/scheduler_api.h"
#include "OSLikeStuff/task_scheduler/task_scheduler.h"
#include "definitions_cxx.hpp"
#include "gui/ui/ui.h"
#include "gui/views/automation_view.h"
#include "gui/views/instrument_clip_view.h"
#include "gui/views/view.h"
#include "io/debug/print.h"
#include "io/midi/midi_device.h"
#include "io/midi/midi_device_manager.h"
#include "io/midi/midi_engine.h"
#include "io/midi/midi_follow.h"
#include "io/midi/test_port.h"
#include "model/action/action_logger.h"
#include "model/clip/instrument_clip.h"
#include "model/drum/drum.h"
#include "model/instrument/kit.h"
#include "model/model_stack.h"
#include "model/sample/sample.h"
#include "model/song/song.h"
#include "platform/card_image.h"
#include "platform/host_platform.h"
#include "processing/engines/audio_engine.h"
#include "storage/audio/audio_file_manager.h"
#include "storage/storage_manager.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <deque>
#include <string>
#include <thread>
#include <vector>

extern TaskManager taskManager;
extern bool sdRoutineLock;

namespace plat = deluge::engine::platform;

namespace deluge::engine::core {

namespace {

// Single-preset MIDI follow uses channel 16 (0-based 15), matching TestPort's `hold midi_setup` (spec §5).
constexpr uint8_t kSinglePresetFollowChannel = 15;
constexpr uint8_t kDefaultKitRootNote = 36;

bool startsWithCaseInsensitive(std::string_view s, std::string_view prefix) {
	if (s.size() < prefix.size()) {
		return false;
	}
	for (size_t i = 0; i < prefix.size(); ++i) {
		const unsigned char a = static_cast<unsigned char>(s[i]);
		const unsigned char b = static_cast<unsigned char>(prefix[i]);
		if (std::tolower(a) != std::tolower(b)) {
			return false;
		}
	}
	return true;
}

PresetKind resolvePresetKind(std::string_view cardPath, PresetKind kind) {
	if (kind != PresetKind::Auto) {
		return kind;
	}
	while (!cardPath.empty() && cardPath.front() == '/') {
		cardPath.remove_prefix(1);
	}
	return startsWithCaseInsensitive(cardPath, "KITS/") ? PresetKind::Kit : PresetKind::Synth;
}

// Frees AudioFiles no longer referenced by any loaded preset (matching perform_song.cpp's deleteUnusedAudioFiles),
// preventing unbounded metadata growth across repeated preset swaps.
void deleteUnusedAudioFiles() {
	AudioFileVector& files = audioFileManager.audioFiles;
	for (int32_t i = files.getNumElements() - 1; i >= 0; --i) {
		auto* audioFile = static_cast<AudioFile*>(files.getElement(i));
		const bool tempRecording = audioFile->type == AudioFileType::SAMPLE
		                           && !static_cast<Sample*>(audioFile)->tempFilePathForRecording.isEmpty();
		if (audioFile->numReasonsToBeLoaded == 0 && !tempRecording) {
			audioFileManager.deleteUnusedAudioFileFromMemory(*audioFile, i);
		}
	}
}

void configureSinglePresetMidiFollow() {
	for (int32_t c = 0; c < kNumGlobalMIDICommands; ++c) {
		midiEngine.globalMIDICommands[c].clear();
	}
	for (auto& ch : midiEngine.midiFollowChannelType) {
		ch.clear();
	}
	LearnedMIDI& followA = midiEngine.midiFollowChannelType[util::to_underlying(MIDIFollowChannelType::A)];
	followA.cable = nullptr; // match any cable
	followA.channelOrZone = kSinglePresetFollowChannel;
	midiEngine.midiFollowKitRootNote = kDefaultKitRootNote;
	midiEngine.midiFollowFeedbackChannelType = MIDIFollowFeedbackChannelType::NONE;
	midiEngine.midiFollowFeedbackAutomation = MIDIFollowFeedbackAutomationMode::DISABLED;
	midiEngine.midiFollowFeedbackFilter = false;
}

struct ScheduledTestLine {
	double atVirtualSeconds = 0.0;
	size_t seq = 0;
	std::string line;
};

// Host MIDICable attached to Debug::midiDebugCable and passed to TestPort::injectReceived() (spec §3.7).
// Captures TestPort status replies synchronously and forwards TestPort event frames to callbacks.onTestEvent
// without consuming DIN UART TX buffer space.
class HostTestCable final : public MIDICable {
public:
	HostTestCable() { connectionFlags = 1; }

	void setEventHandler(std::function<void(std::string_view)> handler) { onEvent_ = std::move(handler); }

	void clearLastStatus() {
		hasStatus_ = false;
		lastStatus_ = TestPort::Status::ParseError;
	}
	bool hasLastStatus() const { return hasStatus_; }
	TestPort::Status lastStatus() const { return lastStatus_; }

	void writeToFlash(uint8_t*) override {}
	char const* getDisplayName() override { return "HostTestPort"; }
	void sendMessage(MIDIMessage) override {}
	size_t sendBufferSpace() const override { return 1024; }

	void sendSysex(const uint8_t* data, int32_t len) override {
		if (data == nullptr || len < 9 || data[0] != 0xF0 || data[len - 1] != 0xF7) {
			return;
		}
		// Header: F0 00 21 7B 01 <cmd> <subcmd> ... F7
		if (data[1] != 0x00 || data[2] != 0x21 || data[3] != 0x7B || data[4] != 0x01) {
			return;
		}
		// TestPort inject status reply: F0 00 21 7B 01 02 50 <seq> <status> F7
		if (len == 10 && data[5] == 0x02 && data[6] == TestPort::kStatusReply) {
			lastStatus_ = static_cast<TestPort::Status>(data[8]);
			hasStatus_ = true;
			return;
		}
		// TestPort event line: F0 00 21 7B 01 03 40 01 <ascii>[\n] F7
		if (len >= 9 && data[5] == 0x03 && data[6] == 0x40 && data[7] == TestPort::kEventCategory) {
			size_t textLen = static_cast<size_t>(len - 9);
			const char* text = reinterpret_cast<const char*>(data + 8);
			while (textLen > 0 && (text[textLen - 1] == '\n' || text[textLen - 1] == '\r')) {
				--textLen;
			}
			if (onEvent_) {
				onEvent_(std::string_view(text, textLen));
			}
		}
	}

protected:
	void writeReferenceAttributesToFile(Serializer&) override {}

private:
	std::function<void(std::string_view)> onEvent_;
	bool hasStatus_ = false;
	TestPort::Status lastStatus_ = TestPort::Status::ParseError;
};

} // namespace

struct Engine::Impl {
	bool booted = false;
	bool midiFollowAnyChannel = true;
	Callbacks callbacks;
	std::string loadedPresetPath;
	std::string cardImagePath;

	HostTestCable testCable;
	uint8_t testSeq = 0;
	std::vector<ScheduledTestLine> scheduledLines;
	size_t nextScheduledIdx = 0;
	size_t nextScheduleOrder = 0;

	// Frame capture state during render(). Any frames produced past the requested render() target in a
	// scheduler step are queued in pendingFrames and returned first on the next render() call.
	bool captureActive = false;
	int32_t* captureBuf = nullptr;
	size_t captureTarget = 0;
	size_t captureWritten = 0;
	std::deque<int32_t> pendingFrames; // interleaved L, R samples (2 * frames)
	uint64_t totalFramesRendered = 0;

	int32_t lastReportedVoices = -1;
	int32_t peakVoices = 0;

	void reportError(std::string_view msg) {
		if (callbacks.onError) {
			callbacks.onError(msg);
		}
	}

	void onAudioFrame(const int32_t* frame) {
		if (!captureActive) {
			return;
		}
		if (captureWritten < captureTarget) {
			if (captureBuf != nullptr) {
				captureBuf[captureWritten * 2 + 0] = frame[0];
				captureBuf[captureWritten * 2 + 1] = frame[1];
			}
			++captureWritten;
			++totalFramesRendered;
		}
		else {
			pendingFrames.push_back(frame[0]);
			pendingFrames.push_back(frame[1]);
		}
	}

	void updateVoiceCount() {
		const int32_t voices = AudioEngine::getNumVoices();
		if (voices > peakVoices) {
			peakVoices = voices;
		}
		if (voices != lastReportedVoices) {
			lastReportedVoices = voices;
			if (callbacks.onVoiceCount) {
				callbacks.onVoiceCount(voices);
			}
		}
	}

	TestLineStatus injectLineNow(std::string_view line) {
		if (!booted) {
			return TestLineStatus::NotBooted;
		}
		std::vector<uint8_t> data;
		data.reserve(line.size() + 4);
		data.push_back(0x02);
		data.push_back(TestPort::kInjectCommand);
		data.push_back(static_cast<uint8_t>(++testSeq & 0x7Fu));
		data.insert(data.end(), line.begin(), line.end());
		data.push_back(0xF7);

		testCable.clearLastStatus();
		TestPort::injectReceived(testCable, data.data(), static_cast<int32_t>(data.size()));

		if (!testCable.hasLastStatus()) {
			reportError("TestPort::injectReceived produced no status reply");
			return TestLineStatus::ParseError;
		}
		switch (testCable.lastStatus()) {
		case TestPort::Status::Queued:
			return TestLineStatus::Queued;
		case TestPort::Status::QueueFull:
			return TestLineStatus::QueueFull;
		case TestPort::Status::ParseError:
			reportError("TestPort rejected line (parse error): " + std::string(line));
			return TestLineStatus::ParseError;
		case TestPort::Status::BadKey:
			reportError("TestPort rejected line (bad key)");
			return TestLineStatus::BadKey;
		}
		return TestLineStatus::ParseError;
	}

	void injectDueScheduledLines() {
		const double now = plat::virtualSeconds();
		while (nextScheduledIdx < scheduledLines.size() && scheduledLines[nextScheduledIdx].atVirtualSeconds <= now) {
			const TestLineStatus st = injectLineNow(scheduledLines[nextScheduledIdx].line);
			if (st == TestLineStatus::QueueFull) {
				// Retry on the next scheduler turn once the test-port queue has room.
				break;
			}
			++nextScheduledIdx;
		}
	}
	static Impl* active;
	static bool firmwareBootedInProcess;

	static void audioSink(const int32_t* frame) {
		if (active != nullptr) {
			active->onAudioFrame(frame);
		}
	}

	static void freezeBridge(const char* code, const char* loaded, const char* backtrace) {
		if (active != nullptr && active->callbacks.onFreeze) {
			active->callbacks.onFreeze(code != nullptr ? code : "UNKNOWN", loaded != nullptr ? loaded : "none",
			                           backtrace != nullptr ? backtrace : "");
		}
	}
};

Engine::Impl* Engine::Impl::active = nullptr;
bool Engine::Impl::firmwareBootedInProcess = false;

Engine::Engine() : impl_(std::make_unique<Impl>()) {}

Engine::~Engine() {
	if (Impl::active == impl_.get()) {
		plat::setAudioSink(nullptr);
		plat::setFreezeCallback(nullptr);
		Debug::midiDebugCable = nullptr;
		Impl::active = nullptr;
	}
}

bool Engine::boot(const Config& config, std::string* errorOut) {
	if (impl_->booted || Impl::firmwareBootedInProcess) {
		const std::string msg = "firmware is already booted in this process (one Engine per process)";
		if (errorOut != nullptr) {
			*errorOut = msg;
		}
		return false;
	}

	impl_->callbacks = config.callbacks;
	impl_->testCable.setEventHandler([this](std::string_view ev) {
		if (impl_->callbacks.onTestEvent) {
			impl_->callbacks.onTestEvent(ev);
		}
	});

	// 1. Build or refresh the card image on a dedicated thread before booting the firmware (spec §3.6).
	if (!config.cardFolder.empty()) {
		plat::CardImageOptions opts;
		opts.cacheDir = config.cardCacheDir;
		opts.onProgress = config.onCardProgress;
		plat::CardImageResult built;
		std::thread builder([&]() { built = plat::buildOrRefreshCardImage(config.cardFolder, opts); });
		builder.join();
		if (!built.ok) {
			const std::string msg = "card image build failed: " + built.error;
			if (errorOut != nullptr) {
				*errorOut = msg;
			}
			impl_->reportError(msg);
			return false;
		}
		if (!plat::openCardImage(built.imagePath)) {
			const std::string msg = "failed to open card image: " + built.imagePath;
			if (errorOut != nullptr) {
				*errorOut = msg;
			}
			impl_->reportError(msg);
			return false;
		}
		impl_->cardImagePath = built.imagePath;
	}
	else if (!config.cardImagePath.empty()) {
		if (!plat::openCardImage(config.cardImagePath)) {
			const std::string msg = "failed to open card image: " + config.cardImagePath;
			if (errorOut != nullptr) {
				*errorOut = msg;
			}
			impl_->reportError(msg);
			return false;
		}
		impl_->cardImagePath = config.cardImagePath;
	}
	else {
		impl_->cardImagePath = plat::cardImagePath();
	}

	// 2. Configure platform layer before booting firmware.
	if (config.stealableBudgetBytes > 0) {
		plat::setStealableBudget(config.stealableBudgetBytes);
	}
	if (config.cardReadModel) {
		plat::setCardReadTimingUs(plat::kDefaultCardReadCommandUs, plat::kDefaultCardReadSectorUs);
	}
	else {
		plat::setCardReadTimingUs(0.0, 0.0);
	}
	plat::clearDinMidi();
	plat::resetClock();

	Impl::active = impl_.get();
	plat::setFreezeLoadedContext("boot");
	plat::setFreezeCallback(&Impl::freezeBridge);

	// 3. Boot firmware headless, attach DMA sink and scheduler clock.
	plat::bootFirmware();
	plat::resetDma();
	plat::setAudioSink(&Impl::audioSink);
	plat::setDmaFollowsClock(true);
	plat::setPace(config.pace);

	// Initialize TaskManager's monotonic clock once without entering its infinite loop.
	(void)taskManager.getSecondsFromStart();

	// 4. Attach TestPort host sink and single-preset MIDI follow routing.
	Debug::midiDebugCable = &impl_->testCable;
	configureSinglePresetMidiFollow();

	plat::setFreezeLoadedContext("blank");
	impl_->booted = true;
	Impl::firmwareBootedInProcess = true;
	impl_->updateVoiceCount();
	return true;
}

bool Engine::isBooted() const {
	return impl_->booted;
}

PresetLoadResult Engine::loadPreset(std::string_view cardPath, PresetKind kind) {
	PresetLoadResult result;
	result.path = std::string(cardPath);

	if (!impl_->booted) {
		result.error = "engine is not booted";
		impl_->reportError(result.error);
		return result;
	}
	if (cardPath.empty()) {
		result.error = "preset path must not be empty";
		impl_->reportError(result.error);
		return result;
	}
	if (sdRoutineLock) {
		result.error = "cannot load preset while SD routine lock is held";
		impl_->reportError(result.error);
		return result;
	}

	const PresetKind resolvedKind = resolvePresetKind(cardPath, kind);
	result.kind = resolvedKind;
	const OutputType outputType = (resolvedKind == PresetKind::Kit) ? OutputType::KIT : OutputType::SYNTH;

	const std::string pathStr(cardPath);
	const std::string previousContext = impl_->loadedPresetPath;
	plat::setFreezeLoadedContext(pathStr.c_str());

	FilePointer fp;
	if (!StorageManager::fileExists(pathStr.c_str(), &fp)) {
		plat::setFreezeLoadedContext(previousContext.empty() ? "blank" : previousContext.c_str());
		result.error = "preset not found on card image: " + pathStr;
		impl_->reportError(result.error);
		return result;
	}

	InstrumentClip* clip = getCurrentInstrumentClip();
	Instrument* old = clip != nullptr ? static_cast<Instrument*>(clip->output) : nullptr;
	if (clip == nullptr || old == nullptr || (old->type != OutputType::SYNTH && old->type != OutputType::KIT)) {
		plat::setFreezeLoadedContext(previousContext.empty() ? "blank" : previousContext.c_str());
		result.error = "current clip is not a Synth or Kit clip";
		impl_->reportError(result.error);
		return result;
	}

	// Split folder and stem (without extension), matching TestPort::loadPreset() and perform_song.cpp.
	const char* slash = std::strrchr(pathStr.c_str(), '/');
	const char* file = slash != nullptr ? slash + 1 : pathStr.c_str();
	const char* dot = std::strrchr(file, '.');
	String dirPath;
	String presetName;
	dirPath.set(pathStr.c_str(), slash != nullptr ? static_cast<int32_t>(slash - pathStr.c_str()) : 0);
	presetName.set(file, dot != nullptr ? static_cast<int32_t>(dot - file) : -1);

	Instrument* loaded = nullptr;
	Error error = StorageManager::loadInstrumentFromFile(currentSong, nullptr, outputType, false, &loaded, &fp,
	                                                     &presetName, &dirPath);
	if (error == Error::NONE && loaded != nullptr) {
		error = loaded->loadAllAudioFiles(true);
		if (error != Error::NONE) {
			loaded->prepareForHibernationOrDeletion();
			currentSong->deleteOutput(loaded);
			loaded = nullptr;
		}
	}
	if (error != Error::NONE || loaded == nullptr) {
		plat::setFreezeLoadedContext(previousContext.empty() ? "blank" : previousContext.c_str());
		result.error = "failed to load preset " + pathStr + " (firmware error " + std::to_string(static_cast<int>(error))
		               + ")";
		impl_->reportError(result.error);
		return result;
	}

	// Ensure old instrument is deleted rather than added to hibernation list so repeated swaps free all RAM.
	old->editedByUser = false;
	midiFollow.removeClip(clip);
	actionLogger.deleteAllLogs();

	char modelStackMemory[MODEL_STACK_MAX_SIZE];
	ModelStackWithTimelineCounter* modelStack = setupModelStackWithTimelineCounter(modelStackMemory, currentSong, clip);
	currentSong->replaceInstrument(old, loaded);
	if (outputType == OutputType::KIT) {
		clip->ensureScrollWithinKitBounds();
		static_cast<Kit*>(loaded)->selectedDrum = nullptr;
	}
	view.instrumentChanged(modelStack, loaded);
	currentSong->ensureAllInstrumentsHaveAClipOrBackedUpParamManager("E058", "H058");

	RootUI* root = getRootUI();
	if (root == &instrumentClipView || root == &automationView) {
		instrumentClipView.recalculateColours();
	}

	deleteUnusedAudioFiles();

	// Drop any tiny leftover frames captured before the swap so the next render() starts cleanly on the new preset.
	impl_->pendingFrames.clear();
	impl_->loadedPresetPath = pathStr;

	if (outputType == OutputType::KIT) {
		int32_t drums = 0;
		for (Drum* d = static_cast<Kit*>(loaded)->firstDrum; d != nullptr; d = d->next) {
			++drums;
		}
		result.drumCount = drums;
	}

	impl_->updateVoiceCount();
	result.ok = true;
	return result;
}

bool Engine::midi(const uint8_t* bytes, size_t len) {
	if (!impl_->booted) {
		return false;
	}
	if (len == 0) {
		return true;
	}
	if (bytes == nullptr) {
		return false;
	}
	if (!impl_->midiFollowAnyChannel) {
		return plat::injectDinMidi(bytes, len);
	}

	// In single-preset MIDI-follow mode, route channel voice messages (0x80..0xEF) on any MIDI channel 1..16
	// to MIDI follow channel A so the firmware's own MIDI parser and MidiFollow route them (spec §5).
	uint8_t stackBuf[64];
	std::vector<uint8_t> heapBuf;
	uint8_t* dst = stackBuf;
	if (len > sizeof(stackBuf)) {
		heapBuf.resize(len);
		dst = heapBuf.data();
	}
	for (size_t i = 0; i < len; ++i) {
		uint8_t b = bytes[i];
		if ((b & 0x80u) != 0 && (b & 0xF0u) != 0xF0u) {
			b = static_cast<uint8_t>((b & 0xF0u) | kSinglePresetFollowChannel);
		}
		dst[i] = b;
	}
	return plat::injectDinMidi(dst, len);
}

bool Engine::midi(std::initializer_list<uint8_t> bytes) {
	return midi(bytes.begin(), bytes.size());
}

void Engine::setMidiFollowAnyChannel(bool enable) {
	impl_->midiFollowAnyChannel = enable;
}

bool Engine::midiFollowAnyChannel() const {
	return impl_->midiFollowAnyChannel;
}

TestLineStatus Engine::testLine(std::string_view line) {
	return impl_->injectLineNow(line);
}

void Engine::scheduleTestLine(double atVirtualSeconds, std::string line) {
	ScheduledTestLine entry;
	entry.atVirtualSeconds = atVirtualSeconds;
	entry.seq = impl_->nextScheduleOrder++;
	entry.line = std::move(line);
	// Insert keeping unprocessed suffix stably sorted by (atVirtualSeconds, seq).
	auto begin = impl_->scheduledLines.begin() + static_cast<std::ptrdiff_t>(impl_->nextScheduledIdx);
	auto pos = std::upper_bound(begin, impl_->scheduledLines.end(), entry,
	                            [](const ScheduledTestLine& a, const ScheduledTestLine& b) {
		                            if (a.atVirtualSeconds != b.atVirtualSeconds) {
			                            return a.atVirtualSeconds < b.atVirtualSeconds;
		                            }
		                            return a.seq < b.seq;
	                            });
	impl_->scheduledLines.insert(pos, std::move(entry));
}

void Engine::clearScheduledTestLines() {
	impl_->scheduledLines.clear();
	impl_->nextScheduledIdx = 0;
}

size_t Engine::render(int32_t* interleavedOut, size_t frames) {
	if (!impl_->booted || frames == 0) {
		return 0;
	}

	size_t written = 0;
	while (written < frames && impl_->pendingFrames.size() >= 2) {
		const int32_t l = impl_->pendingFrames.front();
		impl_->pendingFrames.pop_front();
		const int32_t r = impl_->pendingFrames.front();
		impl_->pendingFrames.pop_front();
		if (interleavedOut != nullptr) {
			interleavedOut[written * 2 + 0] = l;
			interleavedOut[written * 2 + 1] = r;
		}
		++written;
		++impl_->totalFramesRendered;
	}

	if (written >= frames) {
		return written;
	}

	impl_->captureBuf = interleavedOut;
	impl_->captureTarget = frames;
	impl_->captureWritten = written;
	impl_->captureActive = true;

	while (impl_->captureWritten < impl_->captureTarget) {
		impl_->injectDueScheduledLines();

		(void)taskManager.getSecondsFromStart();
		const TaskID task = taskManager.chooseBestTask(Time(-1));
		if (task >= 0) {
			taskManager.runTask(task);
		}
		else {
			(void)taskManager.checkConditionalTasks();
			taskManager.runHighestPriTask();
		}

		impl_->updateVoiceCount();
	}

	impl_->captureActive = false;
	impl_->captureBuf = nullptr;
	return impl_->captureWritten;
}

void Engine::setCallbacks(Callbacks callbacks) {
	impl_->callbacks = std::move(callbacks);
}

double Engine::virtualSeconds() const {
	return plat::virtualSeconds();
}

uint64_t Engine::totalFramesRendered() const {
	return impl_->totalFramesRendered;
}

uint64_t Engine::dmaOverruns() const {
	return plat::dmaOverruns();
}

int32_t Engine::voiceCount() const {
	if (!impl_->booted) {
		return 0;
	}
	return AudioEngine::getNumVoices();
}

int32_t Engine::peakVoiceCount() const {
	return impl_->peakVoices;
}

void Engine::resetPeakVoiceCount() {
	impl_->peakVoices = voiceCount();
}

size_t Engine::stealableBytesUsed() const {
	return plat::stealableBytesUsed();
}

std::string Engine::loadedPresetPath() const {
	return impl_->loadedPresetPath;
}

std::string Engine::cardImagePath() const {
	return impl_->cardImagePath;
}

} // namespace deluge::engine::core
