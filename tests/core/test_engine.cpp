// Engine core unit and integration tests (E4, spec §3.7 & §3.9).
//
// Modes:
//   --unit-pure                                 WAV24, --notes, SMF parser unit tests (no firmware boot)
//   --unit-engine PACK_DIR KIT_CARD_DIR TMP     Engine API, MIDI follow, preset swap, Kit, TestPort inject/sink
//   --test-freeze PACK_DIR TMP                  Freeze callback invocation + exit code 70
//   --load-all-twice CARD_DIR CACHE_DIR         Boot once, load every Synth & Kit preset twice and render a note
#include "core/engine.h"
#include "core/midi_input.h"
#include "core/wav.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

namespace core = deluge::engine::core;
namespace fs = std::filesystem;

namespace {

int gFailures = 0;

void check(bool cond, const char* expr, int line, const std::string& detail = {}) {
	if (!cond) {
		++gFailures;
		if (detail.empty()) {
			std::fprintf(stderr, "FAIL line %d: %s\n", line, expr);
		}
		else {
			std::fprintf(stderr, "FAIL line %d: %s (%s)\n", line, expr, detail.c_str());
		}
	}
}

#define CHECK(expr) check((expr), #expr, __LINE__)
#define CHECK_MSG(expr, msg) check((expr), #expr, __LINE__, (msg))

double channelRms(const std::vector<int32_t>& stereo, size_t startFrame, size_t endFrame, int ch) {
	const size_t totalFrames = stereo.size() / 2;
	startFrame = std::min(startFrame, totalFrames);
	endFrame = std::min(endFrame, totalFrames);
	if (endFrame <= startFrame) {
		return 0.0;
	}
	double sum = 0.0;
	for (size_t i = startFrame; i < endFrame; ++i) {
		const double s = static_cast<double>(stereo[i * 2 + static_cast<size_t>(ch)]) / 2147483648.0;
		sum += s * s;
	}
	return std::sqrt(sum / static_cast<double>(endFrame - startFrame));
}

double zeroCrossingHz(const std::vector<int32_t>& stereo, size_t startFrame, size_t endFrame) {
	std::vector<double> crossings;
	for (size_t i = startFrame; i + 1 < endFrame; ++i) {
		const double a = static_cast<double>(stereo[i * 2]);
		const double b = static_cast<double>(stereo[(i + 1) * 2]);
		if (a < 0.0 && b >= 0.0) {
			crossings.push_back(static_cast<double>(i) + a / (a - b));
		}
	}
	if (crossings.size() < 2) {
		return 0.0;
	}
	return static_cast<double>(crossings.size() - 1) * core::kSampleRate / (crossings.back() - crossings.front());
}

void pushU32BE(std::vector<uint8_t>& out, uint32_t v) {
	out.push_back(static_cast<uint8_t>((v >> 24) & 0xFF));
	out.push_back(static_cast<uint8_t>((v >> 16) & 0xFF));
	out.push_back(static_cast<uint8_t>((v >> 8) & 0xFF));
	out.push_back(static_cast<uint8_t>(v & 0xFF));
}

void pushU16BE(std::vector<uint8_t>& out, uint16_t v) {
	out.push_back(static_cast<uint8_t>((v >> 8) & 0xFF));
	out.push_back(static_cast<uint8_t>(v & 0xFF));
}

void pushChunk(std::vector<uint8_t>& out, const char tag[4], const std::vector<uint8_t>& body) {
	out.insert(out.end(), tag, tag + 4);
	pushU32BE(out, static_cast<uint32_t>(body.size()));
	out.insert(out.end(), body.begin(), body.end());
}

int32_t decodeS24LE(const uint8_t* p) {
	uint32_t u = static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) | (static_cast<uint32_t>(p[2]) << 16);
	if (u & 0x800000u) {
		u |= 0xFF000000u;
	}
	return static_cast<int32_t>(u);
}

void testWav24(const std::string& tmpDir) {
	const std::string wavPath = tmpDir + "/test24.wav";
	const std::vector<int32_t> frames = {
	    0,
	    INT32_MAX,
	    INT32_MIN,
	    -256,
	    0x12345600,
	    -0x12345600,
	};
	std::string err;
	CHECK_MSG(core::writeWav24(wavPath, frames.data(), frames.size() / 2, 44100, &err), err);

	std::ifstream in(wavPath, std::ios::binary);
	std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
	const size_t expectedDataBytes = (frames.size() / 2) * 6;
	CHECK(bytes.size() == 44 + expectedDataBytes);
	if (bytes.size() == 44 + expectedDataBytes) {
		CHECK(std::memcmp(bytes.data(), "RIFF", 4) == 0);
		CHECK(std::memcmp(bytes.data() + 8, "WAVEfmt ", 8) == 0);
		CHECK(std::memcmp(bytes.data() + 36, "data", 4) == 0);
		uint16_t format = 0, channels = 0, blockAlign = 0, bits = 0;
		uint32_t sampleRate = 0, byteRate = 0, dataSize = 0;
		std::memcpy(&format, bytes.data() + 20, 2);
		std::memcpy(&channels, bytes.data() + 22, 2);
		std::memcpy(&sampleRate, bytes.data() + 24, 4);
		std::memcpy(&byteRate, bytes.data() + 28, 4);
		std::memcpy(&blockAlign, bytes.data() + 32, 2);
		std::memcpy(&bits, bytes.data() + 34, 2);
		std::memcpy(&dataSize, bytes.data() + 40, 4);
		CHECK(format == 1);
		CHECK(channels == 2);
		CHECK(sampleRate == 44100);
		CHECK(byteRate == 44100 * 6);
		CHECK(blockAlign == 6);
		CHECK(bits == 24);
		CHECK(dataSize == expectedDataBytes);

		CHECK(decodeS24LE(bytes.data() + 44 + 0) == 0);
		CHECK(decodeS24LE(bytes.data() + 44 + 3) == 8388607);
		CHECK(decodeS24LE(bytes.data() + 44 + 6) == -8388608);
		CHECK(decodeS24LE(bytes.data() + 44 + 9) == -1);
		CHECK(decodeS24LE(bytes.data() + 44 + 12) == 0x123456);
		CHECK(decodeS24LE(bytes.data() + 44 + 15) == -0x123456);
	}

	// Unwritable path fails cleanly.
	CHECK(!core::writeWav24(tmpDir + "/no-such-dir/out.wav", frames.data(), 1, 44100, &err));
	CHECK(!err.empty());
}

void testNotesParser() {
	core::MidiSequence seq;
	std::string err;

	// Single numeric note with default dur=1.0, vel=100.
	CHECK_MSG(core::parseNotesList("60", &seq, &err), err);
	CHECK(seq.events.size() == 2);
	if (seq.events.size() == 2) {
		CHECK(std::abs(seq.events[0].timeSeconds - 0.0) < 1e-9);
		CHECK(seq.events[0].bytes == (std::vector<uint8_t>{0x90, 60, 100}));
		CHECK(std::abs(seq.events[1].timeSeconds - 1.0) < 1e-9);
		CHECK(seq.events[1].bytes == (std::vector<uint8_t>{0x80, 60, 0x40}));
	}
	CHECK(std::abs(seq.durationSeconds - 1.0) < 1e-9);

	// Note names, accidentals, chords, explicit start/dur/vel.
	CHECK_MSG(core::parseNotesList("C2:1.0, C#4:0.5:80, Eb3+G3+Bb3@2.0:1.5:90", &seq, &err), err);
	CHECK(seq.events.size() == 10); // 1+1+3 notes -> 10 on/off events
	CHECK(std::abs(seq.durationSeconds - 3.5) < 1e-9);
	if (seq.events.size() == 10) {
		CHECK(seq.events[0].bytes == (std::vector<uint8_t>{0x90, 36, 100})); // C2 = 36
		CHECK(std::abs(seq.events[0].timeSeconds - 0.0) < 1e-9);
		CHECK(seq.events[2].bytes == (std::vector<uint8_t>{0x90, 61, 80})); // C#4 = 61
		CHECK(std::abs(seq.events[2].timeSeconds - 1.0) < 1e-9);
		CHECK(seq.events[4].bytes == (std::vector<uint8_t>{0x90, 51, 90})); // Eb3 = 51
		CHECK(seq.events[5].bytes == (std::vector<uint8_t>{0x90, 55, 90})); // G3 = 55
		CHECK(seq.events[6].bytes == (std::vector<uint8_t>{0x90, 58, 90})); // Bb3 = 58
		CHECK(std::abs(seq.events[4].timeSeconds - 2.0) < 1e-9);
	}

	// At equal timestamps, note-off must precede note-on even when the later note appears earlier in the list.
	CHECK_MSG(core::parseNotesList("60@0.5:0.5, 60@0.0:0.5", &seq, &err), err);
	CHECK(seq.events.size() == 4);
	if (seq.events.size() == 4) {
		CHECK(std::abs(seq.events[0].timeSeconds - 0.0) < 1e-9);
		CHECK(seq.events[0].bytes == (std::vector<uint8_t>{0x90, 60, 100}));
		CHECK(std::abs(seq.events[1].timeSeconds - 0.5) < 1e-9);
		CHECK(seq.events[1].bytes == (std::vector<uint8_t>{0x80, 60, 0x40})); // note-off first
		CHECK(std::abs(seq.events[2].timeSeconds - 0.5) < 1e-9);
		CHECK(seq.events[2].bytes == (std::vector<uint8_t>{0x90, 60, 100})); // note-on second
		CHECK(std::abs(seq.events[3].timeSeconds - 1.0) < 1e-9);
		CHECK(seq.events[3].bytes == (std::vector<uint8_t>{0x80, 60, 0x40}));
	}

	// Reject invalid inputs.
	CHECK(!core::parseNotesList("", &seq, &err));
	CHECK(!core::parseNotesList("128", &seq, &err));
	CHECK(!core::parseNotesList("H4", &seq, &err));
	CHECK(!core::parseNotesList("60:-1", &seq, &err));
	CHECK(!core::parseNotesList("60:1:0", &seq, &err));
	CHECK(!core::parseNotesList("60:1:128", &seq, &err));
	CHECK(!core::parseNotesList("60@-0.5:1", &seq, &err));
}

void testMidiParser() {
	// Build a Format 1 SMF with 2 tracks:
	// Track 0: tempo 120 BPM (500,000 us/qn) at tick 0, then 60 BPM (1,000,000 us/qn) at tick 480 (0.5 s).
	// Track 1: Note On ch 1 note 60 vel 100 at tick 0, running-status Note On vel 0 (note off) at tick 480 (0.5 s),
	//          Note On ch 10 note 36 vel 110 at tick 960 (1.5 s), Note Off at tick 1440 (2.5 s).
	std::vector<uint8_t> smf;
	std::vector<uint8_t> hdr;
	pushU16BE(hdr, 1);   // format 1
	pushU16BE(hdr, 2);   // 2 tracks
	pushU16BE(hdr, 480); // 480 ticks/quarter
	pushChunk(smf, "MThd", hdr);

	std::vector<uint8_t> trk0 = {
	    0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, // tick 0: 500000 us/qn (120 BPM)
	    0x83, 0x60,                               // delta 480 (VLQ: 0x83 0x60)
	    0xFF, 0x51, 0x03, 0x0F, 0x42, 0x40,       // tick 480: 1000000 us/qn (60 BPM)
	    0x00, 0xFF, 0x2F, 0x00,                   // end of track
	};
	pushChunk(smf, "MTrk", trk0);

	std::vector<uint8_t> trk1 = {
	    0x00, 0x90, 60, 100,          // tick 0: note on ch 0
	    0x83, 0x60, 60, 0,            // delta 480: running status note on vel 0
	    0x83, 0x60, 0x99, 36, 110,    // delta 480 (tick 960): note on ch 9
	    0x83, 0x60, 0x89, 36, 0x40,   // delta 480 (tick 1440): note off ch 9
	    0x00, 0xFF, 0x2F, 0x00,       // end of track
	};
	pushChunk(smf, "MTrk", trk1);

	core::MidiSequence seq;
	std::string err;
	CHECK_MSG(core::parseMidiBytes(smf.data(), smf.size(), &seq, &err), err);
	CHECK(seq.events.size() == 4);
	if (seq.events.size() == 4) {
		CHECK(std::abs(seq.events[0].timeSeconds - 0.0) < 1e-6);
		CHECK(seq.events[0].bytes == (std::vector<uint8_t>{0x90, 60, 100}));
		CHECK(std::abs(seq.events[1].timeSeconds - 0.5) < 1e-6);
		CHECK(seq.events[1].bytes == (std::vector<uint8_t>{0x90, 60, 0}));
		CHECK(std::abs(seq.events[2].timeSeconds - 1.5) < 1e-6);
		CHECK(seq.events[2].bytes == (std::vector<uint8_t>{0x99, 36, 110}));
		CHECK(std::abs(seq.events[3].timeSeconds - 2.5) < 1e-6);
		CHECK(seq.events[3].bytes == (std::vector<uint8_t>{0x89, 36, 0x40}));
	}
	CHECK(std::abs(seq.durationSeconds - 2.5) < 1e-6);

	// Reject Format 1 file declaring more tracks than present MTrk chunks.
	std::vector<uint8_t> missingTrackSmf;
	std::vector<uint8_t> hdr2;
	pushU16BE(hdr2, 1);   // format 1
	pushU16BE(hdr2, 2);   // declares 2 tracks
	pushU16BE(hdr2, 480);
	pushChunk(missingTrackSmf, "MThd", hdr2);
	pushChunk(missingTrackSmf, "MTrk", trk0); // only 1 track chunk
	CHECK(!core::parseMidiBytes(missingTrackSmf.data(), missingTrackSmf.size(), &seq, &err));

	// Reject garbage.
	const uint8_t bad[] = {'N', 'O', 'P', 'E'};
	CHECK(!core::parseMidiBytes(bad, sizeof(bad), &seq, &err));
}

int runPureTests(const std::string& tmpDir) {
	testWav24(tmpDir);
	testNotesParser();
	testMidiParser();
	std::fprintf(stderr, "test_engine --unit-pure: %s (%d failures)\n", gFailures == 0 ? "PASS" : "FAIL", gFailures);
	return gFailures == 0 ? 0 : 1;
}

int runEngineTests(const std::string& kitCardDir, const std::string& tmpDir) {
	std::vector<std::string> errors;
	std::vector<std::string> testEvents;
	std::vector<int32_t> voiceTrace;

	core::Engine engine;
	core::Config cfg;
	cfg.cardFolder = kitCardDir;
	cfg.cardCacheDir = tmpDir + "/cache";
	cfg.callbacks.onError = [&](std::string_view msg) { errors.emplace_back(msg); };
	cfg.callbacks.onTestEvent = [&](std::string_view ev) { testEvents.emplace_back(ev); };
	cfg.callbacks.onVoiceCount = [&](int32_t v) { voiceTrace.push_back(v); };

	std::string bootErr;
	CHECK_MSG(engine.boot(cfg, &bootErr), bootErr);
	CHECK(engine.isBooted());
	if (!engine.isBooted()) {
		return 1;
	}

	// 1. Load Synth preset & play via MIDI follow on channel 1 (0x90).
	auto res = engine.loadPreset("SYNTHS/GENERATIVE/GEN Sine Sub.XML");
	CHECK_MSG(res.ok, res.error);
	CHECK(res.kind == core::PresetKind::Synth);
	CHECK(engine.loadedPresetPath() == "SYNTHS/GENERATIVE/GEN Sine Sub.XML");

	std::vector<int32_t> buf(core::kSampleRate * 2); // 1 s buffer
	// Pre-note silence (0.1 s).
	const size_t leadFrames = core::kSampleRate / 10;
	CHECK(engine.render(buf.data(), leadFrames) == leadFrames);
	CHECK(channelRms(buf, 0, leadFrames, 0) < 1e-6);

	// Note on on ch 1 (0x90), hold 0.6 s.
	CHECK(engine.midi({0x90, 60, 100}));
	const size_t holdFrames = static_cast<size_t>(core::kSampleRate * 0.6);
	CHECK(engine.render(buf.data(), holdFrames) == holdFrames);
	const double sineRms = channelRms(buf, core::kSampleRate / 5, holdFrames, 0);
	const double sineHz = zeroCrossingHz(buf, core::kSampleRate / 5, holdFrames);
	CHECK_MSG(sineRms > 0.003, "sine rms=" + std::to_string(sineRms));
	CHECK_MSG(std::abs(sineHz - 261.63) < 261.63 * 0.004, "sine hz=" + std::to_string(sineHz));
	CHECK(engine.peakVoiceCount() >= 1);
	CHECK(!voiceTrace.empty());

	// Release and verify exponential release decays and eventually frees the voice.
	CHECK(engine.midi({0x80, 60, 0x40}));
	std::vector<int32_t> relBuf(core::kSampleRate * 2 * 2);
	CHECK(engine.render(relBuf.data(), core::kSampleRate * 2) == core::kSampleRate * 2);
	const double lateRms = channelRms(relBuf, static_cast<size_t>(core::kSampleRate * 1.4), core::kSampleRate * 2, 0);
	CHECK_MSG(lateRms < sineRms / 4.0, "release did not decay: late=" + std::to_string(lateRms));
	// Render additional release time until voice finishes completely.
	CHECK(engine.render(nullptr, core::kSampleRate * 5) == core::kSampleRate * 5);
	CHECK_MSG(engine.voiceCount() == 0, "voices after release=" + std::to_string(engine.voiceCount()));
	CHECK(engine.dmaOverruns() == 0);

	// 2. Multi-channel MIDI follow: ch 10 (0x99) and ch 16 (0x9F) also play the single preset.
	for (uint8_t ch : {uint8_t{9}, uint8_t{15}}) {
		CHECK(engine.midi({static_cast<uint8_t>(0x90 | ch), 64, 100}));
		CHECK(engine.render(buf.data(), holdFrames) == holdFrames);
		const double chRms = channelRms(buf, core::kSampleRate / 5, holdFrames, 0);
		CHECK_MSG(chRms > 0.003, "ch=" + std::to_string(ch) + " rms=" + std::to_string(chRms));
		CHECK(engine.midi({static_cast<uint8_t>(0x80 | ch), 64, 0x40}));
		CHECK(engine.render(nullptr, core::kSampleRate * 2) == core::kSampleRate * 2);
	}

	// 3. Preset swapping within one run: Synth -> Synth -> Kit -> Synth.
	auto res2 = engine.loadPreset("SYNTHS/GENERATIVE/GEN Psy Bass.XML");
	CHECK_MSG(res2.ok, res2.error);
	CHECK(engine.midi({0x90, 48, 100}));
	CHECK(engine.render(buf.data(), core::kSampleRate / 2) == core::kSampleRate / 2);
	const double psyRms = channelRms(buf, 2048, core::kSampleRate / 4, 0);
	CHECK_MSG(psyRms > 0.003, "psy bass rms=" + std::to_string(psyRms));
	CHECK(engine.midi({0x80, 48, 0x40}));
	CHECK(engine.render(nullptr, core::kSampleRate / 2) == core::kSampleRate / 2);

	// Missing preset reports error cleanly and keeps prior preset playable.
	const size_t errorsBefore = errors.size();
	auto missingRes = engine.loadPreset("SYNTHS/DOES_NOT_EXIST.XML");
	CHECK(!missingRes.ok);
	CHECK(errors.size() > errorsBefore);
	CHECK(engine.loadedPresetPath() == "SYNTHS/GENERATIVE/GEN Psy Bass.XML");

	// Swap Synth -> Kit (CC0 kit with 2 drums: clap on note 36, ride on note 37), also testing leading '/'.
	auto kitRes = engine.loadPreset("/KITS/TEST CC0 KIT.XML");
	CHECK_MSG(kitRes.ok, kitRes.error);
	CHECK(kitRes.kind == core::PresetKind::Kit);
	CHECK_MSG(kitRes.drumCount == 2, "drumCount=" + std::to_string(kitRes.drumCount));

	CHECK(engine.midi({0x99, 36, 100}));
	CHECK(engine.render(buf.data(), core::kSampleRate / 2) == core::kSampleRate / 2);
	const double drum0Rms = channelRms(buf, 0, core::kSampleRate / 4, 0);
	CHECK_MSG(drum0Rms > 0.003, "kit drum0 rms=" + std::to_string(drum0Rms));
	CHECK(engine.midi({0x89, 36, 0x40}));
	CHECK(engine.render(nullptr, core::kSampleRate / 2) == core::kSampleRate / 2);

	CHECK(engine.midi({0x99, 37, 100}));
	CHECK(engine.render(buf.data(), core::kSampleRate / 2) == core::kSampleRate / 2);
	const double drum1Rms = channelRms(buf, 0, core::kSampleRate / 4, 0);
	CHECK_MSG(drum1Rms > 0.003, "kit drum1 rms=" + std::to_string(drum1Rms));
	CHECK(engine.midi({0x89, 37, 0x40}));
	CHECK(engine.render(nullptr, core::kSampleRate / 2) == core::kSampleRate / 2);

	// Swap Kit -> Synth!
	auto backToSynth = engine.loadPreset("SYNTHS/GENERATIVE/GEN Dub Sub.XML");
	CHECK_MSG(backToSynth.ok, backToSynth.error);
	CHECK(backToSynth.kind == core::PresetKind::Synth);
	CHECK(engine.midi({0x90, 48, 100}));
	CHECK(engine.render(buf.data(), core::kSampleRate / 2) == core::kSampleRate / 2);
	const double dubRms = channelRms(buf, 4096, core::kSampleRate / 2, 0);
	CHECK_MSG(dubRms > 0.003, "dub sub rms=" + std::to_string(dubRms));
	CHECK(engine.midi({0x80, 48, 0x40}));
	CHECK(engine.render(nullptr, core::kSampleRate / 2) == core::kSampleRate / 2);

	// 4. Test port inject route + host sink (spec §3.7).
	const size_t evBefore = testEvents.size();
	CHECK(engine.testLine("report boot_dma") == core::TestLineStatus::Queued);
	CHECK(engine.render(nullptr, core::kSampleRate / 10) == core::kSampleRate / 10);
	bool sawBootDma = false;
	for (size_t i = evBefore; i < testEvents.size(); ++i) {
		if (testEvents[i].find("boot_dma running=0 mask=0x0000") != std::string::npos) {
			sawBootDma = true;
		}
	}
	CHECK_MSG(sawBootDma, "expected boot_dma event");

	// Invalid test line -> ParseError + onError callback.
	const size_t errBeforeParse = errors.size();
	CHECK(engine.testLine("midi") == core::TestLineStatus::ParseError);
	CHECK(errors.size() > errBeforeParse);

	// Scheduled test lines at fixed virtual times (load synth + timed note via S6).
	const double baseT = engine.virtualSeconds();
	const size_t evBeforeLoad = testEvents.size();
	engine.scheduleTestLine(baseT + 0.05, "hold midi_setup");
	engine.scheduleTestLine(baseT + 0.10, "load synth SYNTHS/GENERATIVE/GEN Sine Sub.XML");
	CHECK(engine.render(nullptr, core::kSampleRate / 2) == core::kSampleRate / 2);
	bool sawPresetLoaded = false;
	for (size_t i = evBeforeLoad; i < testEvents.size(); ++i) {
		if (testEvents[i].find("preset_loaded type=synth") != std::string::npos
		    && testEvents[i].find("GEN Sine Sub.XML") != std::string::npos) {
			sawPresetLoaded = true;
		}
	}
	CHECK_MSG(sawPresetLoaded, "expected preset_loaded event from scheduled testLine");

	const double noteBaseT = engine.virtualSeconds();
	engine.scheduleTestLine(noteBaseT + 0.05, "midi 9f 3c 64");
	engine.scheduleTestLine(noteBaseT + 0.45, "midi 8f 3c 40");
	CHECK(engine.render(buf.data(), core::kSampleRate) == core::kSampleRate);
	const double tpRms = channelRms(buf, static_cast<size_t>(core::kSampleRate * 0.2),
	                                static_cast<size_t>(core::kSampleRate * 0.4), 0);
	CHECK_MSG(tpRms > 0.003, "test-port midi note rms=" + std::to_string(tpRms));
	CHECK(engine.testLine("release midi_setup") == core::TestLineStatus::Queued);
	CHECK(engine.render(nullptr, core::kSampleRate / 10) == core::kSampleRate / 10);

	CHECK_MSG(engine.dmaOverruns() == 0, "overruns=" + std::to_string(engine.dmaOverruns()));

	std::fprintf(stderr, "test_engine --unit-engine: %s (%d failures, %zu test events, overruns=%llu)\n",
	             gFailures == 0 ? "PASS" : "FAIL", gFailures, testEvents.size(),
	             static_cast<unsigned long long>(engine.dmaOverruns()));
	return gFailures == 0 ? 0 : 1;
}

std::vector<std::pair<core::PresetKind, std::string>> discoverPresets(const fs::path& cardRoot) {
	std::vector<std::pair<core::PresetKind, std::string>> out;
	auto scanSubdir = [&](const char* dirName, core::PresetKind kind) {
		fs::path sub = cardRoot / dirName;
		if (!fs::is_directory(sub)) {
			return;
		}
		for (const auto& entry : fs::recursive_directory_iterator(sub)) {
			if (!entry.is_regular_file()) {
				continue;
			}
			const std::string name = entry.path().filename().string();
			if (name.empty() || name[0] == '.') {
				continue;
			}
			std::string ext = entry.path().extension().string();
			for (char& c : ext) {
				if (c >= 'a' && c <= 'z') {
					c = static_cast<char>(c - 'a' + 'A');
				}
			}
			if (ext != ".XML") {
				continue;
			}
			fs::path rel = fs::relative(entry.path(), cardRoot);
			out.emplace_back(kind, rel.generic_string());
		}
	};
	scanSubdir("SYNTHS", core::PresetKind::Synth);
	scanSubdir("KITS", core::PresetKind::Kit);
	std::sort(out.begin(), out.end(), [](const auto& a, const auto& b) { return a.second < b.second; });
	return out;
}

int runLoadAllTwice(const std::string& cardDir, const std::string& cacheDir) {
	const auto presets = discoverPresets(cardDir);
	if (presets.empty()) {
		std::fprintf(stderr, "no presets found under %s/{SYNTHS,KITS}\n", cardDir.c_str());
		return 2;
	}

	core::Engine engine;
	core::Config cfg;
	cfg.cardFolder = cardDir;
	cfg.cardCacheDir = cacheDir;
	cfg.callbacks.onError = [](std::string_view msg) {
		std::fprintf(stderr, "  engine error: %.*s\n", static_cast<int>(msg.size()), msg.data());
	};
	std::string bootErr;
	if (!engine.boot(cfg, &bootErr)) {
		std::fprintf(stderr, "boot failed: %s\n", bootErr.c_str());
		return 1;
	}

	const size_t holdFrames = core::kSampleRate / 5; // 200 ms note
	const size_t relFrames = core::kSampleRate / 10; // 100 ms release
	std::vector<int32_t> buf(holdFrames * 2);

	int failedLoads = 0;
	int sounding = 0;
	int silent = 0;
	size_t totalLoads = 0;
	size_t stealablePass1 = 0;
	size_t stealablePass2 = 0;

	for (int pass = 1; pass <= 2; ++pass) {
		for (const auto& [kind, relPath] : presets) {
			++totalLoads;
			auto res = engine.loadPreset(relPath, kind);
			if (!res.ok) {
				++failedLoads;
				std::fprintf(stderr, "FAIL pass %d load %s: %s\n", pass, relPath.c_str(), res.error.c_str());
				continue;
			}
			const uint8_t note = (kind == core::PresetKind::Kit) ? 36 : 60;
			engine.midi({0x90, note, 100});
			engine.render(buf.data(), holdFrames);
			const double level = channelRms(buf, 0, holdFrames, 0);
			if (level > 1e-5) {
				++sounding;
			}
			else {
				++silent;
			}
			engine.midi({0x80, note, 0x40});
			engine.render(nullptr, relFrames);
		}
		if (pass == 1) {
			stealablePass1 = engine.stealableBytesUsed();
		}
		else {
			stealablePass2 = engine.stealableBytesUsed();
		}
	}

	// Pass 2 repeats the exact same presets as pass 1, so stealable memory usage must stay bounded relative to pass 1
	// (no unbounded cluster/AudioFile accumulation across repeated swaps).
	const size_t maxAllowedStealable = stealablePass1 + 65536;
	const bool memBounded = stealablePass2 <= maxAllowedStealable;
	std::fprintf(stderr,
	             "load-all-twice: presets=%zu total_loads=%zu failed=%d sounding=%d silent=%d "
	             "stealable_p1=%zu stealable_p2=%zu overruns=%llu\n",
	             presets.size(), totalLoads, failedLoads, sounding, silent, stealablePass1, stealablePass2,
	             static_cast<unsigned long long>(engine.dmaOverruns()));
	if (!memBounded) {
		std::fprintf(stderr, "FAIL: stealable memory grew from %zu (pass 1) to %zu (pass 2), limit %zu\n",
		             stealablePass1, stealablePass2, maxAllowedStealable);
	}
	return (failedLoads == 0 && engine.dmaOverruns() == 0 && memBounded) ? 0 : 1;
}

int runF7GrainFxSwapTest(const std::string& cardDir, const std::string& tmpDir) {
	core::Engine engine;
	core::Config cfg;
	cfg.cardFolder = cardDir;
	cfg.cardCacheDir = tmpDir + "/cache";
	std::string err;
	if (!engine.boot(cfg, &err)) {
		std::fprintf(stderr, "boot failed: %s\n", err.c_str());
		return 1;
	}
	auto r1 = engine.loadPreset("SYNTHS/TEST/GRAINFX.XML");
	if (!r1.ok) {
		std::fprintf(stderr, "load grainFX preset failed: %s\n", r1.error.c_str());
		return 1;
	}
	std::vector<int32_t> buf(core::kSampleRate / 2 * 2);
	engine.midi({0x90, 60, 100});
	engine.render(buf.data(), core::kSampleRate / 2);
	const double level = channelRms(buf, 4096, core::kSampleRate / 2, 0);
	if (level <= 1e-4) {
		std::fprintf(stderr, "grainFX preset rendered silence (rms=%g)\n", level);
		return 1;
	}
	engine.midi({0x80, 60, 0x40});
	// Swapping destroys the grainFX preset (~ModControllableAudio -> frees GMA-allocated grainFX).
	auto r2 = engine.loadPreset("SYNTHS/GENERATIVE/GEN Sine Sub.XML");
	if (!r2.ok) {
		std::fprintf(stderr, "swap after grainFX failed: %s\n", r2.error.c_str());
		return 1;
	}
	engine.midi({0x90, 60, 100});
	engine.render(buf.data(), core::kSampleRate / 4);
	std::fprintf(stderr, "test_engine --test-f7-grainfx: PASS (overruns=%llu)\n",
	             static_cast<unsigned long long>(engine.dmaOverruns()));
	return engine.dmaOverruns() == 0 ? 0 : 1;
}

int runF7ClusterLoadingSwapTest(const std::string& cardDir, const std::string& tmpDir) {
	core::Engine engine;
	core::Config cfg;
	cfg.cardFolder = cardDir;
	cfg.cardCacheDir = tmpDir + "/cache";
	std::string err;
	if (!engine.boot(cfg, &err)) {
		std::fprintf(stderr, "boot failed: %s\n", err.c_str());
		return 1;
	}
	// Trigger 4 long multi-cluster CC0 samples at once in a Kit, render only 32..128 frames so lookahead clusters
	// are still queued in audioFileManager.loadingQueue (300 us + 40 us/sector read time), then swap away immediately
	// to exercise AudioFileManager::removeReasonFromCluster() -> loadingQueue.erase(&cluster).
	for (int iter = 0; iter < 4; ++iter) {
		auto r1 = engine.loadPreset("KITS/TEST CC0 RISERS.XML");
		if (!r1.ok) {
			std::fprintf(stderr, "load risers kit preset failed: %s\n", r1.error.c_str());
			return 1;
		}
		for (uint8_t note = 36; note < 40; ++note) {
			engine.midi({0x90, note, 100});
		}
		engine.render(nullptr, static_cast<size_t>(32 * (iter + 1)));
		auto r2 = engine.loadPreset("SYNTHS/GENERATIVE/GEN Sine Sub.XML");
		if (!r2.ok) {
			std::fprintf(stderr, "swap away from risers kit failed: %s\n", r2.error.c_str());
			return 1;
		}
		engine.render(nullptr, 256);
	}
	std::fprintf(stderr, "test_engine --test-f7-cluster: PASS (overruns=%llu)\n",
	             static_cast<unsigned long long>(engine.dmaOverruns()));
	return engine.dmaOverruns() == 0 ? 0 : 1;
}

} // namespace

namespace deluge::engine::platform {
[[noreturn]] void handleFreeze(const char* code);
}

int main(int argc, char** argv) {
	int status = 2;
	if (argc == 3 && std::strcmp(argv[1], "--unit-pure") == 0) {
		status = runPureTests(argv[2]);
	}
	else if (argc == 4 && std::strcmp(argv[1], "--unit-engine") == 0) {
		status = runEngineTests(argv[2], argv[3]);
	}
	else if (argc == 4 && std::strcmp(argv[1], "--test-freeze") == 0) {
		core::Engine engine;
		core::Config cfg;
		cfg.cardFolder = argv[2];
		cfg.cardCacheDir = std::string(argv[3]) + "/cache";
		cfg.callbacks.onFreeze = [](std::string_view code, std::string_view loaded, std::string_view bt) {
			std::fprintf(stderr, "ENGINE_FREEZE_CB code=%.*s loaded=%.*s bt_len=%zu\n", static_cast<int>(code.size()),
			             code.data(), static_cast<int>(loaded.size()), loaded.data(), bt.size());
			std::fflush(stderr);
		};
		std::string err;
		if (!engine.boot(cfg, &err)) {
			std::fprintf(stderr, "boot failed: %s\n", err.c_str());
			status = 2;
		}
		else {
			auto res = engine.loadPreset("SYNTHS/GENERATIVE/GEN Sine Sub.XML");
			if (!res.ok) {
				std::fprintf(stderr, "loadPreset failed: %s\n", res.error.c_str());
				status = 2;
			}
			else {
				deluge::engine::platform::handleFreeze("E999");
			}
		}
	}
	else if (argc == 4 && std::strcmp(argv[1], "--load-all-twice") == 0) {
		status = runLoadAllTwice(argv[2], argv[3]);
	}
	else if (argc == 4 && std::strcmp(argv[1], "--test-f7-grainfx") == 0) {
		status = runF7GrainFxSwapTest(argv[2], argv[3]);
	}
	else if (argc == 4 && std::strcmp(argv[1], "--test-f7-cluster") == 0) {
		status = runF7ClusterLoadingSwapTest(argv[2], argv[3]);
	}
	else {
		std::fprintf(stderr, "usage: test_engine --unit-pure TMP | --unit-engine KIT_CARD TMP | "
		                     "--test-freeze PACK TMP | --load-all-twice CARD CACHE | "
		                     "--test-f7-grainfx CARD TMP | --test-f7-cluster CARD TMP\n");
	}
	std::fflush(nullptr);
	std::_Exit(status);
}
