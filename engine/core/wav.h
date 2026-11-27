// 44.1 kHz stereo 24-bit PCM WAV writer (E4, spec §3.9 & §6.2).
// Pure C++ header: includes no firmware or protobuf headers.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

namespace deluge::engine::core {

// Converts signed 32-bit interleaved stereo PCM (from the Deluge's SSI TX ring) to a 24-bit signed little-endian
// stereo WAV file. Takes the top 24 bits of each 32-bit sample (matching the Deluge DAC word).
bool writeWav24(const std::string& path, const int32_t* interleavedStereo, size_t numFrames,
                uint32_t sampleRate = 44100, std::string* errorOut = nullptr);

} // namespace deluge::engine::core
