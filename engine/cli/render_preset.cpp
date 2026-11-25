// The Engine's first render (E1), ported from the spike's render_preset driver. Boots the firmware's engine headless,
// loads a Synth or Kit preset from a FAT32 card image through the firmware's own StorageManager, auditions one note,
// and pulls audio through AudioEngine::routine() by advancing the simulated SSI DMA read position. Writes a 44.1 kHz
// stereo 32-bit WAV; it never opens an audio device. E4 replaces it with `deluge-engine render` on the Engine API.
//
// usage: DELUGE_SD_IMAGE=card.img render_preset SYNTHS/FOO.XML out.wav [note] [seconds-held] [seconds-total]
// A firmware freeze prints FREEZE_WITH_ERROR and exits with status 70 (spec §3.5).
#include "definitions_cxx.hpp"
#include "hid/display/display.h"
#include "hid/display/oled.h"
#include "memory/general_memory_allocator.h"
#include "model/clip/instrument_clip.h"
#include "model/instrument/kit.h"
#include "model/instrument/melodic_instrument.h"
#include "model/note/note_row.h"
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
#include "fatfs/ff.h"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

extern uint32_t host_audio_tx_read_frame;
extern int32_t ssiTxBuffer[];
void setupBlankSong();

// The OLED's freeze screen polls the PIC and DMA forever; on the host a freeze ends the process. E2 adds what was
// loaded and a backtrace.
class HostDisplay final : public deluge::hid::display::OLED {
public:
	void freezeWithError(char const* text) override {
		std::fprintf(stderr, "FREEZE_WITH_ERROR %s\n", text);
		std::fflush(stderr);
		std::_Exit(70);
	}
};

static InstrumentClip* linkIntoSong(Song* song, Instrument* instrument) {
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

static bool writeWav(const char* path, const std::vector<int32_t>& frames) {
	FILE* f = std::fopen(path, "wb");
	if (f == nullptr) {
		std::perror(path);
		return false;
	}
	uint32_t dataBytes = frames.size() * 4;
	auto u32 = [&](uint32_t v) { std::fwrite(&v, 4, 1, f); };
	auto u16 = [&](uint16_t v) { std::fwrite(&v, 2, 1, f); };
	std::fwrite("RIFF", 1, 4, f);
	u32(36 + dataBytes);
	std::fwrite("WAVEfmt ", 1, 8, f);
	u32(16);
	u16(1); // PCM
	u16(2);
	u32(kSampleRate);
	u32(kSampleRate * 8);
	u16(8);
	u16(32);
	std::fwrite("data", 1, 4, f);
	u32(dataBytes);
	bool ok = std::fwrite(frames.data(), 4, frames.size(), f) == frames.size();
	return std::fclose(f) == 0 && ok;
}

static int render(int argc, char** argv) {
	if (argc < 3) {
		std::fprintf(stderr, "usage: render_preset SYNTHS/X.XML out.wav [note] [held s] [total s]\n");
		return 2;
	}
	const char* presetPath = argv[1];
	int note = argc > 3 ? std::atoi(argv[3]) : 60;
	double held = argc > 4 ? std::atof(argv[4]) : 1.5;
	double total = argc > 5 ? std::atof(argv[5]) : 3.0;

	// deluge_main() without the hardware
	functionsInit();
	currentPlaybackMode = &session;
	deluge::hid::display::have_oled_screen = true;
	display = new HostDisplay;
	AudioEngine::init();
	audioFileManager.init();
	FlashStorage::readSettings();
	runtimeFeatureSettings.init();
	std::fprintf(stderr, "booted: Cluster::size %d\n", (int)Cluster::size);
	setupBlankSong();
	std::fprintf(stderr, "blank song set up\n");

	FilePointer fp;
	if (!StorageManager::fileExists(presetPath, &fp)) {
		std::fprintf(stderr, "preset not found on card image: %s\n", presetPath);
		return 1;
	}
	String name;
	String dir;
	const char* slash = std::strrchr(presetPath, '/');
	name.set(slash ? slash + 1 : presetPath);
	dir.set(presetPath, slash ? (int)(slash - presetPath) : 0);
	Instrument* instrument = nullptr;
	const bool isKit = std::strncmp(presetPath, "KITS/", 5) == 0;
	const OutputType type = isKit ? OutputType::KIT : OutputType::SYNTH;
	Error error = StorageManager::loadInstrumentFromFile(currentSong, nullptr, type, true, &instrument,
	                                                     &fp, &name, &dir);
	if (error != Error::NONE || instrument == nullptr) {
		std::fprintf(stderr, "loadInstrumentFromFile failed: error %d\n", (int)error);
		return 1;
	}
	InstrumentClip* clip = linkIntoSong(currentSong, instrument);
	if (!clip) {
		std::fprintf(stderr, "linking failed\n");
		return 1;
	}
	std::fprintf(stderr, "loaded %s\n", presetPath);

	char modelStackMemory[MODEL_STACK_MAX_SIZE];
	ModelStack* modelStack = setupModelStackWithSong(modelStackMemory, currentSong);
	auto* melodic = static_cast<MelodicInstrument*>(instrument);
	// For a kit, `note` is the drum (NoteRow) index.
	auto noteOn = [&](bool on) {
		if (!isKit) {
			if (on) {
				melodic->beginAuditioningForNote(modelStack, note, 100, zeroMPEValues);
			}
			else {
				melodic->endAuditioningForNote(modelStack, note);
			}
			return;
		}
		auto* kit = static_cast<Kit*>(instrument);
		NoteRow* row = clip->noteRows.getElement(note);
		ModelStackWithNoteRow* ms = modelStack->addTimelineCounter(clip)->addNoteRow(note, row);
		if (on) {
			kit->beginAuditioningforDrum(ms, row->drum, 100, zeroMPEValues);
		}
		else {
			kit->endAuditioningForDrum(ms, row->drum);
		}
	};

	std::vector<int32_t> out;
	const uint32_t step = 32; // frames the "DMA" consumes between engine calls
	const uint64_t heldFrames = held * kSampleRate;
	const uint64_t totalFrames = total * kSampleRate;
	bool on = false;
	bool released = false;
	for (uint64_t frame = 0; frame < totalFrames; frame += step) {
		if (!on && frame >= 4096) { // let the engine settle first
			noteOn(true);
			on = true;
		}
		if (on && !released && frame >= 4096 + heldFrames) {
			noteOn(false);
			released = true;
		}
		// The DMA plays `step` frames, then the engine refills them for the next lap of the ring.
		for (uint32_t i = 0; i < step; i++) {
			uint32_t idx = (host_audio_tx_read_frame + i) % SSI_TX_BUFFER_NUM_SAMPLES;
			out.push_back(ssiTxBuffer[idx * 2]);
			out.push_back(ssiTxBuffer[idx * 2 + 1]);
		}
		host_audio_tx_read_frame = (host_audio_tx_read_frame + step) % SSI_TX_BUFFER_NUM_SAMPLES;
		AudioEngine::routine();
		// The firmware's scheduler runs this as its own task: sample clusters are streamed from the card here.
		audioFileManager.loadAnyEnqueuedClusters(128, false);
	}
	if (!writeWav(argv[2], out)) {
		std::fprintf(stderr, "couldn't write %s\n", argv[2]);
		return 1;
	}
	int64_t peak = 0; // int64: -INT32_MIN doesn't fit an int32
	for (int32_t s : out) {
		peak = std::max<int64_t>(peak, s < 0 ? -(int64_t)s : s);
	}
	std::fprintf(stderr, "wrote %s: %zu frames, peak %lld (%.1f dBFS)\n", argv[2], out.size() / 2,
	             (long long)peak, peak ? 20 * std::log10(peak / 2147483648.0) : -999.0);
	return 0;
}

int main(int argc, char** argv) {
	// Flush denormals to zero, as the Deluge's NEON does (spec §3.3). E2 sets it on the engine thread.
	__builtin_arm_wsr64("fpcr", __builtin_arm_rsr64("fpcr") | (1ull << 24));
	int status = render(argc, argv);
	// The Deluge never exits, so the firmware's global destructors were never meant to run: FileReader's frees a
	// pointer offset from the one it allocated. Leave without them.
	std::fflush(nullptr);
	std::_Exit(status);
}
