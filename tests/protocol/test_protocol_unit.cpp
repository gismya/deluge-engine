// C++ unit tests for protocol framing, RequestHandler dispatch, and serveClientFd (E10, spec §7.1, §7.2).

#include "server/framing.h"
#include "server/handler.h"
#include "server/server.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <sys/socket.h>
#include <thread>
#include <unistd.h>
#include <vector>

namespace srv = deluge::engine::server;
namespace epb = deluge::engine::proto;

namespace {

int gFailures = 0;

#define CHECK(cond)                                                                                                    \
	do {                                                                                                               \
		if (!(cond)) {                                                                                                 \
			std::fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);                                       \
			++gFailures;                                                                                               \
		}                                                                                                              \
	} while (0)

void testLengthEncoding() {
	uint8_t buf[4];
	srv::encodeLengthLE(0x12345678u, buf);
	CHECK(buf[0] == 0x78 && buf[1] == 0x56 && buf[2] == 0x34 && buf[3] == 0x12);
	CHECK(srv::decodeLengthLE(buf) == 0x12345678u);

	srv::encodeLengthLE(0u, buf);
	CHECK(srv::decodeLengthLE(buf) == 0u);
	srv::encodeLengthLE(srv::kMaxFrameBytes, buf);
	CHECK(srv::decodeLengthLE(buf) == srv::kMaxFrameBytes);
}

void testFrameBufferChunkedAndOversized() {
	srv::FrameBuffer fb;
	std::string out;
	CHECK(fb.next(out) == srv::FrameBuffer::Status::NeedMore);

	// Feed a 5-byte frame 1 byte at a time.
	uint8_t raw[9] = {5, 0, 0, 0, 'h', 'e', 'l', 'l', 'o'};
	for (int i = 0; i < 8; ++i) {
		fb.append(&raw[i], 1);
		CHECK(fb.next(out) == srv::FrameBuffer::Status::NeedMore);
	}
	fb.append(&raw[8], 1);
	CHECK(fb.next(out) == srv::FrameBuffer::Status::Frame);
	CHECK(out == "hello");
	CHECK(fb.bufferedBytes() == 0);

	// Zero-length frame works.
	uint8_t zero[4] = {0, 0, 0, 0};
	fb.append(zero, 4);
	CHECK(fb.next(out) == srv::FrameBuffer::Status::Frame);
	CHECK(out.empty());

	// Frame exceeding 16 MiB is rejected cleanly without waiting for payload bytes.
	uint8_t tooBig[4];
	srv::encodeLengthLE(srv::kMaxFrameBytes + 1u, tooBig);
	fb.append(tooBig, 4);
	CHECK(fb.next(out) == srv::FrameBuffer::Status::FrameTooLarge);
}

void testSocketpairProtoRoundTrip() {
	int fds[2];
	CHECK(::socketpair(AF_UNIX, SOCK_STREAM, 0, fds) == 0);

	epb::ToEngine sent;
	sent.mutable_set_card()->set_folder("/cards/cc0");
	CHECK(srv::writeProtoFrame(fds[0], sent));

	epb::ToEngine got;
	CHECK(srv::readProtoFrame(fds[1], got) == srv::ReadStatus::Ok);
	CHECK(got.kind_case() == epb::ToEngine::kSetCard);
	CHECK(got.set_card().folder() == "/cards/cc0");

	::close(fds[0]);
	CHECK(srv::readProtoFrame(fds[1], got) == srv::ReadStatus::Eof);
	::close(fds[1]);
}

class CustomHandler final : public srv::RequestHandler {
public:
	std::vector<std::string> capabilities() const override { return {"pieces", "render"}; }
	srv::HeartbeatStats heartbeatStats() const override { return {7, 0.25f, 2}; }

	void handle(const epb::ToEngine& msg, srv::MessageSender& sender) override {
		if (msg.kind_case() == epb::ToEngine::kSetCard) {
			epb::FromEngine reply;
			reply.mutable_card_status()->mutable_ready();
			sender.send(reply);
			return;
		}
		srv::RequestHandler::handle(msg, sender);
	}

	void onShutdown() override { ++shutdownCount; }

	int shutdownCount = 0;
};

void testServeLoopAndExtensionSeam() {
	int fds[2];
	CHECK(::socketpair(AF_UNIX, SOCK_STREAM, 0, fds) == 0);

	srv::ServerConfig cfg;
	cfg.engineVersion = "1.3.0-engine-test";
	cfg.firmwareCommit = "deadbeef";
	cfg.heartbeatInterval = std::chrono::milliseconds(25);
	CustomHandler handler;

	int serverRc = -1;
	std::thread serverThread([&]() { serverRc = srv::serveClientFd(fds[0], cfg, handler); });

	// 1. First message is Hello with custom capabilities.
	epb::FromEngine msg;
	CHECK(srv::readProtoFrame(fds[1], msg) == srv::ReadStatus::Ok);
	CHECK(msg.kind_case() == epb::FromEngine::kHello);
	CHECK(msg.hello().protocol_version() == epb::PROTOCOL_VERSION_CURRENT);
	CHECK(msg.hello().engine_version() == "1.3.0-engine-test");
	CHECK(msg.hello().firmware_commit() == "deadbeef");
	CHECK(msg.hello().capabilities_size() == 2);
	CHECK(msg.hello().capabilities(0) == "pieces");

	// 2. Heartbeat reflects handler.heartbeatStats().
	CHECK(srv::readProtoFrame(fds[1], msg) == srv::ReadStatus::Ok);
	CHECK(msg.kind_case() == epb::FromEngine::kHeartbeat);
	CHECK(msg.heartbeat().voices() == 7);
	CHECK(msg.heartbeat().underruns() == 2);

	// 3. Handled message (SetCard) routes to CustomHandler -> CardStatus.ready.
	epb::ToEngine setCard;
	setCard.mutable_set_card()->set_folder("/tmp/card");
	CHECK(srv::writeProtoFrame(fds[1], setCard));
	do {
		CHECK(srv::readProtoFrame(fds[1], msg) == srv::ReadStatus::Ok);
	} while (msg.kind_case() == epb::FromEngine::kHeartbeat);
	CHECK(msg.kind_case() == epb::FromEngine::kCardStatus);
	CHECK(msg.card_status().state_case() == epb::CardStatus::kReady);

	// 4. Unhandled message falls back to ErrorReply naming the command.
	epb::ToEngine play;
	play.mutable_play()->set_wav_path("/tmp/a.wav");
	CHECK(srv::writeProtoFrame(fds[1], play));
	do {
		CHECK(srv::readProtoFrame(fds[1], msg) == srv::ReadStatus::Ok);
	} while (msg.kind_case() == epb::FromEngine::kHeartbeat);
	CHECK(msg.kind_case() == epb::FromEngine::kError);
	CHECK(msg.error().command() == "play");

	// 5. Malformed protobuf bytes get an ErrorReply and keep the connection alive.
	CHECK(srv::writeFrame(fds[1], std::string("\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff", 11)));
	do {
		CHECK(srv::readProtoFrame(fds[1], msg) == srv::ReadStatus::Ok);
	} while (msg.kind_case() == epb::FromEngine::kHeartbeat);
	CHECK(msg.kind_case() == epb::FromEngine::kError);
	CHECK(msg.error().command() == "parse");

	// 5b. Empty ToEngine (unset oneof) gets an ErrorReply naming "unknown".
	epb::ToEngine empty;
	CHECK(srv::writeProtoFrame(fds[1], empty));
	do {
		CHECK(srv::readProtoFrame(fds[1], msg) == srv::ReadStatus::Ok);
	} while (msg.kind_case() == epb::FromEngine::kHeartbeat);
	CHECK(msg.kind_case() == epb::FromEngine::kError);
	CHECK(msg.error().command() == "unknown");

	// 6. Shutdown cleanly terminates serveClientFd and calls onShutdown().
	epb::ToEngine shutdown;
	shutdown.mutable_shutdown();
	CHECK(srv::writeProtoFrame(fds[1], shutdown));

	serverThread.join();
	::close(fds[0]);
	::close(fds[1]);

	CHECK(serverRc == 0);
	CHECK(handler.shutdownCount == 1);
}

void testFormatTrace() {
	epb::FromEngine msg;
	msg.mutable_hello()->set_protocol_version(1);
	msg.mutable_hello()->set_engine_version("v1");
	std::string text = srv::formatTrace(msg);
	CHECK(text.find("hello") != std::string::npos);
	CHECK(text.find("protocol_version: 1") != std::string::npos);
	CHECK(text.find('\n') == std::string::npos);
}

} // namespace

int main() {
	testLengthEncoding();
	testFrameBufferChunkedAndOversized();
	testSocketpairProtoRoundTrip();
	testServeLoopAndExtensionSeam();
	testFormatTrace();
	if (gFailures != 0) {
		std::fprintf(stderr, "test_protocol_unit: %d failure(s)\n", gFailures);
		return 1;
	}
	std::fprintf(stderr, "test_protocol_unit: PASS\n");
	return 0;
}
