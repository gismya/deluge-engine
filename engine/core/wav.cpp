#include "core/wav.h"

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <limits>
#include <vector>

namespace deluge::engine::core {

namespace {

void writeU16LE(uint8_t* dst, uint16_t v) {
	dst[0] = static_cast<uint8_t>(v & 0xFFu);
	dst[1] = static_cast<uint8_t>((v >> 8) & 0xFFu);
}

void writeU32LE(uint8_t* dst, uint32_t v) {
	dst[0] = static_cast<uint8_t>(v & 0xFFu);
	dst[1] = static_cast<uint8_t>((v >> 8) & 0xFFu);
	dst[2] = static_cast<uint8_t>((v >> 16) & 0xFFu);
	dst[3] = static_cast<uint8_t>((v >> 24) & 0xFFu);
}

bool setError(std::string* errorOut, const std::string& msg) {
	if (errorOut != nullptr) {
		*errorOut = msg;
	}
	return false;
}

} // namespace

bool writeWav24(const std::string& path, const int32_t* interleavedStereo, size_t numFrames, uint32_t sampleRate,
                std::string* errorOut) {
	if (sampleRate == 0) {
		return setError(errorOut, "sampleRate must be non-zero");
	}
	if (numFrames > 0 && interleavedStereo == nullptr) {
		return setError(errorOut, "null audio buffer for non-zero frame count");
	}
	constexpr uint16_t kChannels = 2;
	constexpr uint16_t kBitsPerSample = 24;
	constexpr uint16_t kBytesPerSample = kBitsPerSample / 8;
	constexpr uint16_t kBlockAlign = kChannels * kBytesPerSample; // 6 bytes per stereo frame

	const uint64_t dataBytes64 = static_cast<uint64_t>(numFrames) * kBlockAlign;
	if (dataBytes64 > std::numeric_limits<uint32_t>::max() - 36u) {
		return setError(errorOut, "WAV payload exceeds 4 GiB RIFF limit");
	}
	const uint32_t dataBytes = static_cast<uint32_t>(dataBytes64);
	const uint32_t byteRate = sampleRate * kBlockAlign;

	uint8_t header[44];
	std::memcpy(header + 0, "RIFF", 4);
	writeU32LE(header + 4, 36u + dataBytes);
	std::memcpy(header + 8, "WAVEfmt ", 8);
	writeU32LE(header + 16, 16u); // PCM fmt chunk size
	writeU16LE(header + 20, 1u);  // AudioFormat = PCM
	writeU16LE(header + 22, kChannels);
	writeU32LE(header + 24, sampleRate);
	writeU32LE(header + 28, byteRate);
	writeU16LE(header + 32, kBlockAlign);
	writeU16LE(header + 34, kBitsPerSample);
	std::memcpy(header + 36, "data", 4);
	writeU32LE(header + 40, dataBytes);

	FILE* f = std::fopen(path.c_str(), "wb");
	if (f == nullptr) {
		return setError(errorOut, "failed to open " + path + ": " + std::strerror(errno));
	}

	if (std::fwrite(header, 1, sizeof(header), f) != sizeof(header)) {
		const int err = errno;
		std::fclose(f);
		return setError(errorOut, "failed to write WAV header to " + path + ": " + std::strerror(err));
	}

	// Stream out in 4096-frame (24 KiB) chunks to keep memory overhead minimal for long renders.
	constexpr size_t kChunkFrames = 4096;
	std::vector<uint8_t> chunk(kChunkFrames * kBlockAlign);
	size_t writtenFrames = 0;
	while (writtenFrames < numFrames) {
		const size_t batch = std::min(kChunkFrames, numFrames - writtenFrames);
		uint8_t* dst = chunk.data();
		const int32_t* src = interleavedStereo + writtenFrames * kChannels;
		for (size_t i = 0; i < batch * kChannels; ++i) {
			// Deluge's SSI TX ring holds full-scale signed 32-bit PCM (already dithered in AudioEngine).
			// The top 24 bits match the 24-bit DAC sample word.
			const uint32_t u = static_cast<uint32_t>(src[i]) >> 8;
			dst[0] = static_cast<uint8_t>(u & 0xFFu);
			dst[1] = static_cast<uint8_t>((u >> 8) & 0xFFu);
			dst[2] = static_cast<uint8_t>((u >> 16) & 0xFFu);
			dst += 3;
		}
		const size_t bytesToWrite = batch * kBlockAlign;
		if (std::fwrite(chunk.data(), 1, bytesToWrite, f) != bytesToWrite) {
			const int err = errno;
			std::fclose(f);
			return setError(errorOut, "failed to write WAV samples to " + path + ": " + std::strerror(err));
		}
		writtenFrames += batch;
	}

	if (std::fclose(f) != 0) {
		return setError(errorOut, "failed to close " + path + ": " + std::strerror(errno));
	}
	return true;
}

} // namespace deluge::engine::core
