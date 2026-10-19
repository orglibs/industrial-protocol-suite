import 'dart:typed_data';
import '../i18n/app_i18n.dart';

/// IEC 60870-5-104 APCI (Application Protocol Control Information) Format Types
enum ApciType {
  iFormat, // Information Transfer (data carrying frame)
  sFormat, // Numbered Supervisory functions (acknowledgement)
  uFormat, // Unnumbered Control functions (STARTDT, STOPDT, TESTFR)
}

/// IEC 60870-5-104 U-Format Function Types
enum UFormatType {
  startDtAct(0x07, 'STARTDT act (Activate data transfer)'),
  startDtCon(0x0B, 'STARTDT con (Confirm data transfer)'),
  stopDtAct(0x13, 'STOPDT act (Stop data transfer)'),
  stopDtCon(0x23, 'STOPDT con (Confirm stop transfer)'),
  testFrAct(0x43, 'TESTFR act (Test frame activation)'),
  testFrCon(0x83, 'TESTFR con (Test frame confirmation)');

  final int byteValue;
  final String englishDescription;
  const UFormatType(this.byteValue, this.englishDescription);

  String get description {
    final i18n = AppI18n.instance;
    switch (this) {
      case UFormatType.startDtAct:
        return i18n.t('u_startdt_act');
      case UFormatType.startDtCon:
        return i18n.t('u_startdt_con');
      case UFormatType.stopDtAct:
        return i18n.t('u_stopdt_act');
      case UFormatType.stopDtCon:
        return i18n.t('u_stopdt_con');
      case UFormatType.testFrAct:
        return i18n.t('u_testfr_act');
      case UFormatType.testFrCon:
        return i18n.t('u_testfr_con');
    }
  }

  String get label => description;

  static UFormatType? fromByte(int byte) {
    for (final v in UFormatType.values) {
      if (v.byteValue == byte) return v;
    }
    return null;
  }
}

/// Represents the 6-byte APCI Header in IEC 60870-5-104:
/// Byte 0: Start byte (0x68)
/// Byte 1: Length of APDU (excluding byte 0 & 1, 4 to 253)
/// Bytes 2-5: Control Fields (4 bytes)
class ApciHeader {
  static const int startByte = 0x68;
  static const int apciLength = 6;

  final ApciType type;
  final int apduLength; // Length field in byte 1 (control field + ASDU length)
  final int? txSeq;     // 15-bit Tx sequence number (for I-format)
  final int? rxSeq;     // 15-bit Rx sequence number (for I and S formats)
  final UFormatType? uType; // For U-format

  const ApciHeader._({
    required this.type,
    required this.apduLength,
    this.txSeq,
    this.rxSeq,
    this.uType,
  });

  /// Factory for I-format (Information Transfer)
  factory ApciHeader.iFormat({
    required int txSeq,
    required int rxSeq,
    required int asduLength,
  }) {
    return ApciHeader._(
      type: ApciType.iFormat,
      apduLength: 4 + asduLength,
      txSeq: txSeq & 0x7FFF,
      rxSeq: rxSeq & 0x7FFF,
    );
  }

  /// Factory for S-format (Supervisory Acknowledgement)
  factory ApciHeader.sFormat({
    required int rxSeq,
  }) {
    return ApciHeader._(
      type: ApciType.sFormat,
      apduLength: 4,
      rxSeq: rxSeq & 0x7FFF,
    );
  }

  /// Factory for U-format (Unnumbered Control)
  factory ApciHeader.uFormat({
    required UFormatType uType,
  }) {
    return ApciHeader._(
      type: ApciType.uFormat,
      apduLength: 4,
      uType: uType,
    );
  }

  /// Encodes this APCI Header into 6 bytes
  Uint8List encode() {
    final bytes = Uint8List(apciLength);
    bytes[0] = startByte;
    bytes[1] = apduLength & 0xFF;

    switch (type) {
      case ApciType.iFormat:
        final tx = txSeq ?? 0;
        final rx = rxSeq ?? 0;
        // I-format: Byte 2 bit 0 = 0
        bytes[2] = (tx << 1) & 0xFE;
        bytes[3] = (tx >> 7) & 0xFF;
        // Byte 4 bit 0 = 0
        bytes[4] = (rx << 1) & 0xFE;
        bytes[5] = (rx >> 7) & 0xFF;
        break;

      case ApciType.sFormat:
        final rx = rxSeq ?? 0;
        // S-format: Byte 2 = 0x01
        bytes[2] = 0x01;
        bytes[3] = 0x00;
        bytes[4] = (rx << 1) & 0xFE;
        bytes[5] = (rx >> 7) & 0xFF;
        break;

      case ApciType.uFormat:
        // U-format: Byte 2 has uType bit pattern
        bytes[2] = uType?.byteValue ?? 0x07;
        bytes[3] = 0x00;
        bytes[4] = 0x00;
        bytes[5] = 0x00;
        break;
    }

    return bytes;
  }

  /// Decodes 6 bytes into an [ApciHeader]
  static ApciHeader decode(Uint8List data, [int offset = 0]) {
    if (data.length - offset < apciLength) {
      throw FormatException('Data length ${data.length - offset} is less than APCI length ($apciLength)');
    }
    if (data[offset] != startByte) {
      throw FormatException('Invalid start byte 0x${data[offset].toRadixString(16)}, expected 0x68');
    }

    final length = data[offset + 1];
    final b2 = data[offset + 2];
    final b3 = data[offset + 3];
    final b4 = data[offset + 4];
    final b5 = data[offset + 5];

    // Determine frame format according to IEC 60870-5-104:
    // If bit 0 of byte 2 == 0 -> I-format
    // If bit 0 == 1 and bit 1 == 0 -> S-format
    // If bit 0 == 1 and bit 1 == 1 -> U-format
    if ((b2 & 0x01) == 0) {
      // I-Format
      final txSeq = ((b2 >> 1) | (b3 << 7)) & 0x7FFF;
      final rxSeq = ((b4 >> 1) | (b5 << 7)) & 0x7FFF;
      return ApciHeader._(
        type: ApciType.iFormat,
        apduLength: length,
        txSeq: txSeq,
        rxSeq: rxSeq,
      );
    } else if ((b2 & 0x03) == 0x01) {
      // S-Format
      final rxSeq = ((b4 >> 1) | (b5 << 7)) & 0x7FFF;
      return ApciHeader._(
        type: ApciType.sFormat,
        apduLength: length,
        rxSeq: rxSeq,
      );
    } else if ((b2 & 0x03) == 0x03) {
      // U-Format
      final uType = UFormatType.fromByte(b2);
      return ApciHeader._(
        type: ApciType.uFormat,
        apduLength: length,
        uType: uType,
      );
    } else {
      throw FormatException('Unknown APCI control byte pattern: 0x${b2.toRadixString(16)}');
    }
  }

  @override
  String toString() {
    switch (type) {
      case ApciType.iFormat:
        return 'I-Format(Tx: $txSeq, Rx: $rxSeq, len: $apduLength)';
      case ApciType.sFormat:
        return 'S-Format(Rx: $rxSeq, len: $apduLength)';
      case ApciType.uFormat:
        return 'U-Format(${uType?.description ?? "0x${uType?.byteValue.toRadixString(16)}" }, len: $apduLength)';
    }
  }
}
