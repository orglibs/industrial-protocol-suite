import 'dart:typed_data';

/// RFC 1006 TPKT (ISO Transport on Top of TCP)
class TpktFrame {
  static const int headerLength = 4;
  static const int version = 3;

  /// Wraps COTP/MMS payload with 4-byte TPKT header
  static Uint8List wrap(Uint8List payload) {
    final totalLen = headerLength + payload.length;
    final bytes = Uint8List(totalLen);
    bytes[0] = version;
    bytes[1] = 0x00; // Reserved
    bytes[2] = (totalLen >> 8) & 0xFF;
    bytes[3] = totalLen & 0xFF;
    bytes.setRange(headerLength, totalLen, payload);
    return bytes;
  }

  /// Extracts a complete TPKT packet from rxBuffer.
  /// Returns `(payload, consumedLength)` or null if not enough bytes.
  static ({Uint8List payload, int consumed})? extract(Uint8List buffer) {
    if (buffer.length < headerLength) return null;
    if (buffer[0] != version) {
      // Stream desynchronization, caller should discard
      return null;
    }
    final totalLen = (buffer[2] << 8) | buffer[3];
    if (buffer.length < totalLen) return null; // Wait for full frame

    final payload = Uint8List.sublistView(buffer, headerLength, totalLen);
    return (payload: payload, consumed: totalLen);
  }
}

/// ISO 8073 / RFC 905 COTP (Connection-Oriented Transport Protocol)
class CotpFrame {
  static const int typeCr = 0xE0; // Connection Request
  static const int typeCc = 0xD0; // Connection Confirm
  static const int typeDt = 0xF0; // Data Transfer
  static const int typeDr = 0x80; // Disconnect Request

  /// Checks if packet is a COTP Connection Request (CR)
  static bool isConnectionRequest(Uint8List cotp) {
    if (cotp.length < 2) return false;
    final type = cotp[1] & 0xF0;
    return type == typeCr;
  }

  /// Builds COTP Connection Confirm (CC)
  static Uint8List buildConnectionConfirm({
    required int dstRef,
    required int srcRef,
  }) {
    // Length (1B) + Type (1B) + DstRef (2B) + SrcRef (2B) + Class/Option (1B) = 7 bytes
    final bytes = Uint8List(7);
    bytes[0] = 6; // Length
    bytes[1] = typeCc;
    bytes[2] = (dstRef >> 8) & 0xFF;
    bytes[3] = dstRef & 0xFF;
    bytes[4] = (srcRef >> 8) & 0xFF;
    bytes[5] = srcRef & 0xFF;
    bytes[6] = 0x00; // Class 0
    return bytes;
  }

  /// Wraps ACSE/MMS payload with COTP Data Transfer (DT) header
  static Uint8List wrapDataTransfer(Uint8List payload) {
    // Length (1B) + Type (1B) + EOT (1B = 0x80) = 3 bytes
    final bytes = Uint8List(3 + payload.length);
    bytes[0] = 2; // COTP Header length (Type + EOT)
    bytes[1] = typeDt;
    bytes[2] = 0x80; // EOT = 1 (End of TSPO)
    bytes.setRange(3, 3 + payload.length, payload);
    return bytes;
  }

  /// Extracts payload from COTP DT packet
  static Uint8List? extractDataPayload(Uint8List cotp) {
    if (cotp.length < 3) return null;
    final headerLen = cotp[0];
    final type = cotp[1] & 0xF0;
    if (type != typeDt) return null;
    final payloadOffset = 1 + headerLen;
    if (cotp.length <= payloadOffset) return Uint8List(0);
    return Uint8List.sublistView(cotp, payloadOffset);
  }
}
