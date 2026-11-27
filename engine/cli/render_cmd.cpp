// `deluge-engine render` CLI subcommand (E4, spec §3.9).
// Renders a Synth or Kit preset driven by `--midi FILE.mid` or `--notes LIST` to a 44.1 kHz stereo 24-bit WAV.
#include "cli/render_cmd.h"
#include "core/engine.h"
#include "core/midi_input.h"
#include "core/wav.h"

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace core = deluge::engine::core;

namespace deluge::engine::cli {

namespace {

bool parseNonNegativeDouble(const char* s, double* out) {
	if (s == nullptr || *s == '\0') {
		return false;
	}
	char* end = nullptr;
	errno = 0;
	const double v = std::strtod(s, &end);
	if (errno != 0 || end == s || *end != '\0' || !std::isfinite(v) || v < 0.0) {
		return false;
	}
	*out = v;
	return true;
}

} // namespace

void printRenderUsage() {
	std::fprintf(stderr,
	             "  deluge-engine render --card FOLDER --preset PATH (--midi FILE.mid | --notes LIST) --out WAV\n"
	             "                       [--card-image FILE] [--card-cache DIR] [--lead-in S] [--tail S]\n"
	             "                       [--duration S] [--pace F] [--audio null]\n");
}

int cmdRender(int argc, char** argv) {
	std::string cardFolder;
	std::string cardImage;
	std::string cardCacheDir;
	std::string presetPath;
	std::string midiPath;
	std::string notesSpec;
	std::string outPath;
	std::string audioDevice = "null";
	double leadInSec = 0.1;
	double tailSec = 1.5;
	double durationOverride = -1.0;
	double pace = 0.0;

	for (int i = 0; i < argc; ++i) {
		const char* arg = argv[i];
		auto needValue = [&](const char* opt) -> const char* {
			if (i + 1 >= argc) {
				std::fprintf(stderr, "render: %s requires a value\n", opt);
				return nullptr;
			}
			return argv[++i];
		};

		if (std::strcmp(arg, "--card") == 0) {
			const char* v = needValue("--card");
			if (v == nullptr) return 2;
			cardFolder = v;
		}
		else if (std::strcmp(arg, "--card-image") == 0) {
			const char* v = needValue("--card-image");
			if (v == nullptr) return 2;
			cardImage = v;
		}
		else if (std::strcmp(arg, "--card-cache") == 0) {
			const char* v = needValue("--card-cache");
			if (v == nullptr) return 2;
			cardCacheDir = v;
		}
		else if (std::strcmp(arg, "--preset") == 0) {
			const char* v = needValue("--preset");
			if (v == nullptr) return 2;
			presetPath = v;
		}
		else if (std::strcmp(arg, "--midi") == 0) {
			const char* v = needValue("--midi");
			if (v == nullptr) return 2;
			midiPath = v;
		}
		else if (std::strcmp(arg, "--notes") == 0) {
			const char* v = needValue("--notes");
			if (v == nullptr) return 2;
			notesSpec = v;
		}
		else if (std::strcmp(arg, "--out") == 0) {
			const char* v = needValue("--out");
			if (v == nullptr) return 2;
			outPath = v;
		}
		else if (std::strcmp(arg, "--audio") == 0) {
			const char* v = needValue("--audio");
			if (v == nullptr) return 2;
			audioDevice = v;
		}
		else if (std::strcmp(arg, "--lead-in") == 0) {
			const char* v = needValue("--lead-in");
			if (v == nullptr || !parseNonNegativeDouble(v, &leadInSec)) {
				std::fprintf(stderr, "render: invalid --lead-in value\n");
				return 2;
			}
		}
		else if (std::strcmp(arg, "--tail") == 0) {
			const char* v = needValue("--tail");
			if (v == nullptr || !parseNonNegativeDouble(v, &tailSec)) {
				std::fprintf(stderr, "render: invalid --tail value\n");
				return 2;
			}
		}
		else if (std::strcmp(arg, "--duration") == 0) {
			const char* v = needValue("--duration");
			if (v == nullptr || !parseNonNegativeDouble(v, &durationOverride) || durationOverride <= 0.0) {
				std::fprintf(stderr, "render: invalid --duration value\n");
				return 2;
			}
		}
		else if (std::strcmp(arg, "--pace") == 0) {
			const char* v = needValue("--pace");
			if (v == nullptr || !parseNonNegativeDouble(v, &pace)) {
				std::fprintf(stderr, "render: invalid --pace value\n");
				return 2;
			}
		}
		else if (std::strcmp(arg, "--help") == 0 || std::strcmp(arg, "-h") == 0) {
			printRenderUsage();
			return 0;
		}
		else {
			std::fprintf(stderr, "render: unknown option: %s\n", arg);
			return 2;
		}
	}

	if (audioDevice != "null") {
		std::fprintf(stderr, "render: offline rendering only supports --audio null (got '%s')\n", audioDevice.c_str());
		return 2;
	}
	if (presetPath.empty()) {
		std::fprintf(stderr, "render: --preset PATH is required\n");
		return 2;
	}
	if (outPath.empty()) {
		std::fprintf(stderr, "render: --out WAV is required\n");
		return 2;
	}
	if (midiPath.empty() == notesSpec.empty()) {
		std::fprintf(stderr, "render: specify exactly one of --midi FILE.mid or --notes LIST\n");
		return 2;
	}

	const char* envImage = std::getenv("DELUGE_SD_IMAGE");
	if (cardFolder.empty() && cardImage.empty() && (envImage == nullptr || envImage[0] == '\0')) {
		std::fprintf(stderr, "render: --card FOLDER (or --card-image / DELUGE_SD_IMAGE) is required\n");
		return 2;
	}

	core::MidiSequence seq;
	std::string parseErr;
	const bool parsed = !midiPath.empty() ? core::parseMidiFile(midiPath, &seq, &parseErr)
	                                      : core::parseNotesList(notesSpec, &seq, &parseErr);
	if (!parsed) {
		std::fprintf(stderr, "render: %s\n", parseErr.c_str());
		return 2;
	}

	const double totalSec = (durationOverride > 0.0) ? durationOverride : (leadInSec + seq.durationSeconds + tailSec);
	const size_t totalFrames = static_cast<size_t>(std::llround(totalSec * static_cast<double>(core::kSampleRate)));
	if (totalFrames == 0) {
		std::fprintf(stderr, "render: computed duration is 0 frames\n");
		return 2;
	}

	core::Engine engine;
	core::Config cfg;
	cfg.cardFolder = cardFolder;
	cfg.cardImagePath = cardImage;
	cfg.cardCacheDir = cardCacheDir;
	cfg.pace = pace;

	std::string bootErr;
	if (!engine.boot(cfg, &bootErr)) {
		std::fprintf(stderr, "render: %s\n", bootErr.c_str());
		return 1;
	}

	const core::PresetLoadResult loaded = engine.loadPreset(presetPath);
	if (!loaded.ok) {
		std::fprintf(stderr, "render: %s\n", loaded.error.c_str());
		return 1;
	}

	core::Callbacks renderCallbacks;
	renderCallbacks.onError = [](std::string_view msg) {
		std::fprintf(stderr, "render error: %.*s\n", static_cast<int>(msg.size()), msg.data());
	};
	engine.setCallbacks(std::move(renderCallbacks));

	std::vector<int32_t> audio(totalFrames * core::kChannels);
	size_t currentFrame = 0;

	for (const auto& ev : seq.events) {
		const size_t evFrame =
		    static_cast<size_t>(std::llround((leadInSec + ev.timeSeconds) * static_cast<double>(core::kSampleRate)));
		if (evFrame >= totalFrames) {
			break;
		}
		if (evFrame > currentFrame) {
			const size_t delta = evFrame - currentFrame;
			engine.render(audio.data() + currentFrame * core::kChannels, delta);
			currentFrame += delta;
		}
		if (!engine.midi(ev.bytes.data(), ev.bytes.size())) {
			std::fprintf(stderr, "render: MIDI buffer full at frame %zu\n", currentFrame);
			return 1;
		}
	}

	if (currentFrame < totalFrames) {
		engine.render(audio.data() + currentFrame * core::kChannels, totalFrames - currentFrame);
	}

	std::string wavErr;
	if (!core::writeWav24(outPath, audio.data(), totalFrames, core::kSampleRate, &wavErr)) {
		std::fprintf(stderr, "render: %s\n", wavErr.c_str());
		return 1;
	}

	int64_t peak = 0;
	for (int32_t s : audio) {
		peak = std::max<int64_t>(peak, s < 0 ? -static_cast<int64_t>(s) : s);
	}
	const double peakDbfs = peak > 0 ? 20.0 * std::log10(static_cast<double>(peak) / 2147483648.0) : -999.0;
	std::fprintf(stderr, "wrote %s: %zu frames (24-bit), peak %.1f dBFS, peak_voices %d, overruns %llu\n",
	             outPath.c_str(), totalFrames, peakDbfs, engine.peakVoiceCount(),
	             static_cast<unsigned long long>(engine.dmaOverruns()));
	return 0;
}

} // namespace deluge::engine::cli
