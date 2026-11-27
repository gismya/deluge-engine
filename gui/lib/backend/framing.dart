import 'dart:typed_data';

import 'package:protobuf/protobuf.dart' as $pb;

/// Maximum protocol frame payload size: 16 MiB (spec §7.1).
const int kMaxFrameBytes = 16 * 1024 * 1024;

/// Thrown when an incoming or outgoing frame violates the framing spec (§7.1).
class FramingException implements Exception {
  const FramingException(this.message);
  final String message;

  @override
  String toString() => 'FramingException: $message';
}

/// Encodes a protobuf message with a 4-byte little-endian unsigned length prefix.
Uint8List encodeFrame($pb.GeneratedMessage message) {
  final payload = message.writeToBuffer();
  if (payload.length > kMaxFrameBytes) {
    throw FramingException(
      'Outgoing frame exceeds 16 MiB limit: ${payload.length} bytes',
    );
  }
  final out = Uint8List(4 + payload.length);
  ByteData.sublistView(out, 0, 4).setUint32(0, payload.length, Endian.little);
  out.setRange(4, out.length, payload);
  return out;
}

/// Incremental decoder for 4-byte little-endian length-prefixed protobuf frames.
class FrameDecoder {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  int? _expectedLength;

  /// Appends [chunk] and returns all complete frame payloads extracted so far.
  ///
  /// Throws [FramingException] if a frame header declares a length above
  /// [kMaxFrameBytes].
  List<Uint8List> addChunk(List<int> chunk) {
    if (chunk.isEmpty) return const [];
    _buffer.add(chunk);

    final frames = <Uint8List>[];
    var bytes = _buffer.takeBytes();
    var offset = 0;

    while (true) {
      if (_expectedLength == null) {
        if (bytes.length - offset < 4) break;
        final length =
            ByteData.sublistView(bytes, offset, offset + 4).getUint32(
          0,
          Endian.little,
        );
        if (length > kMaxFrameBytes) {
          _expectedLength = null;
          throw FramingException(
            'Incoming frame exceeds 16 MiB limit: $length bytes',
          );
        }
        _expectedLength = length;
        offset += 4;
      }

      final needed = _expectedLength!;
      if (bytes.length - offset < needed) break;

      frames.add(Uint8List.fromList(bytes.sublist(offset, offset + needed)));
      offset += needed;
      _expectedLength = null;
    }

    if (offset < bytes.length) {
      _buffer.add(bytes.sublist(offset));
    }
    return frames;
  }

  /// Clears any buffered partial frame state.
  void reset() {
    _buffer.clear();
    _expectedLength = null;
  }
}
