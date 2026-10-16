import 'dart:typed_data';
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
    final rawHex = bytesToHex(bytes);
    final fields = <ParsedField>[];

    if (bytes.length < ApciHeader.apciLength) {
      return ParsedFrame(
        rawBytes: bytes,
        rawHex: rawHex,
        apci: ApciHeader.uFormat(uType: UFormatType.startDtAct),
        summary: '报文过短 (小于6字节)',
        fields: [
          ParsedField(name: 'Error', value: '帧长度不足', description: '最小长度为6字节'),
        ],
        isValid: false,
        errorMessage: '报文长度 ${bytes.length} 小于 APCI 最小长度 6',
      );
    }

    if (bytes[0] != 0x68) {
      return ParsedFrame(
        rawBytes: bytes,
        rawHex: rawHex,
        apci: ApciHeader.uFormat(uType: UFormatType.startDtAct),
        summary: '非法起始字符 (非0x68)',
        fields: [
          ParsedField(name: 'StartByte', value: '0x${bytes[0].toRadixString(16)}', description: '起始字符必须为0x68'),
        ],
        isValid: false,
        errorMessage: '非法起始字符 0x${bytes[0].toRadixString(16)}',
      );
    }

    final apci = ApciHeader.decode(bytes);
    fields.add(ParsedField(
      name: '起始字符 (Start Byte)',
      value: '0x68',
      hex: '68',
      description: 'IEC 60870-5-104 帧起始界定符',
    ));
    fields.add(ParsedField(
      name: 'APDU 长度 (Length)',
      value: '${apci.apduLength} 字节',
      hex: bytes[1].toRadixString(16).padLeft(2, '0').toUpperCase(),
      description: '后续控制域与ASDU的总长度',
    ));

    final ctrlHex = bytes.sublist(2, 6).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

    String summary = '';
    Asdu? asdu;

    switch (apci.type) {
      case ApciType.iFormat:
        fields.add(ParsedField(
          name: '控制域格式 (Control Field)',
          value: 'I-Format (信息传输帧)',
          hex: ctrlHex,
          description: '发送序号 N(S)=${apci.txSeq}, 接收序号 N(R)=${apci.rxSeq}',
        ));
        fields.add(ParsedField(name: '发送序列号 N(S)', value: '${apci.txSeq}'));
        fields.add(ParsedField(name: '接收序列号 N(R)', value: '${apci.rxSeq}'));

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
              name: 'ASDU 类型标识 (Type ID)',
              value: '${asdu.typeId.nameString} [${asdu.typeId.id}]',
              hex: asduBytes[0].toRadixString(16).padLeft(2, '0').toUpperCase(),
              description: asdu.typeId.description,
            ));

            fields.add(ParsedField(
              name: '可变结构限定词 (VSQ)',
              value: '${asdu.isSequence ? "连续SQ=1" : "单一SQ=0"}, 元素数量: ${asdu.objects.length}',
              hex: asduBytes[1].toRadixString(16).padLeft(2, '0').toUpperCase(),
            ));

            fields.add(ParsedField(
              name: '传送原因 (COT)',
              value: '${asdu.cot.description} [${asdu.cot.id}]',
              description: '试验位T: ${asdu.isTest}, 肯定/否定P/N: ${asdu.isNegativeConfirm ? "否定(1)" : "肯定(0)"}, 源发地址OA: ${asdu.originatorAddress}',
            ));

            fields.add(ParsedField(
              name: '公共地址 (Common Address / COA)',
              value: '${asdu.commonAddress} (0x${asdu.commonAddress.toRadixString(16).toUpperCase()})',
              description: '从站/子站地址',
            ));

            for (int i = 0; i < asdu.objects.length; i++) {
              final obj = asdu.objects[i];
              fields.add(ParsedField(
                name: '信息对象 #${i + 1} (IOA: ${obj.ioa})',
                value: obj.displayValue,
                description: '十进制IOA: ${obj.ioa}, 十六进制: 0x${obj.ioa.toRadixString(16).padLeft(6, '0').toUpperCase()}',
              ));
            }
          } catch (e) {
            summary = 'I-Frame [Tx:${apci.txSeq}, Rx:${apci.rxSeq}] (ASDU解析错误: $e)';
            fields.add(ParsedField(name: 'ASDU 错误', value: e.toString()));
          }
        } else {
          summary = 'I-Frame [Tx:${apci.txSeq}, Rx:${apci.rxSeq}] (无ASDU数据)';
        }
        break;

      case ApciType.sFormat:
        summary = 'S-Frame [确认 N(R): ${apci.rxSeq}]';
        fields.add(ParsedField(
          name: '控制域格式 (Control Field)',
          value: 'S-Format (监视功能确认帧)',
          hex: ctrlHex,
          description: '确认对方已成功接收到序列号 N(R)=${apci.rxSeq}',
        ));
        fields.add(ParsedField(name: '接收序列号 N(R)', value: '${apci.rxSeq}'));
        break;

      case ApciType.uFormat:
        final uDesc = apci.uType?.description ?? '0x${apci.uType?.byteValue.toRadixString(16)}';
        summary = 'U-Frame [$uDesc]';
        fields.add(ParsedField(
          name: '控制域格式 (Control Field)',
          value: 'U-Format (无编号控制帧: $uDesc)',
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
