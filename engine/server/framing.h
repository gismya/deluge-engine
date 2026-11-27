// Length-prefixed protobuf framing over Unix domain sockets and pipes (spec §7.1).
// Each frame is a 4-byte little-endian unsigned length (<= 16 MiB) followed by serialized protobuf bytes.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace google::protobuf {
class Message;
class MessageLite;
} // namespace google::protobuf

namespace deluge::engine::server {

constexpr uint32_t kMaxFrameBytes = 16u * 1024u * 1024u; // spec §7.1

enum class ReadStatus {
	Ok,
	Eof,
	FrameTooLarge,
	ParseError,
	IoError,
};

void encodeLengthLE(uint32_t length, uint8_t out[4]);
uint32_t decodeLengthLE(const uint8_t in[4]);

// Writes all `size` bytes to `fd`, retrying on EINTR and waiting via poll(POLLOUT) on EAGAIN/EWOULDBLOCK.
bool writeAll(int fd, const void* data, size_t size);

// Writes a 4-byte LE length prefix and `payload` to `fd`. Rejects payloads > kMaxFrameBytes.
bool writeFrame(int fd, const std::string& payload);

// Blocking read of one length-prefixed frame from `fd` (for tests and worker stdout pipes).
ReadStatus readFrame(int fd, std::string& out);

bool writeProtoFrame(int fd, const google::protobuf::MessageLite& msg);
ReadStatus readProtoFrame(int fd, google::protobuf::MessageLite& msg);

// Incremental frame decoder for non-blocking poll() loops.
class FrameBuffer {
public:
	enum class Status {
		NeedMore,
		Frame,
		FrameTooLarge,
	};

	void append(const uint8_t* data, size_t size);
	Status next(std::string& payloadOut);
	void clear();
	size_t bufferedBytes() const { return buf_.size() - offset_; }

private:
	void compactIfNeeded();

	std::vector<uint8_t> buf_;
	size_t offset_ = 0;
};

// Formats a protobuf message as single-line protobuf text format for `--trace` (spec §7.1).
std::string formatTrace(const google::protobuf::Message& msg);

} // namespace deluge::engine::server
