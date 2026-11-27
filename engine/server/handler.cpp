#include "server/handler.h"

namespace deluge::engine::server {

const char* commandName(const proto::ToEngine& msg) {
	switch (msg.kind_case()) {
	case proto::ToEngine::kSetCard:
		return "set_card";
	case proto::ToEngine::kSetSetup:
		return "set_setup";
	case proto::ToEngine::kAudition:
		return "audition";
	case proto::ToEngine::kNote:
		return "note";
	case proto::ToEngine::kSetDevices:
		return "set_devices";
	case proto::ToEngine::kShutdown:
		return "shutdown";
	case proto::ToEngine::kRenderPiece:
		return "render_piece";
	case proto::ToEngine::kCancelRender:
		return "cancel_render";
	case proto::ToEngine::kPlay:
		return "play";
	case proto::ToEngine::kSeek:
		return "seek";
	case proto::ToEngine::kStop:
		return "stop";
	case proto::ToEngine::kPlayPiece:
		return "play_piece";
	case proto::ToEngine::kStopPiece:
		return "stop_piece";
	case proto::ToEngine::KIND_NOT_SET:
		return "unknown";
	}
	return "unknown";
}

proto::FromEngine makeErrorReply(const std::string& command, const std::string& message) {
	proto::FromEngine out;
	auto* err = out.mutable_error();
	err->set_command(command);
	err->set_message(message);
	return out;
}

void RequestHandler::handle(const proto::ToEngine& msg, MessageSender& sender) {
	const char* name = commandName(msg);
	sender.send(makeErrorReply(name, std::string("command '") + name + "' is not implemented"));
}

} // namespace deluge::engine::server
