#include "server/framing.h"

#include <cerrno>
#include <cstring>
#include <google/protobuf/message.h>
#include <google/protobuf/message_lite.h>
#include <google/protobuf/text_format.h>
#include <poll.h>
#include <unistd.h>

namespace deluge::engine::server {

void encodeLengthLE(uint32_t length, uint8_t out[4]) {
	out[0] = static_cast<uint8_t>(length & 0xFFu);
	out[1] = static_cast<uint8_t>((length >> 8) & 0xFFu);
	out[2] = static_cast<uint8_t>((length >> 16) & 0xFFu);
	out[3] = static_cast<uint8_t>((length >> 24) & 0xFFu);
}

uint32_t decodeLengthLE(const uint8_t in[4]) {
	return static_cast<uint32_t>(in[0]) | (static_cast<uint32_t>(in[1]) << 8)
	       | (static_cast<uint32_t>(in[2]) << 16) | (static_cast<uint32_t>(in[3]) << 24);
}

bool writeAll(int fd, const void* data, size_t size) {
	const auto* bytes = static_cast<const uint8_t*>(data);
	size_t written = 0;
	while (written < size) {
		ssize_t n = ::write(fd, bytes + written, size - written);
		if (n > 0) {
			written += static_cast<size_t>(n);
			continue;
		}
		if (n < 0 && errno == EINTR) {
			continue;
		}
		if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
			struct pollfd pfd {};
			pfd.fd = fd;
			pfd.events = POLLOUT;
			int pr = ::poll(&pfd, 1, 5000);
			if (pr <= 0 || (pfd.revents & (POLLERR | POLLHUP | POLLNVAL))) {
				return false;
			}
			continue;
		}
		return false;
	}
	return true;
}

bool writeFrame(int fd, const std::string& payload) {
	if (payload.size() > kMaxFrameBytes) {
		return false;
	}
	uint8_t header[4];
	encodeLengthLE(static_cast<uint32_t>(payload.size()), header);
	if (!writeAll(fd, header, sizeof(header))) {
		return false;
	}
	if (!payload.empty() && !writeAll(fd, payload.data(), payload.size())) {
		return false;
	}
	return true;
}

namespace {

ReadStatus readExact(int fd, void* dst, size_t size) {
	auto* out = static_cast<uint8_t*>(dst);
	size_t got = 0;
	while (got < size) {
		ssize_t n = ::read(fd, out + got, size - got);
		if (n > 0) {
			got += static_cast<size_t>(n);
			continue;
		}
		if (n == 0) {
			return ReadStatus::Eof;
		}
		if (errno == EINTR) {
			continue;
		}
		if (errno == EAGAIN || errno == EWOULDBLOCK) {
			struct pollfd pfd {};
			pfd.fd = fd;
			pfd.events = POLLIN;
			int pr = ::poll(&pfd, 1, 5000);
			if (pr <= 0) {
				return ReadStatus::IoError;
			}
			continue;
		}
		return ReadStatus::IoError;
	}
	return ReadStatus::Ok;
}

} // namespace

ReadStatus readFrame(int fd, std::string& out) {
	uint8_t header[4];
	ReadStatus st = readExact(fd, header, sizeof(header));
	if (st != ReadStatus::Ok) {
		return st;
	}
	const uint32_t len = decodeLengthLE(header);
	if (len > kMaxFrameBytes) {
		return ReadStatus::FrameTooLarge;
	}
	out.resize(len);
	if (len == 0) {
		return ReadStatus::Ok;
	}
	return readExact(fd, out.data(), len);
}

bool writeProtoFrame(int fd, const google::protobuf::MessageLite& msg) {
	std::string encoded;
	if (!msg.SerializeToString(&encoded)) {
		return false;
	}
	return writeFrame(fd, encoded);
}

ReadStatus readProtoFrame(int fd, google::protobuf::MessageLite& msg) {
	std::string encoded;
	ReadStatus st = readFrame(fd, encoded);
	if (st != ReadStatus::Ok) {
		return st;
	}
	if (!msg.ParseFromString(encoded)) {
		return ReadStatus::ParseError;
	}
	return ReadStatus::Ok;
}

void FrameBuffer::append(const uint8_t* data, size_t size) {
	if (size == 0) {
		return;
	}
	buf_.insert(buf_.end(), data, data + size);
}

FrameBuffer::Status FrameBuffer::next(std::string& payloadOut) {
	const size_t avail = buf_.size() - offset_;
	if (avail < 4) {
		return Status::NeedMore;
	}
	const uint32_t len = decodeLengthLE(buf_.data() + offset_);
	if (len > kMaxFrameBytes) {
		return Status::FrameTooLarge;
	}
	if (avail < 4u + len) {
		return Status::NeedMore;
	}
	payloadOut.assign(reinterpret_cast<const char*>(buf_.data() + offset_ + 4), len);
	offset_ += 4u + len;
	compactIfNeeded();
	return Status::Frame;
}

void FrameBuffer::clear() {
	buf_.clear();
	offset_ = 0;
}

void FrameBuffer::compactIfNeeded() {
	if (offset_ == buf_.size()) {
		buf_.clear();
		offset_ = 0;
	}
	else if (offset_ >= 65536 && offset_ * 2 >= buf_.size()) {
		buf_.erase(buf_.begin(), buf_.begin() + static_cast<std::ptrdiff_t>(offset_));
		offset_ = 0;
	}
}

std::string formatTrace(const google::protobuf::Message& msg) {
	// Use the non-inline TextFormat::PrintToString inside libprotobuf rather than constructing
	// TextFormat::Printer in caller TUs: Printer owns absl::flat_hash_map members whose layout
	// differs when caller TUs build under ASan against Homebrew's non-ASan libabsl/libprotobuf.
	std::string raw;
	if (!google::protobuf::TextFormat::PrintToString(msg, &raw)) {
		return "<format-error>";
	}
	// TextFormat escapes literal newlines inside strings as "\\n", so raw '\n' is always structural
	// whitespace. Collapse structural whitespace outside quotes so each traced frame is one line
	// while preserving spaces inside string literals.
	std::string out;
	out.reserve(raw.size());
	bool inQuotes = false;
	bool escaped = false;
	bool lastSpace = false;
	for (char c : raw) {
		if (inQuotes) {
			out.push_back(c);
			if (escaped) {
				escaped = false;
			}
			else if (c == '\\') {
				escaped = true;
			}
			else if (c == '"') {
				inQuotes = false;
			}
			lastSpace = false;
			continue;
		}
		if (c == '"') {
			inQuotes = true;
			out.push_back(c);
			lastSpace = false;
		}
		else if (c == '\n' || c == '\r' || c == ' ') {
			if (!out.empty() && !lastSpace) {
				out.push_back(' ');
				lastSpace = true;
			}
		}
		else {
			out.push_back(c);
			lastSpace = false;
		}
	}
	if (!out.empty() && out.back() == ' ') {
		out.pop_back();
	}
	return out;
}

} // namespace deluge::engine::server
