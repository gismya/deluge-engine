// Unix domain socket protocol server for `deluge-engine serve` (spec §7.1, §7.2, §7.7).
#pragma once

#include "server/handler.h"
#include <chrono>
#include <string>

namespace deluge::engine::server {

struct ServerConfig {
	std::string socketPath;
	std::string audioDevice = "default";
	std::string cardFolder;
	bool trace = false;
	std::string engineVersion;
	std::string firmwareCommit;
	std::chrono::milliseconds heartbeatInterval{250}; // 4 Hz (spec §7.4)
};

// Runs the protocol loop on an already-connected stream fd (also used directly by socketpair unit tests).
int serveClientFd(int clientFd, const ServerConfig& config, RequestHandler& handler);

// Listens on `config.socketPath`, accepts one client, serves the protocol, and unlinks the socket on exit.
int runServer(const ServerConfig& config, RequestHandler& handler);

} // namespace deluge::engine::server
