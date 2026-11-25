// Spike driver (issue #42): a Setup built in memory. Boots the firmware headless on the virtual clock with its own
// scheduler (as perform_engine does), then a host task in that scheduler follows a script of timed lines: load a
// preset, give it an always-active session clip in the current song and bind its MIDI input to a channel; swap or
// remove a binding; and MIDI notes, which go in through the DIN UART stand-in so the firmware's own parser and
// PlaybackHandler::noteMessageReceived() route them. Every frame the "DMA" plays from boot goes to the WAV.
//
// usage: DELUGE_SD_IMAGE=card.img setup_engine --script FILE --out out.wav [--card-us C:S] [--midi-during-load]
//
// Script lines, "T command args", T in virtual seconds since boot, channels 1-16:
//   T bind CH PATH [LOWNOTE]  load SYNTHS/... or KITS/... (by folder), link it with a clip, input on CH. A Kit's
//                             LOWNOTE (default 36) is the note of its first row, as a whole-Kit MIDI learn sets it.
//   T swap CH PATH            the preset browser's way: load PATH, Song::replaceInstrument(old, new). The binding
//                             moves with it; old voices stop.
//   T swapx CH PATH           load PATH beside the old one, link it, move the binding to it, release the old one's
//                             notes, and free the old one 2 s later
//   T unbind CH               remove the instrument and its clip from the song
//   T on CH NOTE [VEL]        MIDI note-on through the DIN stand-in (VEL default 100)
//   T off CH NOTE             MIDI note-off
//   T end                     write the WAV and exit
#include "OSLikeStuff/scheduler_api.h"
#include "definitions_cxx.hpp"
#include "gui/ui/ui.h"
#include "gui/ui_timer_manager.h"
#include "gui/views/view.h"
#include "hid/display/display.h"
#include "hid/display/oled.h"
#include "hid/display/screensaver.h"
#include "hid/encoders.h"
#include "io/midi/midi_device_manager.h"
#include "io/midi/midi_engine.h"
#include "io/midi/midi_follow.h"
#include "memory/general_memory_allocator.h"
#include "model/clip/instrument_clip.h"
#include "model/instrument/kit.h"
#include "model/instrument/melodic_instrument.h"
#include "model/model_stack.h"
#include "model/settings/runtime_feature_settings.h"
#include "model/song/song.h"
#include "playback/mode/playback_mode.h"
#include "playback/mode/session.h"
#include "processing/engines/audio_engine.h"
#include "processing/sound/sound_instrument.h"
#include "storage/audio/audio_file_manager.h"
#include "storage/flash_storage.h"
#include "storage/storage_manager.h"
#include "util/functions.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

extern "C" {
extern bool host_virtual_clock;
extern uint64_t host_virtual_ticks;
extern bool host_dma_follows_clock;
extern void (*host_audio_sink)(const int32_t* frame);
extern uint64_t host_dma_frames;
extern uint64_t host_dma_overruns;
extern uint32_t host_card_ticks_per_command, host_card_ticks_per_sector;
bool host_midi_inject(const uint8_t* bytes, uint32_t n);
}
void setupBlankSong();
void inputRoutine();
void registerTasks();
extern bool sdRoutineLock;

namespace {

class HostDisplay final : public deluge::hid::display::OLED {
public:
	void freezeWithError(char const* text) override {
		std::fprintf(stderr, "FREEZE_WITH_ERROR %s at %.3f s virtual\n", text, host_virtual_ticks / DELUGE_CLOCKS_PERf);
		std::fflush(stderr);
		std::abort();
	}
};

std::vector<int32_t> audio; // every frame the DMA played since boot, L R interleaved
void sink(const int32_t* frame) {
	if (audio.size() < (size_t)kSampleRate * 2 * 600) {
		audio.push_back(frame[0]);
		audio.push_back(frame[1]);
	}
}

double virtualNow() {
	return host_virtual_ticks / DELUGE_CLOCKS_PERf;
}
auto wallStart = std::chrono::steady_clock::now();
double wallNow() {
	return std::chrono::duration<double>(std::chrono::steady_clock::now() - wallStart).count();
}

const char* outPath = nullptr;
bool midiDuringLoad = false; // --midi-during-load: note lines may run while a bind or swap is loading
bool inCommand = false;      // a bind, swap, unbind or free is running (and may have yielded back to the scheduler)

void writeWav(const char* path, const int32_t* frames, size_t samples) {
	FILE* f = std::fopen(path, "wb");
	uint32_t dataBytes = samples * 4;
	auto u32 = [&](uint32_t v) { std::fwrite(&v, 4, 1, f); };
	auto u16 = [&](uint16_t v) { std::fwrite(&v, 2, 1, f); };
	std::fwrite("RIFF", 1, 4, f);
	u32(36 + dataBytes);
	std::fwrite("WAVEfmt ", 1, 8, f);
	u32(16);
	u16(1);
	u16(2);
	u32(kSampleRate);
	u32(kSampleRate * 8);
	u16(8);
	u16(32);
	std::fwrite("data", 1, 4, f);
	u32(dataBytes);
	std::fwrite(frames, 4, samples, f);
	std::fclose(f);
}

// ---- The Setup: one instrument and clip per channel, in the current song.

struct Binding {
	Instrument* instrument = nullptr;
	InstrumentClip* clip = nullptr;
	std::string path;
};
Binding bindings[16];
struct Retiring {
	Instrument* instrument;
	InstrumentClip* clip;
	double freeAt;
};
std::vector<Retiring> retiring;

// An empty, always-active, 1-bar session clip for `instrument`, both linked into `song`, as the firmware's
// Generative mode builds its parts (generative/firmware/perform_song.cpp link()) and SessionView makes a new clip.
InstrumentClip* linkIntoSong(Song* song, Instrument* instrument) {
	void* memory = GeneralMemoryAllocator::get().allocMaxSpeed(sizeof(InstrumentClip));
	auto* clip = new (memory) InstrumentClip(song);
	clip->loopLength = song->getBarLength();
	clip->activeIfNoSolo = true;
	if (clip->setAudioInstrument(instrument, song, true, nullptr) != Error::NONE) {
		return nullptr;
	}
	char modelStackMemory[MODEL_STACK_MAX_SIZE];
	ModelStackWithTimelineCounter* modelStack =
	    setupModelStackWithSong(modelStackMemory, song)->addTimelineCounter(clip);
	if (instrument->type == OutputType::KIT) {
		clip->setupAsNewKitClipIfNecessary(modelStack); // one NoteRow per drum
	}
	song->sessionClips.insertClipAtIndex(clip, song->sessionClips.getNumElements());
	song->addOutput(instrument, false);
	instrument->setActiveClip(modelStack);
	return clip;
}

// Removes the clip and its Output from the song, in the stock order (SessionView::removeClip()).
void unlinkAndDelete(Song* song, Instrument* instrument, InstrumentClip* clip) {
	char modelStackMemory[MODEL_STACK_MAX_SIZE];
	ModelStack* modelStack = setupModelStackWithSong(modelStackMemory, song);
	instrument->stopAnyAuditioning(modelStack);
	clip->stopAllNotesPlaying(modelStack->addTimelineCounter(clip));
	if (view.instrumentPressedForMIDILearn == instrument) {
		view.instrumentPressedForMIDILearn = nullptr;
	}
	midiFollow.removeClip(clip);
	if (song->getCurrentClip() == clip) {
		song->setCurrentClip(nullptr);
	}
	instrument->midiInput.clear();
	const int32_t index = song->sessionClips.getIndexForClip(clip);
	if (index >= 0) {
		song->removeSessionClipLowLevel(clip, index);
	}
	song->deleteClipObject(clip, false, InstrumentRemoval::DELETE);
	AudioEngine::mustUpdateReverbParamsBeforeNextRender = true;
}

Instrument* loadPreset(const char* path, InstrumentClip* clip) {
	FilePointer fp;
	if (!StorageManager::fileExists(path, &fp)) {
		std::fprintf(stderr, "preset not found on card image: %s\n", path);
		return nullptr;
	}
	String name;
	String dir;
	const char* slash = std::strrchr(path, '/');
	name.set(slash ? slash + 1 : path);
	dir.set(path, slash ? (int)(slash - path) : 0);
	Instrument* instrument = nullptr;
	const OutputType type = std::strncmp(path, "KITS/", 5) == 0 ? OutputType::KIT : OutputType::SYNTH;
	Error error = StorageManager::loadInstrumentFromFile(currentSong, clip, type, true, &instrument, &fp, &name, &dir);
	if (error != Error::NONE || instrument == nullptr) {
		std::fprintf(stderr, "loadInstrumentFromFile %s failed: error %d\n", path, (int)error);
		return nullptr;
	}
	return instrument;
}

void bindInput(Instrument* instrument, int ch, int lowNote) {
	instrument->midiInput.clear();
	instrument->midiInput.cable = nullptr; // any input: DIN, USB or (later) a host port
	instrument->midiInput.channelOrZone = ch - 1;
	instrument->midiInput.noteOrCC = instrument->type == OutputType::KIT ? lowNote : 255;
}

// ---- Script

struct Line {
	double at;
	std::string cmd;
	int ch = 0;
	std::string path;
	int a = -1, b = -1;
};
std::vector<Line> script;
size_t nextLine = 0;

void readScript(const char* path) {
	FILE* f = std::fopen(path, "r");
	if (!f) {
		std::perror(path);
		std::exit(2);
	}
	char buf[512];
	while (std::fgets(buf, sizeof(buf), f)) {
		std::string s(buf);
		while (!s.empty() && (s.back() == '\n' || s.back() == '\r')) {
			s.pop_back();
		}
		if (s.empty() || s[0] == '#') {
			continue;
		}
		Line l;
		char cmd[32];
		int n = 0;
		if (std::sscanf(s.c_str(), "%lf %31s %d%n", &l.at, cmd, &l.ch, &n) < 2) {
			continue;
		}
		l.cmd = cmd;
		std::string rest = n ? s.substr(n) : "";
		while (!rest.empty() && rest[0] == ' ') {
			rest.erase(0, 1);
		}
		if (l.cmd == "bind" || l.cmd == "swap" || l.cmd == "swapx") {
			// PATH may contain spaces; an optional trailing number after ".XML" is the Kit's low note.
			size_t dot = rest.find(".XML");
			l.path = dot == std::string::npos ? rest : rest.substr(0, dot + 4);
			if (dot != std::string::npos && dot + 4 < rest.size()) {
				l.a = std::atoi(rest.c_str() + dot + 4);
			}
		}
		else if (l.cmd == "on" || l.cmd == "off") {
			std::sscanf(rest.c_str(), "%d %d", &l.a, &l.b);
		}
		script.push_back(l);
	}
	std::fclose(f);
	std::stable_sort(script.begin(), script.end(), [](const Line& x, const Line& y) { return x.at < y.at; });
}

void finish(const char* why) {
	if (outPath) {
		writeWav(outPath, audio.data(), audio.size());
	}
	std::fprintf(stderr, "end (%s): virtual %.3f s, wall %.2f s, DMA overruns %llu, frames %zu%s%s\n", why,
	             virtualNow(), wallNow(), (unsigned long long)host_dma_overruns, audio.size() / 2,
	             outPath ? ", wrote " : "", outPath ? outPath : "");
	std::fflush(stderr);
	std::_Exit(0);
}

// Each command logs: when it ran, how much virtual time and wall time it took, the frames the DMA played meanwhile
// (audio kept running) and the DMA overruns it caused (audio stopped).
struct Timing {
	double v0, w0;
	uint64_t frames0, overruns0;
};
Timing startTiming() {
	return {virtualNow(), wallNow(), host_dma_frames, host_dma_overruns};
}
void logTiming(const Timing& t, const char* what) {
	std::fprintf(stderr, "  %s: at %.4f s took %.1f ms virtual, %.1f ms wall; DMA played %llu frames meanwhile, %llu "
	                     "overruns\n",
	             what, t.v0, (virtualNow() - t.v0) * 1000, (wallNow() - t.w0) * 1000,
	             (unsigned long long)(host_dma_frames - t.frames0),
	             (unsigned long long)(host_dma_overruns - t.overruns0));
}

int countOutputs() {
	int n = 0;
	for (Output* o = currentSong->firstOutput; o; o = o->next) {
		n++;
	}
	return n;
}

void run(const Line& l) {
	char what[600];
	const int ch = l.ch;
	if (l.cmd == "on" || l.cmd == "off") {
		uint8_t msg[3] = {uint8_t((l.cmd == "on" ? 0x90 : 0x80) | ((ch - 1) & 15)), uint8_t(l.a),
		                  uint8_t(l.cmd == "on" ? (l.b >= 0 ? l.b : 100) : 64)};
		host_midi_inject(msg, 3);
		std::fprintf(stderr, "  %s ch %d note %d at %.4f s\n", l.cmd.c_str(), ch, l.a, virtualNow());
		return;
	}
	if (l.cmd == "end") {
		finish("script end");
	}
	if (ch < 1 || ch > 16) {
		std::fprintf(stderr, "bad channel in %s\n", l.cmd.c_str());
		std::exit(2);
	}
	Binding& b = bindings[ch - 1];
	Timing t = startTiming();
	if (l.cmd == "bind") {
		Instrument* instrument = loadPreset(l.path.c_str(), nullptr);
		if (!instrument) {
			std::exit(1);
		}
		InstrumentClip* clip = linkIntoSong(currentSong, instrument);
		if (!clip) {
			std::fprintf(stderr, "linking %s failed\n", l.path.c_str());
			std::exit(1);
		}
		bindInput(instrument, ch, l.a >= 0 ? l.a : 36);
		b = {instrument, clip, l.path};
		snprintf(what, sizeof(what), "bind ch %d %s (outputs now %d)", ch, l.path.c_str(), countOutputs());
	}
	else if (l.cmd == "swap") {
		// As LoadInstrumentPresetUI does when the clip is its instrument's only one (load_instrument_preset_ui.cpp
		// :941-985): load with the clip, then replace the whole instrument. replaceInstrument() moves midiInput.
		Instrument* fresh = loadPreset(l.path.c_str(), b.clip);
		if (!fresh) {
			std::exit(1);
		}
		currentSong->replaceInstrument(b.instrument, fresh);
		b.instrument = fresh;
		b.path = l.path;
		snprintf(what, sizeof(what), "swap ch %d -> %s (input ch %d, outputs now %d)", ch, l.path.c_str(),
		              fresh->midiInput.channelOrZone + 1, countOutputs());
	}
	else if (l.cmd == "swapx") {
		Instrument* fresh = loadPreset(l.path.c_str(), nullptr);
		if (!fresh) {
			std::exit(1);
		}
		InstrumentClip* clip = linkIntoSong(currentSong, fresh);
		fresh->midiInput = b.instrument->midiInput;
		b.instrument->midiInput.clear();
		// The old one's held notes get a note-off now (release tail), as a note-off on its channel would give them.
		char modelStackMemory[MODEL_STACK_MAX_SIZE];
		b.instrument->stopAnyAuditioning(setupModelStackWithSong(modelStackMemory, currentSong));
		retiring.push_back({b.instrument, b.clip, virtualNow() + 2.0});
		b = {fresh, clip, l.path};
		snprintf(what, sizeof(what), "swapx ch %d -> %s (outputs now %d)", ch, l.path.c_str(), countOutputs());
	}
	else if (l.cmd == "unbind") {
		unlinkAndDelete(currentSong, b.instrument, b.clip);
		b = {};
		snprintf(what, sizeof(what), "unbind ch %d (outputs now %d)", ch, countOutputs());
	}
	else {
		std::fprintf(stderr, "unknown command %s\n", l.cmd.c_str());
		std::exit(2);
	}
	logTiming(t, what);
}

int32_t lastVoices = 0;

void hostTask() {
	const double v = virtualNow();
	const int32_t voices = (int32_t)AudioEngine::getNumVoices();
	if (voices != lastVoices) {
		std::fprintf(stderr, "  voices %d at %.4f s\n", voices, v);
		lastVoices = voices;
	}
	for (auto it = retiring.begin(); it != retiring.end() && !inCommand;) {
		if (v >= it->freeAt) {
			Retiring r = *it;
			it = retiring.erase(it);
			Timing t = startTiming();
			inCommand = true;
			unlinkAndDelete(currentSong, r.instrument, r.clip);
			inCommand = false;
			logTiming(t, "free retired instrument");
			it = retiring.begin();
		}
		else {
			++it;
		}
	}
	// A load yields to the scheduler while it waits for the card (host_diskio.c), and the scheduler runs this task
	// again from inside it. Lines wait for the command in progress to end, except notes with --midi-during-load,
	// which then reach the firmware's MIDI task while the load is still going (as notes from a keyboard would).
	while (nextLine < script.size() && script[nextLine].at <= v) {
		const std::string& c = script[nextLine].cmd;
		const bool note = c == "on" || c == "off";
		if (inCommand && !(note && midiDuringLoad)) {
			return;
		}
		// Loads read the card: not while the card routine is part-way through (test_port.cpp:793 waits the same way).
		if (sdRoutineLock && !note && c != "end") {
			return;
		}
		const Line& line = script[nextLine++];
		if (note) {
			run(line);
			continue;
		}
		inCommand = true;
		run(line);
		inCommand = false;
	}
	if (v > 600) {
		finish("600 s");
	}
}

} // namespace

int main(int argc, char** argv) {
	for (int i = 1; i < argc; i++) {
		auto arg = [&](const char* name) { return std::strcmp(argv[i], name) == 0 && i + 1 < argc; };
		if (arg("--script")) {
			readScript(argv[++i]);
		}
		else if (arg("--out")) {
			outPath = argv[++i];
		}
		else if (std::strcmp(argv[i], "--midi-during-load") == 0) {
			midiDuringLoad = true;
		}
		else if (arg("--card-us")) {
			double command = 0, sector = 0;
			std::sscanf(argv[++i], "%lf:%lf", &command, &sector);
			host_card_ticks_per_command = (uint32_t)(command * DELUGE_CLOCKS_PERf / 1e6);
			host_card_ticks_per_sector = (uint32_t)(sector * DELUGE_CLOCKS_PERf / 1e6);
		}
		else {
			std::fprintf(stderr, "unknown argument %s\n", argv[i]);
			return 2;
		}
	}
	setvbuf(stderr, nullptr, _IOLBF, 0);
	host_virtual_clock = true;
	host_dma_follows_clock = true;
	host_audio_sink = sink;
	audio.reserve((size_t)kSampleRate * 2 * 30);

	// deluge_main() without the hardware (spec §3.3's host init list), as perform_engine
	functionsInit();
	currentPlaybackMode = &session;
	deluge::hid::display::have_oled_screen = true;
	display = new HostDisplay;
	deluge::hid::encoders::init();
	AudioEngine::init();
	audioFileManager.init();
	FlashStorage::readSettings();
	runtimeFeatureSettings.init();
	runtimeFeatureSettings.readSettingsFromFile();
	MIDIDeviceManager::readDevicesFromFile();
	midiFollow.readDefaultsFromFile();
	setupBlankSong();
	inputRoutine();
	uiTimerManager.setTimer(TimerName::GRAPHICS_ROUTINE, 50);
	sdRoutineLock = false;
	deluge::hid::display::Screensaver::settingsChanged();
	std::fprintf(stderr, "booted at %.3f s virtual, %llu DMA overruns so far; blank song has %d outputs; follow A channel %d\n", virtualNow(),
	             (unsigned long long)host_dma_overruns, countOutputs(),
	             midiEngine.midiFollowChannelType[util::to_underlying(MIDIFollowChannelType::A)].channelOrZone);

	registerTasks();
	addRepeatingTask(hostTask, 35, 0.001, 0.001, 0.002, "host", RESOURCE_NONE);
	startTaskManager();
	return 0;
}
