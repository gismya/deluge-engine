// deluge-engine CLI entrypoint (spec §3.9, §7.1).
//
// Subcommands:
//   serve  --socket PATH [--audio null|default|NAME] [--card FOLDER] [--trace]
//   render --card FOLDER --preset PATH (--midi FILE.mid | --notes LIST) --out WAV [--audio null]
//
// Later tickets add `play` (E8), `render --piece` (E14), and `list` (E15) here.

#include "cli/render_cmd.h"
#include "engine_version.h"
#include "server/handler.h"
#include "server/server.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace {

void printUsage() {
	std::fprintf(stderr,
	             "usage:\n"
	             "  deluge-engine serve --socket PATH [--audio null|default|NAME] [--card FOLDER] [--trace]\n");
	deluge::engine::cli::printRenderUsage();
}

int cmdServe(int argc, char** argv) {
	deluge::engine::server::ServerConfig config;
	config.engineVersion = DELUGE_ENGINE_VERSION;
	config.firmwareCommit = DELUGE_FIRMWARE_COMMIT;

	for (int i = 0; i < argc; ++i) {
		const char* arg = argv[i];
		if (std::strcmp(arg, "--socket") == 0) {
			if (i + 1 >= argc) {
				std::fprintf(stderr, "serve: --socket requires a path\n");
				return 2;
			}
			config.socketPath = argv[++i];
		}
		else if (std::strcmp(arg, "--audio") == 0) {
			if (i + 1 >= argc) {
				std::fprintf(stderr, "serve: --audio requires a value (null|default|NAME)\n");
				return 2;
			}
			config.audioDevice = argv[++i];
			if (config.audioDevice.empty()) {
				std::fprintf(stderr, "serve: --audio value must not be empty\n");
				return 2;
			}
		}
		else if (std::strcmp(arg, "--card") == 0) {
			if (i + 1 >= argc) {
				std::fprintf(stderr, "serve: --card requires a folder path\n");
				return 2;
			}
			config.cardFolder = argv[++i];
		}
		else if (std::strcmp(arg, "--trace") == 0) {
			config.trace = true;
		}
		else if (std::strcmp(arg, "--help") == 0 || std::strcmp(arg, "-h") == 0) {
			printUsage();
			return 0;
		}
		else {
			std::fprintf(stderr, "serve: unknown option: %s\n", arg);
			return 2;
		}
	}

	if (config.socketPath.empty()) {
		std::fprintf(stderr, "serve: --socket PATH is required\n");
		return 2;
	}

	deluge::engine::server::RequestHandler handler;
	return deluge::engine::server::runServer(config, handler);
}

int dispatch(int argc, char** argv) {
	if (argc < 2) {
		printUsage();
		return 2;
	}
	const char* cmd = argv[1];
	if (std::strcmp(cmd, "serve") == 0) {
		return cmdServe(argc - 2, argv + 2);
	}
	if (std::strcmp(cmd, "render") == 0) {
		return deluge::engine::cli::cmdRender(argc - 2, argv + 2);
	}
	if (std::strcmp(cmd, "--help") == 0 || std::strcmp(cmd, "-h") == 0) {
		printUsage();
		return 0;
	}
	std::fprintf(stderr, "unknown subcommand: %s\n", cmd);
	printUsage();
	return 2;
}

} // namespace

int main(int argc, char** argv) {
	const int status = dispatch(argc, argv);
	// The Deluge firmware never exits, so its global destructors (e.g. FileReader::~FileReader) must not run.
	// dispatch() has already destroyed all local RAII resources (such as serve's socket file guard).
	std::fflush(nullptr);
	std::_Exit(status);
}
