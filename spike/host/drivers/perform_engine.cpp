// Spike driver: the firmware booted headless and run by its own scheduler (registerTasks + taskManager) on a virtual
// clock, with the DIN MIDI port bridged to UDP so the sysex test port (ENABLE_SYSEX_TEST) and the firmware's probe
// scripts drive it as they drive delugemu. Records what the "DMA" plays and writes the audio from the moment
// playback starts to a WAV.
//
// usage: DELUGE_SD_IMAGE=card.img perform_engine [--udp LISTEN:SEND] [--pace F] [--ticks-per-read N]
//                                               [--seconds S] [--play-seconds S] [--out out.wav]
//   --udp           the probe's ports (deluge_probe.py --udp LISTEN:SEND): the Engine binds SEND, sends to LISTEN
//   --card-us C:S   model card reads: C us per read command plus S us per 512-byte sector (default instant)
//   --inject FILE   test-port lines called in directly at fixed virtual times ("T line"; see readInjections())
//   --free-after-play  stop pacing once playback starts
//   --pace F        hold virtual time to F x the wall clock (1 = real time); 0, the default, runs free
//   --seconds       stop after this much virtual time in all (default 600)
//   --play-seconds  stop this long (virtual) after playback starts (default 60)
#include "OSLikeStuff/scheduler_api.h"
#include "OSLikeStuff/task_scheduler/task_scheduler.h"
#include "definitions_cxx.hpp"
#include "gui/ui/root_ui.h"
#include "gui/ui/ui.h"
#include "gui/ui_timer_manager.h"
#include "hid/display/display.h"
#include "hid/display/oled.h"
#include "hid/display/screensaver.h"
#include "hid/encoders.h"
#include "model/settings/runtime_feature_settings.h"
#include "io/midi/midi_device_manager.h"
#include "io/debug/print.h"
#include "io/midi/test_port.h"
#include "io/midi/midi_follow.h"
#include "playback/mode/playback_mode.h"
#include "playback/mode/session.h"
#include "playback/playback_handler.h"
#include "processing/engines/audio_engine.h"
#include "storage/audio/audio_file_manager.h"
#include "storage/flash_storage.h"
#include "util/functions.h"
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

extern "C" {
extern bool host_virtual_clock;
extern uint32_t host_ticks_per_read;
extern double host_pace;
extern uint64_t host_virtual_ticks;
extern bool host_dma_follows_clock;
extern void (*host_audio_sink)(const int32_t* frame);
extern uint64_t host_dma_frames;
extern uint64_t host_dma_overruns;
extern uint64_t host_midi_bytes_in, host_midi_bytes_out;
extern bool host_midi_print_events;
extern uint32_t host_card_ticks_per_command, host_card_ticks_per_sector;
bool host_midi_udp_open(int probeListen, int probeSend);
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
bool keepAudio = false;
void sink(const int32_t* frame) {
	// Only for --out, and at most 20 minutes: a long script run (thousands of virtual seconds) would not fit.
	if (keepAudio && audio.size() < (size_t)kSampleRate * 2 * 1200) {
		audio.push_back(frame[0]);
		audio.push_back(frame[1]);
	}
}

// --inject FILE: test-port lines handed straight to TestPort::injectReceived(), no MIDI, each at a fixed virtual
// time ("T line", or a bare line for T = 0.5 s). The firmware's own "wait" lines space them, so a run repeats exactly.
struct Injection {
	double at;
	std::string line;
};
std::vector<Injection> injections;
size_t nextInjection = 0;

void readInjections(const char* path) {
	FILE* f = std::fopen(path, "r");
	if (!f) {
		std::perror(path);
		std::exit(2);
	}
	char buf[256];
	while (std::fgets(buf, sizeof(buf), f)) {
		std::string line(buf);
		while (!line.empty() && (line.back() == '\n' || line.back() == '\r')) {
			line.pop_back();
		}
		if (line.empty() || line[0] == '#') {
			continue;
		}
		double at = 0.5;
		char* end;
		double t = std::strtod(line.c_str(), &end);
		if (end != line.c_str() && *end == ' ') {
			at = t;
			line = std::string(end + 1);
		}
		injections.push_back({at, line});
	}
	std::fclose(f);
}

void injectDue(double v) {
#if ENABLE_SYSEX_TEST
	static uint8_t seq = 0;
	while (nextInjection < injections.size() && injections[nextInjection].at <= v) {
		const std::string& line = injections[nextInjection++].line;
		// The payload as HIDSysex::sysexReceived() hands it on: HID command, inject command, sequence, text, F7.
		std::vector<uint8_t> data{0x02, TestPort::kInjectCommand, uint8_t(++seq & 0x7F)};
		data.insert(data.end(), line.begin(), line.end());
		data.push_back(0xF7);
		TestPort::injectReceived(MIDIDeviceManager::dinMIDIPorts, data.data(), (int32_t)data.size());
		std::fprintf(stderr, "  inject at %.3f s: %s\n", v, line.c_str());
	}
#else
	(void)v;
#endif
}

double maxSeconds = 600;
bool freeAfterPlay = false; // --free-after-play: stop pacing once playback starts (the scripts are done by then)
double playSeconds = 60;
const char* outPath = nullptr;
auto wallStart = std::chrono::steady_clock::now();

double virtualNow() {
	return host_virtual_ticks / DELUGE_CLOCKS_PERf;
}
double wallNow() {
	return std::chrono::duration<double>(std::chrono::steady_clock::now() - wallStart).count();
}

bool started = false;
uint64_t playStartFrame = 0;
double playStartVirtual = 0, playStartWall = 0;
// Freeze watch while playing: the OLED (it shows the beat) unchanged for how long at most.
uint32_t lastOledHash = 0;
double lastOledChange = 0, longestOledStill = 0;
int32_t maxVoices = 0;
double nextReport = 5;

uint32_t oledHash() {
	uint32_t h = 2166136261u;
	const uint8_t* p = deluge::hid::display::OLED::oledCurrentImage[0];
	for (int i = 0; i < 768; i++) {
		h = (h ^ p[i]) * 16777619u;
	}
	return h;
}

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

void finish(const char* why) {
	const double v = virtualNow(), w = wallNow();
	size_t from = started ? playStartFrame * 2 : 0;
	size_t samples = audio.size() > from ? audio.size() - from : 0;
	int32_t peak = 0;
	double sum = 0;
	size_t silentHalfSeconds = 0, halves = 0;
	const size_t half = kSampleRate; // samples (L+R) in half a second
	for (size_t i = from; i + half <= audio.size(); i += half, halves++) {
		int32_t hp = 0;
		for (size_t j = i; j < i + half; j++) {
			hp = std::max(hp, std::abs(audio[j]));
		}
		silentHalfSeconds += hp == 0;
	}
	for (size_t i = from; i < audio.size(); i++) {
		peak = std::max(peak, std::abs(audio[i]));
		sum += (double)audio[i] * audio[i];
	}
	double rms = samples ? std::sqrt(sum / samples) : 0;
	if (outPath && samples) {
		writeWav(outPath, audio.data() + from, samples);
	}
	std::fprintf(stderr,
	             "end (%s): virtual %.2f s, wall %.2f s; played %.2f s virtual in %.2f s wall (%.1fx real time)\n", why,
	             v, w, started ? v - playStartVirtual : 0.0, started ? w - playStartWall : 0.0,
	             started && w > playStartWall ? (v - playStartVirtual) / (w - playStartWall) : 0.0);
	std::fprintf(stderr,
	             "audio from play: %.2f s, peak %.1f dBFS, rms %.1f dBFS, silent half-seconds %zu of %zu; "
	             "DMA overruns %llu; longest OLED still while playing %.2f s; max voices %d; midi in %llu out %llu\n",
	             samples / 2.0 / kSampleRate, peak ? 20 * std::log10(peak / 2147483648.0) : -999.0,
	             rms > 0 ? 20 * std::log10(rms / 2147483648.0) : -999.0, silentHalfSeconds, halves,
	             (unsigned long long)host_dma_overruns, longestOledStill, maxVoices,
	             (unsigned long long)host_midi_bytes_in, (unsigned long long)host_midi_bytes_out);
	if (outPath && samples) {
		std::fprintf(stderr, "wrote %s\n", outPath);
	}
	std::fflush(stderr);
	std::_Exit(0);
}

// A host task in the firmware's scheduler: notices playback starting, watches the OLED and ends the run.
void hostTask() {
	const double v = virtualNow();
	injectDue(v);
	const bool playing = playbackHandler.isEitherClockActive();
	if (playing && !started) {
		started = true;
		playStartFrame = host_dma_frames;
		playStartVirtual = v;
		playStartWall = wallNow();
		lastOledChange = v;
		std::fprintf(stderr, "playback started at %.3f s virtual (%.2f s wall)\n", v, playStartWall);
		if (freeAfterPlay) {
			host_pace = 0;
		}
	}
	if (started && playing) {
		uint32_t h = oledHash();
		if (h != lastOledHash) {
			lastOledHash = h;
			lastOledChange = v;
		}
		longestOledStill = std::max(longestOledStill, v - lastOledChange);
		maxVoices = std::max(maxVoices, (int32_t)AudioEngine::getNumVoices());
	}
	if (v >= nextReport) {
		nextReport += 5;
		UI* ui = getCurrentUI();
		RootUI* root = getRootUI();
		std::fprintf(stderr,
		             "  t=%.1f s virtual, %.1f s wall, ui=%s root=%s playing=%d voices=%d direness=%d overruns=%llu\n",
		             v, wallNow(), ui ? ui->getUIName() : "none", root ? root->getUIName() : "none", playing,
		             (int)AudioEngine::getNumVoices(), (int)AudioEngine::cpuDireness,
		             (unsigned long long)host_dma_overruns);
	}
	if (started && v - playStartVirtual >= playSeconds) {
		finish("played --play-seconds");
	}
	if (v >= maxSeconds) {
		finish("--seconds reached");
	}
}

} // namespace

int main(int argc, char** argv) {
	int udpListen = 0, udpSend = 0;
	for (int i = 1; i < argc; i++) {
		auto arg = [&](const char* name) { return std::strcmp(argv[i], name) == 0 && i + 1 < argc; };
		if (arg("--udp")) {
			std::sscanf(argv[++i], "%d:%d", &udpListen, &udpSend);
		}
		else if (arg("--pace")) {
			host_pace = std::atof(argv[++i]);
		}
		else if (arg("--ticks-per-read")) {
			host_ticks_per_read = std::atoi(argv[++i]);
		}
		else if (arg("--seconds")) {
			maxSeconds = std::atof(argv[++i]);
		}
		else if (arg("--play-seconds")) {
			playSeconds = std::atof(argv[++i]);
		}
		else if (std::strcmp(argv[i], "--free-after-play") == 0) {
			freeAfterPlay = true;
		}
		else if (arg("--card-us")) {
			// "COMMAND:SECTOR" microseconds of modelled card transfer time, e.g. 300:20
			double command = 0, sector = 0;
			std::sscanf(argv[++i], "%lf:%lf", &command, &sector);
			host_card_ticks_per_command = (uint32_t)(command * DELUGE_CLOCKS_PERf / 1e6);
			host_card_ticks_per_sector = (uint32_t)(sector * DELUGE_CLOCKS_PERf / 1e6);
		}
		else if (arg("--inject")) {
			readInjections(argv[++i]);
		}
		else if (arg("--out")) {
			outPath = argv[++i];
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
	keepAudio = outPath != nullptr;
	audio.reserve((size_t)kSampleRate * 2 * 200);
	if (udpSend && !host_midi_udp_open(udpListen, udpSend)) {
		return 1;
	}

	// deluge_main() without the hardware (spec §3.3's host init list)
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
	if (!udpSend && !injections.empty()) {
		// Inject mode: test events go to stderr (as the probe's "03 00 01" subscribe would send them over MIDI).
		Debug::midiDebugCable = &MIDIDeviceManager::dinMIDIPorts;
		host_midi_print_events = true;
	}
	std::fprintf(stderr, "booted at %.3f s virtual, %.2f s wall\n", virtualNow(), wallNow());

	registerTasks();
	addRepeatingTask(hostTask, 35, 0.005, 0.01, 0.02, "host", RESOURCE_NONE);
	startTaskManager();
	return 0;
}
