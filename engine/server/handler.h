// Extension seam for protocol command handlers (E10, extended by E12, E15, E16, E19).
#pragma once

#include "proto/engine.pb.h"
#include <cstdint>
#include <string>
#include <vector>

namespace deluge::engine::server {

struct HeartbeatStats {
	uint32_t voices = 0;
	float cpuLoad = 0.0f;
	uint64_t underruns = 0;
};

// Thread-safe outbound frame sink passed to RequestHandler and async producers (workers, pump, freeze callback).
class MessageSender {
public:
	virtual ~MessageSender() = default;
	virtual bool send(const proto::FromEngine& msg) = 0;
};

// Returns the proto field name of `msg`'s active oneof kind (e.g. "set_card"), or "unknown" if unset.
const char* commandName(const proto::ToEngine& msg);

// Builds a FromEngine envelope holding an ErrorReply.
proto::FromEngine makeErrorReply(const std::string& command, const std::string& message);

// Base handler for `deluge-engine serve`.
// E10 uses this directly (empty capabilities, zeroed heartbeats, ErrorReply for every command other than Shutdown).
// E15 overrides SetCard/RenderPiece/CancelRender + capabilities {"pieces", "render"}.
// E16 overrides Play/Seek/Stop/Audition(.wav)/SetDevices(audio).
// E12 overrides SetCard(live boot)/SetSetup/Note/Audition(preset)/SetDevices(midi)/Freeze + {"setups", "audition"}.
// E19 overrides PlayPiece/StopPiece + "play_live".
class RequestHandler {
public:
	virtual ~RequestHandler() = default;

	virtual std::vector<std::string> capabilities() const { return {}; }
	virtual HeartbeatStats heartbeatStats() const { return {}; }

	// Handle any ToEngine message other than Shutdown (which the server handles directly).
	virtual void handle(const proto::ToEngine& msg, MessageSender& sender);

	// Called once when Shutdown arrives or the client disconnects.
	virtual void onShutdown() {}
};

} // namespace deluge::engine::server
