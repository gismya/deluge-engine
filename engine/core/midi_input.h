// Standard MIDI File (SMF format 0/1) and `--notes` list parsers for `deluge-engine render` (E4, spec §3.9).
// Pure C++ header: includes no firmware or protobuf headers.
#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace deluge::engine::core {

struct TimedMidiEvent {
	double timeSeconds = 0.0;
	std::vector<uint8_t> bytes; // 1..3-byte channel voice message
};

struct MidiSequence {
	std::vector<TimedMidiEvent> events; // stably sorted by timeSeconds
	double durationSeconds = 0.0;       // time of the last event (0 if empty)
};

// Parses a Standard MIDI File (format 0 or 1, PPQN or SMPTE division, tempo map, running status).
// Keeps channel voice messages (0x80..0xEF); SysEx and non-tempo meta events are skipped.
bool parseMidiFile(const std::string& path, MidiSequence* out, std::string* errorOut = nullptr);

// Parses a Standard MIDI File from raw bytes in memory (unit-test seam).
bool parseMidiBytes(const uint8_t* data, size_t size, MidiSequence* out, std::string* errorOut = nullptr);

// Parses `--notes LIST`:
//   ITEM[,ITEM...]
//   ITEM := PITCH[+PITCH...][@START_S][:DUR_S[:VEL]]
//   PITCH := 0..127 or note name like C4, C#3, Eb2, F#5 (C4 = 60, C-1 = 0, G9 = 127)
//   START_S (optional): start time in seconds; if omitted, starts sequentially when the previous item ends
//   DUR_S   (optional): hold duration in seconds (default 1.0)
//   VEL     (optional): MIDI velocity 1..127 (default 100)
// Channel defaults to 0 (MIDI channel 1); single-preset MIDI follow accepts any channel.
bool parseNotesList(std::string_view spec, MidiSequence* out, std::string* errorOut = nullptr);

} // namespace deluge::engine::core
