#include "server/server.h"
#include "server/framing.h"

#include <algorithm>
#include <atomic>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <mutex>
#include <poll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

namespace deluge::engine::server {

namespace {

std::atomic<bool> gStopRequested{false};

void handleSignal(int) {
	gStopRequested.store(true, std::memory_order_relaxed);
}

void logTrace(const char* direction, const google::protobuf::Message& msg) {
	std::string formatted = formatTrace(msg);
	std::fprintf(stderr, "[trace] %s %s\n", direction, formatted.c_str());
	std::fflush(stderr);
}

class SocketSender final : public MessageSender {
public:
	SocketSender(int fd, bool trace) : fd_(fd), trace_(trace) {}

	bool send(const proto::FromEngine& msg) override {
		std::lock_guard<std::mutex> lock(mu_);
		if (trace_) {
			logTrace("->", msg);
		}
		return writeProtoFrame(fd_, msg);
	}

private:
	int fd_;
	bool trace_;
	std::mutex mu_;
};

class ScopedFd {
public:
	explicit ScopedFd(int fd = -1) : fd_(fd) {}
	~ScopedFd() { reset(); }
	ScopedFd(const ScopedFd&) = delete;
	ScopedFd& operator=(const ScopedFd&) = delete;

	int get() const { return fd_; }
	void reset(int next = -1) {
		if (fd_ >= 0) {
			::close(fd_);
		}
		fd_ = next;
	}

private:
	int fd_;
};

class ScopedSocketFile {
public:
	explicit ScopedSocketFile(std::string path) : path_(std::move(path)) {}
	~ScopedSocketFile() {
		if (!path_.empty()) {
			::unlink(path_.c_str());
		}
	}
	ScopedSocketFile(const ScopedSocketFile&) = delete;
	ScopedSocketFile& operator=(const ScopedSocketFile&) = delete;

private:
	std::string path_;
};

void disableSigpipe(int fd) {
#ifdef SO_NOSIGPIPE
	int one = 1;
	(void)::setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#else
	(void)fd;
#endif
}

} // namespace

int serveClientFd(int clientFd, const ServerConfig& config, RequestHandler& handler) {
	disableSigpipe(clientFd);

	// Put the socket in non-blocking mode so reads never starve Heartbeat emission.
	const int flags = ::fcntl(clientFd, F_GETFL, 0);
	if (flags >= 0) {
		(void)::fcntl(clientFd, F_SETFL, flags | O_NONBLOCK);
	}

	SocketSender sender(clientFd, config.trace);

	// Spec §7.2: first message is always Hello.
	proto::FromEngine helloEnvelope;
	auto* hello = helloEnvelope.mutable_hello();
	hello->set_protocol_version(proto::PROTOCOL_VERSION_CURRENT);
	hello->set_engine_version(config.engineVersion);
	hello->set_firmware_commit(config.firmwareCommit);
	for (const std::string& cap : handler.capabilities()) {
		hello->add_capabilities(cap);
	}
	if (!sender.send(helloEnvelope)) {
		handler.onShutdown();
		return 0;
	}

	const auto interval = std::max(config.heartbeatInterval, std::chrono::milliseconds(1));
	auto nextHeartbeat = std::chrono::steady_clock::now() + interval;

	FrameBuffer rx;
	uint8_t chunk[8192];

	while (!gStopRequested.load(std::memory_order_relaxed)) {
		const auto now = std::chrono::steady_clock::now();
		int timeoutMs = 0;
		if (nextHeartbeat > now) {
			const auto rem = std::chrono::duration_cast<std::chrono::milliseconds>(nextHeartbeat - now);
			timeoutMs = static_cast<int>(std::min<int64_t>(rem.count(), 1000));
			if (timeoutMs == 0) {
				timeoutMs = 1;
			}
		}

		struct pollfd pfd {};
		pfd.fd = clientFd;
		pfd.events = POLLIN;
		const int pr = ::poll(&pfd, 1, timeoutMs);
		if (pr < 0) {
			if (errno == EINTR) {
				continue;
			}
			std::fprintf(stderr, "serve: poll failed: %s\n", std::strerror(errno));
			handler.onShutdown();
			return 1;
		}

		if (pr > 0 && (pfd.revents & (POLLIN | POLLHUP | POLLERR))) {
			bool eof = false;
			while (true) {
				ssize_t n = ::read(clientFd, chunk, sizeof(chunk));
				if (n > 0) {
					rx.append(chunk, static_cast<size_t>(n));
					continue;
				}
				if (n == 0) {
					eof = true;
					break;
				}
				if (errno == EINTR) {
					continue;
				}
				if (errno == EAGAIN || errno == EWOULDBLOCK) {
					break;
				}
				eof = true;
				break;
			}

			std::string payload;
			while (true) {
				const FrameBuffer::Status st = rx.next(payload);
				if (st == FrameBuffer::Status::NeedMore) {
					break;
				}
				if (st == FrameBuffer::Status::FrameTooLarge) {
					std::fprintf(stderr, "serve: rejecting frame larger than %u bytes\n", kMaxFrameBytes);
					(void)sender.send(makeErrorReply("frame", "frame exceeds 16 MiB limit"));
					handler.onShutdown();
					return 0;
				}

				proto::ToEngine msg;
				if (!msg.ParseFromString(payload)) {
					std::fprintf(stderr, "serve: invalid ToEngine protobuf payload (%zu bytes)\n", payload.size());
					if (!sender.send(makeErrorReply("parse", "invalid ToEngine protobuf payload"))) {
						handler.onShutdown();
						return 0;
					}
					continue;
				}

				if (config.trace) {
					logTrace("<-", msg);
				}

				if (msg.kind_case() == proto::ToEngine::kShutdown) {
					handler.onShutdown();
					return 0;
				}

				handler.handle(msg, sender);
			}

			if (eof) {
				handler.onShutdown();
				return 0;
			}
		}

		const auto after = std::chrono::steady_clock::now();
		if (after >= nextHeartbeat) {
			const HeartbeatStats stats = handler.heartbeatStats();
			proto::FromEngine hbEnvelope;
			auto* hb = hbEnvelope.mutable_heartbeat();
			hb->set_voices(stats.voices);
			hb->set_cpu_load(stats.cpuLoad);
			hb->set_underruns(stats.underruns);
			if (!sender.send(hbEnvelope)) {
				handler.onShutdown();
				return 0;
			}
			do {
				nextHeartbeat += interval;
			} while (nextHeartbeat <= after);
		}
	}

	handler.onShutdown();
	return 0;
}

int runServer(const ServerConfig& config, RequestHandler& handler) {
	if (config.socketPath.empty()) {
		std::fprintf(stderr, "serve: --socket PATH is required\n");
		return 2;
	}

	struct sockaddr_un addr {};
	if (config.socketPath.size() >= sizeof(addr.sun_path)) {
		std::fprintf(stderr, "serve: socket path too long (%zu >= %zu bytes): %s\n", config.socketPath.size(),
		             sizeof(addr.sun_path), config.socketPath.c_str());
		return 2;
	}

	gStopRequested.store(false, std::memory_order_relaxed);
	std::signal(SIGPIPE, SIG_IGN);
	struct sigaction sa {};
	sa.sa_handler = handleSignal;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0; // no SA_RESTART so accept/poll wake promptly
	::sigaction(SIGINT, &sa, nullptr);
	::sigaction(SIGTERM, &sa, nullptr);

	struct stat st {};
	if (::lstat(config.socketPath.c_str(), &st) == 0) {
		if (!S_ISSOCK(st.st_mode)) {
			std::fprintf(stderr, "serve: refusing to overwrite non-socket path: %s\n", config.socketPath.c_str());
			return 1;
		}
		if (::unlink(config.socketPath.c_str()) != 0) {
			std::fprintf(stderr, "serve: failed to remove stale socket %s: %s\n", config.socketPath.c_str(),
			             std::strerror(errno));
			return 1;
		}
	}

	ScopedFd listenFd(::socket(AF_UNIX, SOCK_STREAM, 0));
	if (listenFd.get() < 0) {
		std::fprintf(stderr, "serve: socket() failed: %s\n", std::strerror(errno));
		return 1;
	}

	addr.sun_family = AF_UNIX;
	std::memcpy(addr.sun_path, config.socketPath.c_str(), config.socketPath.size() + 1);
	if (::bind(listenFd.get(), reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) != 0) {
		std::fprintf(stderr, "serve: bind(%s) failed: %s\n", config.socketPath.c_str(), std::strerror(errno));
		return 1;
	}
	ScopedSocketFile unlinkGuard(config.socketPath);

	if (::listen(listenFd.get(), 1) != 0) {
		std::fprintf(stderr, "serve: listen(%s) failed: %s\n", config.socketPath.c_str(), std::strerror(errno));
		return 1;
	}

	std::fprintf(stderr, "deluge-engine serve: listening on %s (audio=%s)\n", config.socketPath.c_str(),
	             config.audioDevice.c_str());
	std::fflush(stderr);

	int clientRaw = -1;
	while (!gStopRequested.load(std::memory_order_relaxed)) {
		clientRaw = ::accept(listenFd.get(), nullptr, nullptr);
		if (clientRaw >= 0) {
			break;
		}
		if (errno == EINTR) {
			continue;
		}
		std::fprintf(stderr, "serve: accept() failed: %s\n", std::strerror(errno));
		return 1;
	}
	if (clientRaw < 0) {
		return 0;
	}

	ScopedFd clientFd(clientRaw);
	// Spec §7.1: one client at a time. Stop listening once connected.
	listenFd.reset();

	return serveClientFd(clientFd.get(), config, handler);
}

} // namespace deluge::engine::server
