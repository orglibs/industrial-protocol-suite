import 'dart:typed_data';
import '../i18n/app_i18n.dart';
import 'apci.dart';
import 'asdu.dart';
import 'codec.dart';

/// Parsed field item in an IEC 104 frame
class ParsedField {
  final String name;
  final String value;
  final String hex;
  final String description;

  const ParsedField({
    required this.name,
    required this.value,
    this.hex = '',
    this.description = '',
  });
}

/// Detailed result of parsing an IEC 104 frame
class ParsedFrame {
  final Uint8List rawBytes;
  final String rawHex;
  final ApciHeader apci;
  final Asdu? asdu;
  final String summary;
  final List<ParsedField> fields;
  final bool isValid;
  final String? errorMessage;

  ParsedFrame({
    required this.rawBytes,
    required this.rawHex,
    required this.apci,
    this.asdu,
    required this.summary,
    required this.fields,
    this.isValid = true,
    this.errorMessage,
  });
}

/// High-level parser and packet analyzer
class Iec104Parser {
  /// Converts a hex string (with or without spaces/commas) into Uint8List
  static Uint8List? hexToBytes(String hex) {
    try {
      final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      if (clean.isEmpty || clean.length % 2 != 0) return null;
      final bytes = Uint8List(clean.length ~/ 2);
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Formats bytes as space-separated uppercase hex string
  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  /// Parses a raw byte buffer containing an APDU
  static ParsedFrame parseBytes(
    Uint8List bytes, {
    int cotSize = 2,
    int caSize = 2,
    int ioaSize = 3,
  }) {
    final i18n = AppI18n.instance;
    final rawHex = bytesToHex(bytes);
    final fields = <ParsedField>[];

    if (bytes.length < ApciHeader.apciLength) {
      return ParsedFrame(
        rawBytes: bytes,
        rawHex: rawHex,
        apci: ApciHeader.uFormat(uType: UFormatType.startDtAct),
        summary: i18n.t('parserFrameTooShort'),
        fields: [
          ParsedField(name: 'Error', value: i18n.t('parserLengthInsufficient'), description: i18n.t('parserMinLength6')),
        ],
        isValid: false,
        errorMessage: 'Frame length ${bytes.length} < 6',
      );
    }

    if (bytes[0] != 0x68) {
      return ParsedFrame(
        rawBytes: bytes,
        rawHex: rawHex,
        apci: ApciHeader.uFormat(uType: UFormatType.startDtAct),
        summary: i18n.t('parserInvalidStartByte'),
        fields: [
          ParsedField(name: 'StartByte', value: '0x${bytes[0].toRadixString(16)}', description: i18n.t('parserStartByteMustBe68')),
        ],
        isValid: false,
        errorMessage: 'Invalid start byte 0x${bytes[0].toRadixString(16)}',
      );
    }

    final apci = ApciHeader.decode(bytes);
    fields.add(ParsedField(
      name: i18n.t('parserFieldStartByte'),
      value: '0x68',
      hex: '68',
      description: i18n.t('parserFieldStartByteDesc'),
    ));
    fields.add(ParsedField(
      name: i18n.t('parserFieldApduLength'),
      value: '${apci.apduLength} bytes',
      hex: bytes[1].toRadixString(16).padLeft(2, '0').toUpperCase(),
      description: i18n.t('parserFieldApduLengthDesc'),
    ));

    final ctrlHex = bytes.sublist(2, 6).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

    String summary = '';
    Asdu? asdu;

    switch (apci.type) {
      case ApciType.iFormat:
        fields.add(ParsedField(
          name: i18n.t('parserCtrlField'),
          value: 'I-Format',
          hex: ctrlHex,
          description: 'N(S)=${apci.txSeq}, N(R)=${apci.rxSeq}',
        ));
        fields.add(ParsedField(name: i18n.t('parserTxSeq'), value: '${apci.txSeq}'));
        fields.add(ParsedField(name: i18n.t('parserRxSeq'), value: '${apci.rxSeq}'));

        // Parse ASDU if present
        if (bytes.length > 6) {
          final asduBytes = bytes.sublist(6);
          try {
            asdu = Iec104Codec.decodeAsdu(
              bytes,
              6,
              bytes.length - 6,
              cotSize: cotSize,
              caSize: caSize,
              ioaSize: ioaSize,
            );

            summary = 'I-Frame [Tx:${apci.txSeq}, Rx:${apci.rxSeq}] - ${asdu.typeId.nameString} (${asdu.typeId.description})';

            fields.add(ParsedField(
              name: i18n.t('parserAsduTypeId'),
              value: '${asdu.typeId.nameString} [${asdu.typeId.id}]',
              hex: asduBytes[0].toRadixString(16).padLeft(2, '0').toUpperCase(),
              description: asdu.typeId.description,
            ));

            fields.add(ParsedField(
              name: i18n.t('parserVsq'),
              value: '${asdu.isSequence ? "SQ=1" : "SQ=0"}, Count: ${asdu.objects.length}',
              hex: asduBytes[1].toRadixString(16).padLeft(2, '0').toUpperCase(),
            ));

            fields.add(ParsedField(
              name: i18n.t('parserCot'),
              value: '${asdu.cot.description} [${asdu.cot.id}]',
              description: 'Test: ${asdu.isTest}, P/N: ${asdu.isNegativeConfirm ? "Negative(1)" : "Positive(0)"}, OA: ${asdu.originatorAddress}',
            ));

            fields.add(ParsedField(
              name: i18n.t('parserCommonAddr'),
              value: '${asdu.commonAddress} (0x${asdu.commonAddress.toRadixString(16).toUpperCase()})',
              description: 'Common Address',
            ));

            for (int i = 0; i < asdu.objects.length; i++) {
              final obj = asdu.objects[i];
              fields.add(ParsedField(
                name: '${i18n.t('parserInfoObj')} #${i + 1} (IOA: ${obj.ioa})',
                value: obj.displayValue,
                description: 'IOA Dec: ${obj.ioa}, Hex: 0x${obj.ioa.toRadixString(16).padLeft(6, '0').toUpperCase()}',
              ));
            }
          } catch (e) {
            summary = 'I-Frame [Tx:${apci.txSeq}, Rx:${apci.rxSeq}] (ASDU Error: $e)';
            fields.add(ParsedField(name: 'ASDU Error', value: e.toString()));
          }
        } else {
          summary = 'I-Frame [Tx:${apci.txSeq}, Rx:${apci.rxSeq}] (Empty ASDU)';
        }
        break;

      case ApciType.sFormat:
        summary = 'S-Frame [N(R): ${apci.rxSeq}]';
        fields.add(ParsedField(
          name: i18n.t('parserCtrlField'),
          value: 'S-Format',
          hex: ctrlHex,
          description: 'Confirm N(R)=${apci.rxSeq}',
        ));
        fields.add(ParsedField(name: i18n.t('parserRxSeq'), value: '${apci.rxSeq}'));
        break;

      case ApciType.uFormat:
        final uDesc = apci.uType?.description ?? '0x${apci.uType?.byteValue.toRadixString(16)}';
        summary = 'U-Frame [$uDesc]';
        fields.add(ParsedField(
          name: i18n.t('parserCtrlField'),
          value: 'U-Format ($uDesc)',
          hex: ctrlHex,
          description: apci.uType?.description ?? '',
        ));
        break;
    }

    return ParsedFrame(
      rawBytes: bytes,
      rawHex: rawHex,
      apci: apci,
      asdu: asdu,
      summary: summary,
      fields: fields,
    );
  }

  /// Parses a hex string directly
  static ParsedFrame? parseHex(String hex, {int cotSize = 2, int caSize = 2, int ioaSize = 3}) {
    final bytes = hexToBytes(hex);
    if (bytes == null) return null;
    return parseBytes(bytes, cotSize: cotSize, caSize: caSize, ioaSize: ioaSize);
  }
}
