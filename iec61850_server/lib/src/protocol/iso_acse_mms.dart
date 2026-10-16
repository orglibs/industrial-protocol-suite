import 'dart:convert';
import 'dart:typed_data';
import '../models/scl_models.dart';
import '../models/server_variable_model.dart';

/// ASN.1 BER Tag Classes and Utilities
class BerTlv {
  final int tag;
  final Uint8List value;

  BerTlv(this.tag, this.value);

  int get length => value.length;

  Uint8List encode() {
    final lenBytes = encodeLength(value.length);
    final total = Uint8List(1 + lenBytes.length + value.length);
    total[0] = tag;
    total.setRange(1, 1 + lenBytes.length, lenBytes);
    total.setRange(1 + lenBytes.length, total.length, value);
    return total;
  }

  static Uint8List encodeLength(int len) {
    if (len < 128) {
      return Uint8List.fromList([len]);
    } else if (len <= 0xFF) {
      return Uint8List.fromList([0x81, len]);
    } else if (len <= 0xFFFF) {
      return Uint8List.fromList([0x82, (len >> 8) & 0xFF, len & 0xFF]);
    } else {
      return Uint8List.fromList([
        0x83,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF,
      ]);
    }
  }

  static ({int tag, int length, int headerSize, Uint8List value})? decode(Uint8List bytes, [int offset = 0]) {
    if (bytes.length <= offset + 1) return null;
    final tag = bytes[offset];
    int lenByte = bytes[offset + 1];
    int length = 0;
    int headerSize = 2;

    if ((lenByte & 0x80) == 0) {
      length = lenByte;
    } else {
      final numBytes = lenByte & 0x7F;
      headerSize = 2 + numBytes;
      if (bytes.length < offset + headerSize) return null;
      for (int i = 0; i < numBytes; i++) {
        length = (length << 8) | bytes[offset + 2 + i];
      }
    }

    if (bytes.length < offset + headerSize + length) return null;
    final val = Uint8List.sublistView(bytes, offset + headerSize, offset + headerSize + length);
    return (tag: tag, length: length, headerSize: headerSize, value: val);
  }
}

/// MMS Data Value Encoder & Decoder
class MmsValueEncoder {
  static Uint8List encodeVariable(ServerVariableModel variable) {
    switch (variable.type) {
      case IecBasicType.boolean:
        final b = variable.value == true;
        return BerTlv(0x83, Uint8List.fromList([b ? 0xFF : 0x00])).encode();

      case IecBasicType.int8:
      case IecBasicType.int16:
      case IecBasicType.int32:
      case IecBasicType.int64:
        final n = (variable.value is num) ? (variable.value as num).toInt() : 0;
        final bd = ByteData(4);
        bd.setInt32(0, n, Endian.big);
        return BerTlv(0x85, Uint8List.sublistView(bd.buffer.asUint8List())).encode();

      case IecBasicType.uint8:
      case IecBasicType.uint16:
      case IecBasicType.uint32:
        final n = (variable.value is num) ? (variable.value as num).toInt() : 0;
        final bd = ByteData(4);
        bd.setUint32(0, n, Endian.big);
        return BerTlv(0x86, Uint8List.sublistView(bd.buffer.asUint8List())).encode();

      case IecBasicType.float32:
        final d = (variable.value is num) ? (variable.value as num).toDouble() : 0.0;
        final raw = Uint8List(5);
        raw[0] = 8; // Float format specification exponent width
        final bd = ByteData.sublistView(raw, 1);
        bd.setFloat32(0, d, Endian.big);
        return BerTlv(0x87, raw).encode();

      case IecBasicType.float64:
        final d = (variable.value is num) ? (variable.value as num).toDouble() : 0.0;
        final raw = Uint8List(9);
        raw[0] = 11; // Exponent width for float64
        final bd = ByteData.sublistView(raw, 1);
        bd.setFloat64(0, d, Endian.big);
        return BerTlv(0x87, raw).encode();

      case IecBasicType.quality:
        final q = variable.quality;
        final qBytes = Uint8List(3);
        qBytes[0] = 3; // Unused bits = 3 (13-bit quality in 16-bit word)
        qBytes[1] = (q >> 8) & 0xFF;
        qBytes[2] = q & 0xFF;
        return BerTlv(0x84, qBytes).encode(); // Bit-String

      case IecBasicType.utcTime:
        final now = variable.timestamp;
        final ms = now.millisecondsSinceEpoch;
        final sec = ms ~/ 1000;
        final frac = ((ms % 1000) * 16777216) ~/ 1000; // 24-bit fraction
        final tBytes = Uint8List(8);
        final bd = ByteData.sublistView(tBytes);
        bd.setUint32(0, sec, Endian.big);
        bd.setUint32(4, (frac << 8) | 0x0A, Endian.big); // 0x0A = Clock sync quality
        return BerTlv(0x91, tBytes).encode(); // UtcTime

      default:
        final str = variable.value?.toString() ?? '';
        final strBytes = utf8.encode(str);
        return BerTlv(0x8A, Uint8List.fromList(strBytes)).encode(); // VisibleString
    }
  }
}

/// ISO Presentation & ACSE Wrapper
class IsoAcseMms {
  /// Checks if packet is an ACSE AARQ (Association Request)
  static bool isAarq(Uint8List payload) {
    if (payload.isEmpty) return false;
    // AARQ is typically preceded by Presentation Header (CP type: 0x31) or AARQ tag (0x60)
    for (int i = 0; i < payload.length - 1; i++) {
      if (payload[i] == 0x60) return true; // AARQ tag
    }
    return false;
  }

  /// Builds ACSE AARE (Association Response - Accepted) with MMS Initiate Response
  static Uint8List buildAareWithMmsInitiate() {
    // 1. MMS Initiate Response PDU (Tag 0xA9)
    // Negotiated MaxServOutstandingCalling = 5, Negotiated MaxServOutstandingCalled = 5, Nesting = 10, MMS Version = 1
    final mmsInit = Uint8List.fromList([
      0xA9, 0x16, // Initiate-ResponsePdu
      0x80, 0x02, 0x00, 0x05, // localDetailCalling = 5
      0x81, 0x02, 0x00, 0x05, // localDetailCalled = 5
      0x82, 0x01, 0x0A,       // negotiatedDataStructureNestingLevel = 10
      0xA3, 0x0B,             // mmsInitDetail
      0x80, 0x02, 0x00, 0x01, // mmsVersion = 1
      0x81, 0x03, 0x05, 0xF1, 0x00, // parameterSupportOptions
      0x82, 0x00,             // servicesSupportedCalled
    ]);

    // 2. Wrap in Presentation CPA / ACSE AARE
    // AARE (0x61) Accepted + User Information carrying MMS Initiate Response
    final aareUser = Uint8List(mmsInit.length + 8);
    aareUser[0] = 0x28; // Presentation Context ID
    aareUser[1] = (mmsInit.length + 6) & 0xFF;
    aareUser[2] = 0x06; aareUser[3] = 0x02; aareUser[4] = 0x51; aareUser[5] = 0x01; // Direct Reference
    aareUser[6] = 0xA0; // Single ASN.1 type
    aareUser[7] = mmsInit.length & 0xFF;
    aareUser.setRange(8, 8 + mmsInit.length, mmsInit);

    final aare = Uint8List.fromList([
      0x61, 0x2E, // AARE
      0x80, 0x02, 0x00, 0x00, // Result = accepted (0)
      0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01, // Result source diagnostic
      0xBE, 0x21, // User Information
      ...aareUser,
    ]);

    // 3. Presentation Header CPA (0x31) + Session Accept (0x0E)
    final pres = Uint8List.fromList([
      0x31, (aare.length + 2) & 0xFF,
      ...aare,
    ]);

    // Session Data
    final session = Uint8List.fromList([
      0x0E, 0x01, 0x00, // Session Accept
      ...pres,
    ]);

    return session;
  }

  /// Wraps an MMS PDU with ISO Session & Presentation headers
  static Uint8List wrapMmsPdu(Uint8List mmsPdu) {
    // Presentation header: 0x61 (Fully Encoded Data) -> 0x30 -> 0x02 (Presentation Context = 1) -> 0xA0 (Single ASN.1)
    final presBody = Uint8List(mmsPdu.length + 6);
    presBody[0] = 0x30;
    presBody[1] = (mmsPdu.length + 4) & 0xFF;
    presBody[2] = 0x02;
    presBody[3] = 0x01;
    presBody[4] = 0x01; // Context 1
    presBody[5] = 0xA0; // Single ASN1
    presBody.setRange(6, 6 + mmsPdu.length, mmsPdu);

    final pres = BerTlv(0x61, presBody).encode();

    // Session DT Header (0x01 0x00)
    final session = Uint8List(2 + pres.length);
    session[0] = 0x01;
    session[1] = 0x00;
    session.setRange(2, 2 + pres.length, pres);
    return session;
  }

  /// Extracts the underlying MMS PDU from an incoming Session/Presentation packet
  static Uint8List? extractMmsPdu(Uint8List payload) {
    if (payload.isEmpty) return null;

    // Scan for MMS PDU tags:
    // 0xA0 (Confirmed-RequestPdu)
    // 0xA1 (Confirmed-ResponsePdu)
    // 0xA2 (Confirmed-ErrorPdu)
    // 0xA3 (UnconfirmedPdu)
    // 0xA8 (Initiate-RequestPdu)
    for (int i = 0; i < payload.length - 2; i++) {
      final tag = payload[i];
      if (tag == 0xA0 || tag == 0xA1 || tag == 0xA2 || tag == 0xA3 || tag == 0xA8) {
        final decoded = BerTlv.decode(payload, i);
        if (decoded != null && (i + decoded.headerSize + decoded.length <= payload.length)) {
          if (_isValidMmsPdu(decoded)) {
            return Uint8List.sublistView(payload, i, i + decoded.headerSize + decoded.length);
          }
        }
      }
    }
    return null;
  }

  static bool _isValidMmsPdu(({int tag, int length, int headerSize, Uint8List value}) tlv) {
    if (tlv.value.isEmpty) return false;
    final tag = tlv.tag;
    if (tag == 0xA0 || tag == 0xA1 || tag == 0xA2) {
      final sub = BerTlv.decode(tlv.value, 0);
      return sub != null && sub.tag == 0x02;
    }
    if (tag == 0xA3) {
      final sub = BerTlv.decode(tlv.value, 0);
      return sub != null && sub.tag == 0xA0;
    }
    if (tag == 0xA8 || tag == 0xA9) {
      return true;
    }
    return false;
  }
}
