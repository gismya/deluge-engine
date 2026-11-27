#include "core/midi_input.h"

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <charconv>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

namespace deluge::engine::core {

namespace {

bool fail(std::string* errorOut, const std::string& msg) {
	if (errorOut != nullptr) {
		*errorOut = msg;
	}
	return false;
}

std::string_view trim(std::string_view s) {
	while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) {
		s.remove_prefix(1);
	}
	while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) {
		s.remove_suffix(1);
	}
	return s;
}

bool parseDoubleStrict(std::string_view sv, double* out) {
	sv = trim(sv);
	if (sv.empty()) {
		return false;
	}
	std::string tmp(sv);
	char* end = nullptr;
	errno = 0;
	const double v = std::strtod(tmp.c_str(), &end);
	if (errno != 0 || end != tmp.c_str() + tmp.size() || !std::isfinite(v)) {
		return false;
	}
	*out = v;
	return true;
}

bool parseIntStrict(std::string_view sv, int* out) {
	sv = trim(sv);
	if (sv.empty()) {
		return false;
	}
	int v = 0;
	const char* begin = sv.data();
	const char* end = sv.data() + sv.size();
	auto [ptr, ec] = std::from_chars(begin, end, v);
	if (ec != std::errc{} || ptr != end) {
		return false;
	}
	*out = v;
	return true;
}

// Parses a MIDI pitch: either 0..127 or a note name like C4, C#3, Db3, Eb2, F#5 (C4 = 60, C-1 = 0, G9 = 127).
bool parsePitch(std::string_view sv, uint8_t* out) {
	sv = trim(sv);
	if (sv.empty()) {
		return false;
	}
	int numeric = 0;
	if (parseIntStrict(sv, &numeric)) {
		if (numeric < 0 || numeric > 127) {
			return false;
		}
		*out = static_cast<uint8_t>(numeric);
		return true;
	}

	const char letter = static_cast<char>(std::toupper(static_cast<unsigned char>(sv[0])));
	int semitone = -1;
	switch (letter) {
	case 'C':
		semitone = 0;
		break;
	case 'D':
		semitone = 2;
		break;
	case 'E':
		semitone = 4;
		break;
	case 'F':
		semitone = 5;
		break;
	case 'G':
		semitone = 7;
		break;
	case 'A':
		semitone = 9;
		break;
	case 'B':
		semitone = 11;
		break;
	default:
		return false;
	}

	size_t idx = 1;
	if (idx < sv.size()) {
		if (sv[idx] == '#') {
			semitone += 1;
			++idx;
		}
		else if (sv[idx] == 'b' || sv[idx] == 'B') {
			semitone -= 1;
			++idx;
		}
	}

	int octave = 0;
	if (!parseIntStrict(sv.substr(idx), &octave)) {
		return false;
	}
	const int midiNote = (octave + 1) * 12 + semitone;
	if (midiNote < 0 || midiNote > 127) {
		return false;
	}
	*out = static_cast<uint8_t>(midiNote);
	return true;
}

uint16_t readU16BE(const uint8_t* p) {
	return static_cast<uint16_t>((static_cast<uint16_t>(p[0]) << 8) | p[1]);
}

uint32_t readU32BE(const uint8_t* p) {
	return (static_cast<uint32_t>(p[0]) << 24) | (static_cast<uint32_t>(p[1]) << 16)
	       | (static_cast<uint32_t>(p[2]) << 8) | p[3];
}

bool readVlq(const uint8_t* data, size_t end, size_t* pos, uint32_t* out) {
	uint32_t value = 0;
	for (int i = 0; i < 4; ++i) {
		if (*pos >= end) {
			return false;
		}
		const uint8_t b = data[(*pos)++];
		value = (value << 7) | (b & 0x7Fu);
		if ((b & 0x80u) == 0) {
			*out = value;
			return true;
		}
	}
	return false; // VLQ longer than 4 bytes
}

size_t channelMessageDataBytes(uint8_t status) {
	switch (status & 0xF0u) {
	case 0x80: // Note Off
	case 0x90: // Note On
	case 0xA0: // Polyphonic Aftertouch
	case 0xB0: // Control Change
	case 0xE0: // Pitch Bend
		return 2;
	case 0xC0: // Program Change
	case 0xD0: // Channel Pressure
		return 1;
	default:
		return 0;
	}
}

struct RawTickEvent {
	uint64_t tick = 0;
	size_t order = 0;
	std::vector<uint8_t> bytes;
};

struct TempoChange {
	uint64_t tick = 0;
	size_t order = 0;
	uint32_t usPerQuarter = 500000;
};

} // namespace

bool parseMidiFile(const std::string& path, MidiSequence* out, std::string* errorOut) {
	std::ifstream f(path, std::ios::binary);
	if (!f) {
		return fail(errorOut, "failed to open MIDI file " + path + ": " + std::strerror(errno));
	}
	std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
	if (f.bad()) {
		return fail(errorOut, "failed to read MIDI file " + path);
	}
	return parseMidiBytes(bytes.data(), bytes.size(), out, errorOut);
}

bool parseMidiBytes(const uint8_t* data, size_t size, MidiSequence* out, std::string* errorOut) {
	if (out == nullptr) {
		return fail(errorOut, "null MidiSequence output pointer");
	}
	*out = MidiSequence{};
	if (data == nullptr || size < 14) {
		return fail(errorOut, "MIDI file too short for MThd header");
	}
	if (std::memcmp(data, "MThd", 4) != 0) {
		return fail(errorOut, "MIDI file missing MThd header");
	}
	const uint32_t headerLen = readU32BE(data + 4);
	if (headerLen < 6 || 8u + headerLen > size) {
		return fail(errorOut, "invalid MThd header length");
	}
	const uint16_t format = readU16BE(data + 8);
	const uint16_t numTracks = readU16BE(data + 10);
	const uint16_t division = readU16BE(data + 12);
	if (format > 1) {
		return fail(errorOut, "unsupported SMF format " + std::to_string(format) + " (only format 0 and 1 supported)");
	}
	if (division == 0) {
		return fail(errorOut, "MIDI file has zero time division");
	}

	const bool isSmpte = (division & 0x8000u) != 0;
	double smpteTicksPerSecond = 0.0;
	if (isSmpte) {
		const int8_t negFps = static_cast<int8_t>((division >> 8) & 0xFFu);
		const int fpsCode = -static_cast<int>(negFps);
		double fps = static_cast<double>(fpsCode);
		if (fpsCode == 29) {
			fps = 29.97;
		}
		const uint8_t subframes = static_cast<uint8_t>(division & 0xFFu);
		if (fps <= 0.0 || subframes == 0) {
			return fail(errorOut, "invalid SMPTE division in MIDI header");
		}
		smpteTicksPerSecond = fps * static_cast<double>(subframes);
	}

	size_t pos = 8u + headerLen;
	std::vector<RawTickEvent> rawEvents;
	std::vector<TempoChange> tempos;
	size_t globalOrder = 0;
	uint16_t tracksParsed = 0;

	while (pos + 8 <= size && tracksParsed < numTracks) {
		const char* chunkId = reinterpret_cast<const char*>(data + pos);
		const uint32_t chunkLen = readU32BE(data + pos + 4);
		pos += 8;
		if (chunkLen > size - pos) {
			return fail(errorOut, "truncated MIDI chunk");
		}
		const size_t chunkEnd = pos + chunkLen;
		if (std::memcmp(chunkId, "MTrk", 4) != 0) {
			pos = chunkEnd;
			continue;
		}
		++tracksParsed;

		uint64_t tick = 0;
		uint8_t runningStatus = 0;
		size_t tpos = pos;
		while (tpos < chunkEnd) {
			uint32_t delta = 0;
			if (!readVlq(data, chunkEnd, &tpos, &delta)) {
				return fail(errorOut, "invalid variable-length delta time in MIDI track");
			}
			tick += delta;
			if (tpos >= chunkEnd) {
				return fail(errorOut, "unexpected end of MIDI track after delta time");
			}

			uint8_t status = data[tpos];
			if ((status & 0x80u) != 0) {
				++tpos;
				if (status < 0xF0u) {
					runningStatus = status;
				}
				else if (status < 0xF8u) {
					runningStatus = 0;
				}
			}
			else {
				if (runningStatus == 0) {
					return fail(errorOut, "MIDI data byte without running status");
				}
				status = runningStatus;
			}

			if (status == 0xFFu) {
				// Meta event: FF <type> <vlq len> <bytes>
				if (tpos >= chunkEnd) {
					return fail(errorOut, "truncated MIDI meta event");
				}
				const uint8_t metaType = data[tpos++];
				uint32_t metaLen = 0;
				if (!readVlq(data, chunkEnd, &tpos, &metaLen) || metaLen > chunkEnd - tpos) {
					return fail(errorOut, "truncated MIDI meta event payload");
				}
				if (metaType == 0x51u && metaLen == 3u) {
					const uint32_t usPerQn = (static_cast<uint32_t>(data[tpos]) << 16)
					                         | (static_cast<uint32_t>(data[tpos + 1]) << 8)
					                         | static_cast<uint32_t>(data[tpos + 2]);
					if (usPerQn > 0) {
						tempos.push_back(TempoChange{tick, globalOrder++, usPerQn});
					}
				}
				tpos += metaLen;
				if (metaType == 0x2Fu) {
					break; // End of track
				}
			}
			else if (status == 0xF0u || status == 0xF7u) {
				// SysEx event: F0/F7 <vlq len> <bytes>
				uint32_t sysexLen = 0;
				if (!readVlq(data, chunkEnd, &tpos, &sysexLen) || sysexLen > chunkEnd - tpos) {
					return fail(errorOut, "truncated SysEx event in MIDI track");
				}
				tpos += sysexLen;
			}
			else if (status >= 0x80u && status <= 0xEFu) {
				const size_t dataLen = channelMessageDataBytes(status);
				if (dataLen == 0 || dataLen > chunkEnd - tpos) {
					return fail(errorOut, "truncated MIDI channel message");
				}
				RawTickEvent ev;
				ev.tick = tick;
				ev.order = globalOrder++;
				ev.bytes.reserve(1 + dataLen);
				ev.bytes.push_back(status);
				for (size_t i = 0; i < dataLen; ++i) {
					ev.bytes.push_back(static_cast<uint8_t>(data[tpos++] & 0x7Fu));
				}
				rawEvents.push_back(std::move(ev));
			}
			else {
				return fail(errorOut, "unsupported status byte in MIDI track");
			}
		}
		pos = chunkEnd;
	}

	if (tracksParsed == 0) {
		return fail(errorOut, "MIDI file contains no MTrk chunks");
	}

	std::stable_sort(rawEvents.begin(), rawEvents.end(), [](const RawTickEvent& a, const RawTickEvent& b) {
		if (a.tick != b.tick) {
			return a.tick < b.tick;
		}
		return a.order < b.order;
	});
	std::stable_sort(tempos.begin(), tempos.end(), [](const TempoChange& a, const TempoChange& b) {
		if (a.tick != b.tick) {
			return a.tick < b.tick;
		}
		return a.order < b.order;
	});

	out->events.reserve(rawEvents.size());
	if (isSmpte) {
		for (auto& ev : rawEvents) {
			const double t = static_cast<double>(ev.tick) / smpteTicksPerSecond;
			out->events.push_back(TimedMidiEvent{t, std::move(ev.bytes)});
		}
	}
	else {
		const double tpqn = static_cast<double>(division);
		uint64_t curTick = 0;
		double curSec = 0.0;
		uint32_t curUsPerQn = 500000; // default 120 BPM
		size_t tempoIdx = 0;

		for (auto& ev : rawEvents) {
			while (tempoIdx < tempos.size() && tempos[tempoIdx].tick <= ev.tick) {
				if (tempos[tempoIdx].tick > curTick) {
					curSec += static_cast<double>(tempos[tempoIdx].tick - curTick) * (curUsPerQn * 1e-6) / tpqn;
					curTick = tempos[tempoIdx].tick;
				}
				curUsPerQn = tempos[tempoIdx].usPerQuarter;
				++tempoIdx;
			}
			if (ev.tick > curTick) {
				curSec += static_cast<double>(ev.tick - curTick) * (curUsPerQn * 1e-6) / tpqn;
				curTick = ev.tick;
			}
			out->events.push_back(TimedMidiEvent{curSec, std::move(ev.bytes)});
		}
	}

	if (!out->events.empty()) {
		out->durationSeconds = out->events.back().timeSeconds;
	}
	return true;
}

bool parseNotesList(std::string_view spec, MidiSequence* out, std::string* errorOut) {
	if (out == nullptr) {
		return fail(errorOut, "null MidiSequence output pointer");
	}
	*out = MidiSequence{};
	spec = trim(spec);
	if (spec.empty()) {
		return fail(errorOut, "--notes list must not be empty");
	}

	struct IndexedEvent {
		double timeSeconds;
		size_t order;
		std::vector<uint8_t> bytes;
	};
	std::vector<IndexedEvent> events;
	size_t order = 0;
	double cursorSeconds = 0.0;

	size_t startPos = 0;
	while (startPos <= spec.size()) {
		size_t comma = spec.find(',', startPos);
		if (comma == std::string_view::npos) {
			comma = spec.size();
		}
		std::string_view item = trim(spec.substr(startPos, comma - startPos));
		startPos = comma + 1;
		if (item.empty()) {
			return fail(errorOut, "empty entry in --notes list");
		}

		// Split item by ':' into [pitchPart[@start], dur?, vel?].
		std::vector<std::string_view> colonParts;
		size_t cpos = 0;
		while (cpos <= item.size()) {
			size_t next = item.find(':', cpos);
			if (next == std::string_view::npos) {
				next = item.size();
			}
			colonParts.push_back(item.substr(cpos, next - cpos));
			cpos = next + 1;
		}
		if (colonParts.size() > 3) {
			return fail(errorOut, "too many ':' fields in note item: " + std::string(item));
		}

		// Parse optional @start on colonParts[0].
		std::string_view pitchGroup = colonParts[0];
		double noteStart = cursorSeconds;
		const size_t atPos = pitchGroup.find('@');
		if (atPos != std::string_view::npos) {
			if (!parseDoubleStrict(pitchGroup.substr(atPos + 1), &noteStart) || noteStart < 0.0) {
				return fail(errorOut, "invalid start time in note item: " + std::string(item));
			}
			pitchGroup = pitchGroup.substr(0, atPos);
		}

		// Parse optional duration (default 1.0 s).
		double duration = 1.0;
		if (colonParts.size() >= 2 && !trim(colonParts[1]).empty()) {
			if (!parseDoubleStrict(colonParts[1], &duration) || duration <= 0.0) {
				return fail(errorOut, "invalid duration in note item: " + std::string(item));
			}
		}

		// Parse optional velocity (default 100, range 1..127).
		int velocity = 100;
		if (colonParts.size() >= 3 && !trim(colonParts[2]).empty()) {
			if (!parseIntStrict(colonParts[2], &velocity) || velocity < 1 || velocity > 127) {
				return fail(errorOut, "invalid velocity (must be 1..127) in note item: " + std::string(item));
			}
		}

		// Parse '+'-separated chord pitches.
		std::vector<uint8_t> pitches;
		size_t ppos = 0;
		while (ppos <= pitchGroup.size()) {
			size_t plus = pitchGroup.find('+', ppos);
			if (plus == std::string_view::npos) {
				plus = pitchGroup.size();
			}
			uint8_t pitch = 0;
			if (!parsePitch(pitchGroup.substr(ppos, plus - ppos), &pitch)) {
				return fail(errorOut, "invalid pitch in note item: " + std::string(item));
			}
			pitches.push_back(pitch);
			ppos = plus + 1;
		}

		for (uint8_t pitch : pitches) {
			events.push_back(IndexedEvent{noteStart, order++, {0x90, pitch, static_cast<uint8_t>(velocity)}});
		}
		const double noteEnd = noteStart + duration;
		for (uint8_t pitch : pitches) {
			events.push_back(IndexedEvent{noteEnd, order++, {0x80, pitch, 0x40}});
		}
		cursorSeconds = std::max(cursorSeconds, noteEnd);
	}

	std::stable_sort(events.begin(), events.end(), [](const IndexedEvent& a, const IndexedEvent& b) {
		if (a.timeSeconds != b.timeSeconds) {
			return a.timeSeconds < b.timeSeconds;
		}
		return a.order < b.order;
	});

	out->events.reserve(events.size());
	for (auto& ev : events) {
		out->events.push_back(TimedMidiEvent{ev.timeSeconds, std::move(ev.bytes)});
	}
	if (!out->events.empty()) {
		out->durationSeconds = out->events.back().timeSeconds;
	}
	return true;
}

} // namespace deluge::engine::core
