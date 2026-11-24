// Spike driver: boot the firmware's engine headless, load a SYNTHS/*.XML preset from a FAT32 image through the
// firmware's own StorageManager, audition one note, and pull audio through AudioEngine::routine() by advancing the
// simulated SSI DMA read position. Writes a 44.1 kHz stereo 32-bit WAV.
//
// usage: DELUGE_SD_IMAGE=card.img render_preset SYNTHS/FOO.XML out.wav [note] [seconds-held] [seconds-total]
#include "definitions_cxx.hpp"
#include "hid/display/display.h"
#include "hid/display/oled.h"
#include "memory/general_memory_allocator.h"
#include "model/clip/instrument_clip.h"
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
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

extern uint32_t host_audio_tx_read_frame;
extern int32_t ssiTxBuffer[];
void setupBlankSong();

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
	song->sessionClips.insertClipAtIndex(clip, song->sessionClips.getNumElements());
	song->addOutput(instrument, false);
	instrument->setActiveClip(modelStack);
	return clip;
}

static void writeWav(const char* path, const std::vector<int32_t>& frames) {
	FILE* f = std::fopen(path, "wb");
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
	std::fwrite(frames.data(), 4, frames.size(), f);
	std::fclose(f);
}

int main(int argc, char** argv) {
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
	display = new deluge::hid::display::OLED;
	AudioEngine::init();
	audioFileManager.init();
	FlashStorage::readSettings();
	runtimeFeatureSettings.init();
	setupBlankSong();
	std::fprintf(stderr, "booted: Cluster::size %d\n", (int)Cluster::size);

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
	Error error = StorageManager::loadInstrumentFromFile(currentSong, nullptr, OutputType::SYNTH, true, &instrument,
	                                                     &fp, &name, &dir);
	if (error != Error::NONE || instrument == nullptr) {
		std::fprintf(stderr, "loadInstrumentFromFile failed: error %d\n", (int)error);
		return 1;
	}
	if (!linkIntoSong(currentSong, instrument)) {
		std::fprintf(stderr, "linking failed\n");
		return 1;
	}
	std::fprintf(stderr, "loaded %s\n", presetPath);

	char modelStackMemory[MODEL_STACK_MAX_SIZE];
	ModelStack* modelStack = setupModelStackWithSong(modelStackMemory, currentSong);
	auto* melodic = static_cast<MelodicInstrument*>(instrument);

	std::vector<int32_t> out;
	const uint32_t step = 32; // frames the "DMA" consumes between engine calls
	const uint64_t heldFrames = held * kSampleRate;
	const uint64_t totalFrames = total * kSampleRate;
	bool on = false;
	bool released = false;
	for (uint64_t frame = 0; frame < totalFrames; frame += step) {
		if (!on && frame >= 4096) { // let the engine settle first
			melodic->beginAuditioningForNote(modelStack, note, 100, zeroMPEValues);
			on = true;
		}
		if (on && !released && frame >= 4096 + heldFrames) {
			melodic->endAuditioningForNote(modelStack, note);
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
	}
	writeWav(argv[2], out);
	int32_t peak = 0;
	for (int32_t s : out) {
		peak = std::max(peak, s < 0 ? -s : s);
	}
	std::fprintf(stderr, "wrote %s: %zu frames, peak %d (%.1f dBFS)\n", argv[2], out.size() / 2, peak,
	             peak ? 20 * std::log10(peak / 2147483648.0) : -999.0);
	return 0;
}
