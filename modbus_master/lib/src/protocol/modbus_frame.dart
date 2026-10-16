import 'dart:typed_data';
import 'modbus_crc.dart';

enum ModbusFrameType {
  tcp('Modbus TCP (MBAP Header)'),
  rtu('Modbus RTU (CRC-16)'),
  ascii('Modbus ASCII (LRC)');

  final String label;
  const ModbusFrameType(this.label);
}

class ModbusAdu {
  final ModbusFrameType frameType;
  final int unitId; // Slave address (1..247)
  final int transactionId; // For TCP (0..65535)
  final Uint8List pdu;

  ModbusAdu({
    required this.frameType,
    required this.unitId,
    this.transactionId = 0,
    required this.pdu,
  });

  /// Encodes this ADU to raw bytes ready to transmit
  Uint8List encode() {
    switch (frameType) {
      case ModbusFrameType.tcp:
        // MBAP Header (7 bytes):
        // 0..1: Transaction ID (2B)
        // 2..3: Protocol ID = 0 (2B)
        // 4..5: Length (2B) = 1 (Unit ID) + PDU length
        // 6:    Unit ID (1B)
        final length = 1 + pdu.length;
        final raw = Uint8List(7 + pdu.length);
        final bd = ByteData.sublistView(raw);
        bd.setUint16(0, transactionId, Endian.big);
        bd.setUint16(2, 0, Endian.big); // Protocol ID
        bd.setUint16(4, length, Endian.big);
        raw[6] = unitId & 0xFF;
        raw.setRange(7, 7 + pdu.length, pdu);
        return raw;

      case ModbusFrameType.rtu:
        // RTU: Unit ID [1B] + PDU + CRC16 [2B, Low byte first]
        final body = Uint8List(1 + pdu.length);
        body[0] = unitId & 0xFF;
        body.setRange(1, 1 + pdu.length, pdu);
        return ModbusCrc.appendCrc16(body);

      case ModbusFrameType.ascii:
        // ASCII: ':' + Hex(Unit ID + PDU + LRC) + '\r\n'
        final body = Uint8List(1 + pdu.length);
        body[0] = unitId & 0xFF;
        body.setRange(1, 1 + pdu.length, pdu);
        final lrc = ModbusCrc.calculateLrc(body);
        final full = Uint8List(body.length + 1);
        full.setRange(0, body.length, body);
        full[body.length] = lrc;

        final buffer = StringBuffer(':');
        for (final b in full) {
          buffer.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
        }
        buffer.write('\r\n');
        return Uint8List.fromList(buffer.toString().codeUnits);
    }
  }

  /// Decodes raw bytes into ModbusAdu
  static ModbusAdu? decode(Uint8List raw, ModbusFrameType type) {
    if (raw.isEmpty) return null;

    switch (type) {
      case ModbusFrameType.tcp:
        if (raw.length < 7) return null;
        final bd = ByteData.sublistView(raw);
        final txId = bd.getUint16(0, Endian.big);
        final protoId = bd.getUint16(2, Endian.big);
        if (protoId != 0) return null; // Standard Modbus Protocol ID is 0
        final len = bd.getUint16(4, Endian.big);
        if (raw.length < 6 + len) return null;
        final uId = raw[6];
        final pdu = Uint8List.sublistView(raw, 7, 6 + len);
        return ModbusAdu(
          frameType: ModbusFrameType.tcp,
          unitId: uId,
          transactionId: txId,
          pdu: pdu,
        );

      case ModbusFrameType.rtu:
        if (raw.length < 3) return null; // Minimum needed to inspect slave and function code

        int expectedLen = 0;
        final fc = raw[1];
        if ((fc & 0x80) != 0) {
          // Exception response: Slave(1) + FC(1) + ExCode(1) + CRC(2) = 5
          expectedLen = 5;
        } else if (fc == 1 || fc == 2 || fc == 3 || fc == 4) {
          final byteCount = raw[2];
          expectedLen = 3 + byteCount + 2;
        } else if (fc == 5 || fc == 6 || fc == 15 || fc == 16 || fc == 8) {
          expectedLen = 8;
        } else if (fc == 22) {
          expectedLen = 10;
        } else {
          expectedLen = raw.length >= 4 ? raw.length : 0;
        }

        if (expectedLen == 0 || raw.length < expectedLen) {
          return null; // Partial frame received, await more bytes
        }

        final frameBytes = Uint8List.sublistView(raw, 0, expectedLen);
        if (!ModbusCrc.checkCrc16(frameBytes)) {
          throw const FormatException('Modbus RTU frame CRC-16 check failed');
        }
        final uId = frameBytes[0];
        final pdu = Uint8List.sublistView(frameBytes, 1, frameBytes.length - 2);
        return ModbusAdu(
          frameType: ModbusFrameType.rtu,
          unitId: uId,
          pdu: pdu,
        );

      case ModbusFrameType.ascii:
        final str = String.fromCharCodes(raw).trim();
        if (!str.startsWith(':') || str.length < 5) return null;
        final hexPayload = str.substring(1);
        final bytes = <int>[];
        for (int i = 0; i < hexPayload.length - 1; i += 2) {
          final b = int.tryParse(hexPayload.substring(i, i + 2), radix: 16);
          if (b != null) bytes.add(b);
        }
        if (bytes.length < 3 || !ModbusCrc.checkLrc(bytes)) {
          throw const FormatException('Modbus ASCII frame LRC check failed');
        }
        final uId = bytes[0];
        final pdu = Uint8List.fromList(bytes.sublist(1, bytes.length - 1));
        return ModbusAdu(
          frameType: ModbusFrameType.ascii,
          unitId: uId,
          pdu: pdu,
        );
    }
  }
}
