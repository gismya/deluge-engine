// Offline preset renderer driven by the firmware's own scheduler on the virtual clock (E2, spec §3.4 & §3.5).
// Boots the firmware headless, loads a Synth or Kit preset from a FAT32 card image through StorageManager,
// auditions one note from a host scheduler task, and captures audio from the simulated SSI DMA sink.
// Writes a 44.1 kHz stereo 32-bit WAV; never opens an audio device. E4 replaces it with `deluge-engine render`.
//
// usage: DELUGE_SD_IMAGE=card.img render_preset [--pace F] [--audio null] SYNTHS/FOO.XML out.wav [note] [held s] [total s]
// A firmware freeze prints FREEZE_WITH_ERROR with what was loaded and a backtrace, then exits with status 70.
#include "OSLikeStuff/scheduler_api.h"
#include "definitions_cxx.hpp"
#include "memory/general_memory_allocator.h"
#include "model/clip/instrument_clip.h"
#include "model/instrument/kit.h"
#include "model/instrument/melodic_instrument.h"
#include "model/model_stack.h"
#include "model/note/note_row.h"
#include "model/song/song.h"
#include "platform/host_platform.h"
#include "storage/cluster/cluster.h"
#include "storage/storage_manager.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

namespace plat = deluge::engine::platform;

namespace {

constexpr uint64_t kNoteOnFrame = 4096; // let the engine settle before triggering the note

Instrument* gInstrument = nullptr;
InstrumentClip* gClip = nullptr;
bool gIsKit = false;
int gNote = 60;
uint64_t gHeldFrames = 0;
uint64_t gTotalFrames = 0;
const char* gOutPath = nullptr;
bool gNoteOn = false;
bool gReleased = false;
std::vector<int32_t> gOut;

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

bool writeWav(const char* path, const std::vector<int32_t>& frames) {
	FILE* f = std::fopen(path, "wb");
	if (f == nullptr) {
		std::perror(path);
		return false;
	}
	uint32_t dataBytes = static_cast<uint32_t>(frames.size() * 4);
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

void triggerNote(bool on) {
	char modelStackMemory[MODEL_STACK_MAX_SIZE];
	ModelStack* modelStack = setupModelStackWithSong(modelStackMemory, currentSong);
	if (!gIsKit) {
		auto* melodic = static_cast<MelodicInstrument*>(gInstrument);
		if (on) {
			melodic->beginAuditioningForNote(modelStack, gNote, 100, zeroMPEValues);
		}
		else {
			melodic->endAuditioningForNote(modelStack, gNote);
		}
		return;
	}
	auto* kit = static_cast<Kit*>(gInstrument);
	NoteRow* row = gClip->noteRows.getElement(gNote);
	ModelStackWithNoteRow* ms = modelStack->addTimelineCounter(gClip)->addNoteRow(gNote, row);
	if (on) {
		kit->beginAuditioningforDrum(ms, row->drum, 100, zeroMPEValues);
	}
	else {
		kit->endAuditioningForDrum(ms, row->drum);
	}
}

void audioSink(const int32_t* frame) {
	if (gOut.size() < gTotalFrames * 2) {
		gOut.push_back(frame[0]);
		gOut.push_back(frame[1]);
	}
}

void hostRenderTask() {
	const uint64_t frames = gOut.size() / 2;
	if (!gNoteOn && frames >= kNoteOnFrame) {
		triggerNote(true);
		gNoteOn = true;
	}
	if (gNoteOn && !gReleased && frames >= kNoteOnFrame + gHeldFrames) {
		triggerNote(false);
		gReleased = true;
	}
	if (frames >= gTotalFrames) {
		if (!writeWav(gOutPath, gOut)) {
			std::fprintf(stderr, "couldn't write %s\n", gOutPath);
			std::fflush(nullptr);
			std::_Exit(1);
		}
		int64_t peak = 0; // int64: -INT32_MIN doesn't fit an int32
		for (int32_t s : gOut) {
			peak = std::max<int64_t>(peak, s < 0 ? -static_cast<int64_t>(s) : s);
		}
		std::fprintf(stderr, "wrote %s: %zu frames, peak %lld (%.1f dBFS), overruns %llu\n", gOutPath, gOut.size() / 2,
		             static_cast<long long>(peak), peak ? 20 * std::log10(peak / 2147483648.0) : -999.0,
		             static_cast<unsigned long long>(plat::dmaOverruns()));
		std::fflush(nullptr);
		std::_Exit(0);
	}
}

int render(int argc, char** argv) {
	double paceVal = 0.0;
	std::vector<const char*> positional;
	for (int i = 1; i < argc; i++) {
		if (std::strcmp(argv[i], "--pace") == 0 && i + 1 < argc) {
			paceVal = std::atof(argv[++i]);
		}
		else if (std::strcmp(argv[i], "--audio") == 0 && i + 1 < argc) {
			const char* audioArg = argv[++i];
			if (std::strcmp(audioArg, "null") != 0) {
				std::fprintf(stderr, "render_preset only supports --audio null\n");
				return 2;
			}
		}
		else if (argv[i][0] == '-') {
			std::fprintf(stderr, "unknown option: %s\n", argv[i]);
			return 2;
		}
		else {
			positional.push_back(argv[i]);
		}
	}

	if (positional.size() < 2) {
		std::fprintf(stderr,
		             "usage: render_preset [--pace F] [--audio null] SYNTHS/X.XML out.wav [note] [held s] [total s]\n");
		return 2;
	}
	const char* presetPath = positional[0];
	gOutPath = positional[1];
	gNote = positional.size() > 2 ? std::atoi(positional[2]) : 60;
	const double held = positional.size() > 3 ? std::atof(positional[3]) : 1.5;
	const double total = positional.size() > 4 ? std::atof(positional[4]) : 3.0;
	gHeldFrames = static_cast<uint64_t>(held * kSampleRate);
	gTotalFrames = static_cast<uint64_t>(total * kSampleRate);
	gOut.reserve(static_cast<size_t>(gTotalFrames * 2));

	plat::bootFirmware();
	std::fprintf(stderr, "booted: Cluster::size %d\n", static_cast<int>(Cluster::size));

	plat::setFreezeLoadedContext(presetPath);
	FilePointer fp;
	if (!StorageManager::fileExists(presetPath, &fp)) {
		std::fprintf(stderr, "preset not found on card image: %s\n", presetPath);
		return 1;
	}
	String name;
	String dir;
	const char* slash = std::strrchr(presetPath, '/');
	name.set(slash ? slash + 1 : presetPath);
	dir.set(presetPath, slash ? static_cast<int>(slash - presetPath) : 0);
	gIsKit = std::strncmp(presetPath, "KITS/", 5) == 0;
	const OutputType type = gIsKit ? OutputType::KIT : OutputType::SYNTH;
	Error error = StorageManager::loadInstrumentFromFile(currentSong, nullptr, type, true, &gInstrument, &fp, &name,
	                                                     &dir);
	if (error != Error::NONE || gInstrument == nullptr) {
		std::fprintf(stderr, "loadInstrumentFromFile failed: error %d\n", static_cast<int>(error));
		return 1;
	}
	gClip = linkIntoSong(currentSong, gInstrument);
	if (gClip == nullptr) {
		std::fprintf(stderr, "linking failed\n");
		return 1;
	}
	std::fprintf(stderr, "loaded %s\n", presetPath);

	plat::resetDma();
	plat::setAudioSink(audioSink);
	plat::setDmaFollowsClock(true);
	plat::setPace(paceVal);

	addRepeatingTask(hostRenderTask, 35, 0.0005, 0.001, 0.002, "host_render", RESOURCE_NONE);
	plat::runScheduler();
	return 0;
}

} // namespace

int main(int argc, char** argv) {
	int status = render(argc, argv);
	// The Deluge never exits, so the firmware's global destructors were never meant to run: FileReader's frees a
	// pointer offset from the one it allocated. Leave without them.
	std::fflush(nullptr);
	std::_Exit(status);
}
