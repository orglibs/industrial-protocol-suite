import 'dart:typed_data';
import 'modbus_crc.dart';

enum ModbusFrameType {
  tcp('Modbus TCP (MBAP Header)'),
  rtu('Modbus RTU (CRC-16)'),
  rtuOverTcp('Modbus RTU over TCP'),
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

  /// Encodes this ADU to raw bytes ready to transmit back to master
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
      case ModbusFrameType.rtuOverTcp:
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

  /// Attempts to extract a complete Modbus request ADU received by the slave.
  /// Returns `(adu, consumedByteCount)` or null if not enough bytes.
  static ({ModbusAdu adu, int consumed})? extractRequest(Uint8List buffer, ModbusFrameType type) {
    if (buffer.isEmpty) return null;

    switch (type) {
      case ModbusFrameType.tcp:
        if (buffer.length < 7) return null;
        final bd = ByteData.sublistView(buffer);
        final protoId = bd.getUint16(2, Endian.big);
        if (protoId != 0) {
          // Sync issue: discard one byte
          return null;
        }
        final len = bd.getUint16(4, Endian.big);
        final totalLen = 6 + len;
        if (buffer.length < totalLen) return null; // Wait for full frame

        final txId = bd.getUint16(0, Endian.big);
        final uId = buffer[6];
        final pdu = Uint8List.sublistView(buffer, 7, totalLen);
        final adu = ModbusAdu(
          frameType: ModbusFrameType.tcp,
          unitId: uId,
          transactionId: txId,
          pdu: pdu,
        );
        return (adu: adu, consumed: totalLen);

      case ModbusFrameType.rtu:
      case ModbusFrameType.rtuOverTcp:
        if (buffer.length < 4) return null;

        // In Modbus RTU, master requests have specific lengths based on FC:
        final fc = buffer[1];
        int expectedLen = 0;

        if (fc == 1 || fc == 2 || fc == 3 || fc == 4 || fc == 5 || fc == 6 || fc == 8) {
          // UnitId(1) + FC(1) + Addr(2) + Value/Count(2) + CRC(2) = 8 bytes
          expectedLen = 8;
        } else if (fc == 15 || fc == 16) {
          // UnitId(1) + FC(1) + Addr(2) + Qty(2) + ByteCount(1) + Data(ByteCount) + CRC(2) = 9 + ByteCount
          if (buffer.length < 7) return null;
          final byteCount = buffer[6];
          expectedLen = 7 + byteCount + 2;
        } else if (fc == 17) {
          // Report Slave ID: UnitId(1) + FC(1) + CRC(2) = 4
          expectedLen = 4;
        } else if (fc == 22) {
          // Mask Write Register: UnitId(1) + FC(1) + Addr(2) + And(2) + Or(2) + CRC(2) = 10
          expectedLen = 10;
        } else if (fc == 23) {
          // Read/Write Multiple: UnitId(1) + FC(1) + ReadAddr(2) + ReadQty(2) + WriteAddr(2) + WriteQty(2) + WriteByteCount(1) + Data + CRC(2)
          if (buffer.length < 11) return null;
          final byteCount = buffer[10];
          expectedLen = 11 + byteCount + 2;
        } else {
          // Unknown or unsupported FC: try looking for valid CRC within buffer
          expectedLen = 8;
        }

        if (buffer.length < expectedLen) return null;

        final candidate = Uint8List.sublistView(buffer, 0, expectedLen);
        if (ModbusCrc.checkCrc16(candidate)) {
          final uId = candidate[0];
          final pdu = Uint8List.sublistView(candidate, 1, expectedLen - 2);
          final adu = ModbusAdu(
            frameType: type,
            unitId: uId,
            pdu: pdu,
          );
          return (adu: adu, consumed: expectedLen);
        }

        // If CRC failed, could be alignment mismatch. Return null so caller can handle or scan.
        return null;

      case ModbusFrameType.ascii:
        final str = String.fromCharCodes(buffer);
        final startIdx = str.indexOf(':');
        if (startIdx < 0) return null;
        final endIdx = str.indexOf('\r\n', startIdx);
        if (endIdx < 0) return null;

        final rawAscii = str.substring(startIdx + 1, endIdx).trim();
        final bytes = <int>[];
        for (int i = 0; i < rawAscii.length - 1; i += 2) {
          final b = int.tryParse(rawAscii.substring(i, i + 2), radix: 16);
          if (b != null) bytes.add(b);
        }
        if (bytes.length < 3 || !ModbusCrc.checkLrc(bytes)) {
          return null;
        }

        final uId = bytes[0];
        final pdu = Uint8List.fromList(bytes.sublist(1, bytes.length - 1));
        final adu = ModbusAdu(
          frameType: ModbusFrameType.ascii,
          unitId: uId,
          pdu: pdu,
        );
        return (adu: adu, consumed: endIdx + 2);
    }
  }
}
