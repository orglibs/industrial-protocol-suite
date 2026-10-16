import 'dart:convert';
import 'dart:typed_data';
import '../models/scl_models.dart';

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
class MmsValueCodec {
  static Uint8List encodeValue(dynamic value, IecBasicType type) {
    switch (type) {
      case IecBasicType.boolean:
        final b = value == true || value == 1 || value == 'true';
        return BerTlv(0x83, Uint8List.fromList([b ? 0xFF : 0x00])).encode();

      case IecBasicType.int8:
      case IecBasicType.int16:
      case IecBasicType.int32:
      case IecBasicType.int64:
        final n = (value is num) ? value.toInt() : (int.tryParse(value.toString()) ?? 0);
        final bd = ByteData(4);
        bd.setInt32(0, n, Endian.big);
        return BerTlv(0x85, Uint8List.sublistView(bd.buffer.asUint8List())).encode();

      case IecBasicType.uint8:
      case IecBasicType.uint16:
      case IecBasicType.uint32:
        final n = (value is num) ? value.toInt() : (int.tryParse(value.toString()) ?? 0);
        final bd = ByteData(4);
        bd.setUint32(0, n, Endian.big);
        return BerTlv(0x86, Uint8List.sublistView(bd.buffer.asUint8List())).encode();

      case IecBasicType.float32:
        final d = (value is num) ? value.toDouble() : (double.tryParse(value.toString()) ?? 0.0);
        final raw = Uint8List(5);
        raw[0] = 8; // Float exponent specification
        final bd = ByteData.sublistView(raw, 1);
        bd.setFloat32(0, d, Endian.big);
        return BerTlv(0x87, raw).encode();

      case IecBasicType.float64:
        final d = (value is num) ? value.toDouble() : (double.tryParse(value.toString()) ?? 0.0);
        final raw = Uint8List(9);
        raw[0] = 11;
        final bd = ByteData.sublistView(raw, 1);
        bd.setFloat64(0, d, Endian.big);
        return BerTlv(0x87, raw).encode();

      case IecBasicType.quality:
        final q = (value is num) ? value.toInt() : 0;
        final qBytes = Uint8List(3);
        qBytes[0] = 3;
        qBytes[1] = (q >> 8) & 0xFF;
        qBytes[2] = q & 0xFF;
        return BerTlv(0x84, qBytes).encode();

      case IecBasicType.utcTime:
        final now = value is DateTime ? value : DateTime.now();
        final ms = now.millisecondsSinceEpoch;
        final sec = ms ~/ 1000;
        final frac = ((ms % 1000) * 16777216) ~/ 1000;
        final tBytes = Uint8List(8);
        final bd = ByteData.sublistView(tBytes);
        bd.setUint32(0, sec, Endian.big);
        bd.setUint32(4, (frac << 8) | 0x0A, Endian.big);
        return BerTlv(0x91, tBytes).encode();

      default:
        final str = value?.toString() ?? '';
        final strBytes = utf8.encode(str);
        return BerTlv(0x8A, Uint8List.fromList(strBytes)).encode();
    }
  }

  static ({dynamic value, int quality, DateTime? timestamp, int consumed}) decodeValue(Uint8List bytes, [int offset = 0]) {
    final tlv = BerTlv.decode(bytes, offset);
    if (tlv == null) {
      return (value: null, quality: 0, timestamp: null, consumed: 0);
    }

    final totalConsumed = tlv.headerSize + tlv.length;
    dynamic val;
    int q = 0;
    DateTime? ts;

    switch (tlv.tag) {
      case 0x83: // boolean
        val = tlv.value.isNotEmpty && tlv.value[0] != 0;
        break;

      case 0x85: // integer
        int n = 0;
        for (final b in tlv.value) {
          n = (n << 8) | b;
        }
        val = n;
        break;

      case 0x86: // unsigned
        int u = 0;
        for (final b in tlv.value) {
          u = (u << 8) | b;
        }
        val = u;
        break;

      case 0x87: // float
        if (tlv.value.length >= 5) {
          final bd = ByteData.sublistView(tlv.value, 1);
          val = bd.getFloat32(0, Endian.big);
        }
        break;

      case 0x84: // bitstring (often Quality)
        if (tlv.value.length >= 3) {
          q = (tlv.value[1] << 8) | tlv.value[2];
        }
        val = q;
        break;

      case 0x91: // utcTime
        if (tlv.value.length >= 4) {
          final bd = ByteData.sublistView(tlv.value);
          final sec = bd.getUint32(0, Endian.big);
          ts = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
        }
        val = ts?.toIso8601String();
        break;

      case 0x8A: // VisibleString
      default:
        val = utf8.decode(tlv.value, allowMalformed: true);
        break;
    }

    return (value: val, quality: q, timestamp: ts, consumed: totalConsumed);
  }
}

/// ISO Presentation & ACSE Wrapper
class IsoAcseMms {
  /// Builds ACSE AARQ (Association Request) with MMS Initiate Request
  static Uint8List buildAarqWithMmsInitiate() {
    // 1. MMS Initiate Request PDU (Tag 0xA8)
    final mmsInit = Uint8List.fromList([
      0xA8, 0x16, // Initiate-RequestPdu
      0x80, 0x02, 0x00, 0x05, // localDetailCalling = 5
      0x81, 0x02, 0x00, 0x05, // proposedMaxServOutstandingCalling = 5
      0x82, 0x01, 0x0A,       // proposedDataStructureNestingLevel = 10
      0xA3, 0x0B,             // mmsInitDetail
      0x80, 0x02, 0x00, 0x01, // mmsVersion = 1
      0x81, 0x03, 0x05, 0xF1, 0x00, // parameterSupportOptions
      0x82, 0x00,             // servicesSupportedCalling
    ]);

    // 2. Wrap in ACSE AARQ (Tag 0x60)
    final aarqUser = Uint8List(mmsInit.length + 8);
    aarqUser[0] = 0x28; // Presentation Context ID
    aarqUser[1] = (mmsInit.length + 6) & 0xFF;
    aarqUser[2] = 0x06; aarqUser[3] = 0x02; aarqUser[4] = 0x51; aarqUser[5] = 0x01; // Direct Reference
    aarqUser[6] = 0xA0; // Single ASN.1 type
    aarqUser[7] = mmsInit.length & 0xFF;
    aarqUser.setRange(8, 8 + mmsInit.length, mmsInit);

    final aarq = Uint8List.fromList([
      0x60, 0x2E, // AARQ
      0x80, 0x02, 0x00, 0x00, // Protocol version
      0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01, // AS Name
      0xBE, 0x21, // User Information
      ...aarqUser,
    ]);

    // 3. Wrap in Presentation CP (0x31)
    final pres = Uint8List.fromList([
      0x31, (aarq.length + 2) & 0xFF,
      ...aarq,
    ]);

    // 4. Session Connect (0x0D 0x01 0x00)
    final session = Uint8List.fromList([
      0x0D, 0x01, 0x00,
      ...pres,
    ]);

    return session;
  }

  /// Checks if packet is an ACSE AARE (Association Response)
  static bool isAare(Uint8List payload) {
    if (payload.isEmpty) return false;
    // ISO 8327-1 Session Accept SPDU is tag 0x0E
    if (payload[0] == 0x0E) return true;
    for (int i = 0; i < payload.length - 2; i++) {
      if (payload[i] == 0x0E && payload[i + 1] == 0x01) return true;
    }
    return false;
  }

  /// Wraps an MMS PDU with ISO Session & Presentation headers
  static Uint8List wrapMmsPdu(Uint8List mmsPdu) {
    final presBody = Uint8List(mmsPdu.length + 6);
    presBody[0] = 0x30;
    presBody[1] = (mmsPdu.length + 4) & 0xFF;
    presBody[2] = 0x02;
    presBody[3] = 0x01;
    presBody[4] = 0x01; // Context 1
    presBody[5] = 0xA0; // Single ASN1
    presBody.setRange(6, 6 + mmsPdu.length, mmsPdu);

    final pres = BerTlv(0x61, presBody).encode();

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
    // 0xA3 (UnconfirmedPdu / InformationReport)
    // 0xA8 (Initiate-RequestPdu)
    // 0xA9 (Initiate-ResponsePdu)
    for (int i = 0; i < payload.length - 2; i++) {
      final tag = payload[i];
      if (tag == 0xA0 || tag == 0xA1 || tag == 0xA2 || tag == 0xA3 || tag == 0xA8 || tag == 0xA9) {
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
      // Confirmed-Request / Response / Error: First item MUST be invokeID (INTEGER tag 0x02)
      final sub = BerTlv.decode(tlv.value, 0);
      return sub != null && sub.tag == 0x02;
    }
    if (tag == 0xA3) {
      // Unconfirmed-Pdu (InformationReport): First item is tag 0xA0
      final sub = BerTlv.decode(tlv.value, 0);
      return sub != null && sub.tag == 0xA0;
    }
    if (tag == 0xA8 || tag == 0xA9) {
      return true;
    }
    return false;
  }
}
