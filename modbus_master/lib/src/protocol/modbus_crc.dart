import 'dart:typed_data';

/// Modbus CRC-16 (IBM / RTU) and LRC (ASCII) calculations
class ModbusCrc {
  /// Precomputed CRC-16 Modbus table for maximum performance
  static final Uint16List _crcTable = _generateCrcTable();

  static Uint16List _generateCrcTable() {
    final table = Uint16List(256);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc = crc >> 1;
        }
      }
      table[i] = crc & 0xFFFF;
    }
    return table;
  }

  /// Calculates 16-bit Modbus CRC for the given byte buffer.
  /// Standard polynomial: 0xA001, initial value: 0xFFFF.
  static int calculateCrc16(List<int> bytes, [int offset = 0, int? length]) {
    final len = length ?? (bytes.length - offset);
    int crc = 0xFFFF;
    for (int i = offset; i < offset + len; i++) {
      final index = (crc ^ bytes[i]) & 0xFF;
      crc = (crc >> 8) ^ _crcTable[index];
    }
    return crc & 0xFFFF;
  }

  /// Checks if the CRC at the end of the given RTU frame (2 bytes, little-endian) is valid.
  static bool checkCrc16(List<int> frame) {
    if (frame.length < 3) return false;
    final expectedCrc = calculateCrc16(frame, 0, frame.length - 2);
    final actualCrc = frame[frame.length - 2] | (frame[frame.length - 1] << 8);
    return expectedCrc == actualCrc;
  }

  /// Appends 2-byte CRC16 (little-endian) to given bytes and returns a new list.
  static Uint8List appendCrc16(List<int> bytes) {
    final crc = calculateCrc16(bytes);
    final result = Uint8List(bytes.length + 2);
    result.setRange(0, bytes.length, bytes);
    result[bytes.length] = crc & 0xFF;        // Low byte
    result[bytes.length + 1] = (crc >> 8) & 0xFF; // High byte
    return result;
  }

  /// Calculates Longitudinal Redundancy Check (LRC) for Modbus ASCII.
  static int calculateLrc(List<int> bytes, [int offset = 0, int? length]) {
    final len = length ?? (bytes.length - offset);
    int sum = 0;
    for (int i = offset; i < offset + len; i++) {
      sum = (sum + bytes[i]) & 0xFF;
    }
    return ((-sum) & 0xFF);
  }

  /// Checks if the LRC byte in a Modbus ASCII message is valid.
  static bool checkLrc(List<int> bytes) {
    if (bytes.length < 2) return false;
    final expectedLrc = calculateLrc(bytes, 0, bytes.length - 1);
    return expectedLrc == bytes.last;
  }
}
