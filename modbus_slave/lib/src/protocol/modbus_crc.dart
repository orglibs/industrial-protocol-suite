import 'dart:typed_data';

class ModbusCrc {
  /// Standard Modbus RTU CRC-16 table (polynomial 0xA001, initial 0xFFFF)
  static final Uint16List _crc16Table = _initCrc16Table();

  static Uint16List _initCrc16Table() {
    final table = Uint16List(256);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int bit = 0; bit < 8; bit++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc >>= 1;
        }
      }
      table[i] = crc & 0xFFFF;
    }
    return table;
  }

  /// Calculates 16-bit CRC for Modbus RTU frames.
  /// Returns 16-bit unsigned integer (Low byte in bits 0..7, High byte in bits 8..15).
  static int calculateCrc16(List<int> bytes, [int start = 0, int? end]) {
    final stop = end ?? bytes.length;
    int crc = 0xFFFF;
    for (int i = start; i < stop; i++) {
      final index = (crc ^ bytes[i]) & 0xFF;
      crc = (crc >> 8) ^ _crc16Table[index];
    }
    return crc & 0xFFFF;
  }

  /// Checks if the last 2 bytes of the frame match the expected CRC16.
  static bool checkCrc16(List<int> frame) {
    if (frame.length < 3) return false;
    final payloadLen = frame.length - 2;
    final calculated = calculateCrc16(frame, 0, payloadLen);
    final expectedLow = frame[payloadLen];
    final expectedHigh = frame[payloadLen + 1];
    return (calculated & 0xFF) == expectedLow && ((calculated >> 8) & 0xFF) == expectedHigh;
  }

  /// Appends 2-byte CRC16 (Low byte first) to the byte list and returns new Uint8List.
  static Uint8List appendCrc16(List<int> bytes) {
    final crc = calculateCrc16(bytes);
    final result = Uint8List(bytes.length + 2);
    result.setRange(0, bytes.length, bytes);
    result[bytes.length] = crc & 0xFF;         // Low byte
    result[bytes.length + 1] = (crc >> 8) & 0xFF; // High byte
    return result;
  }

  /// Calculates Modbus ASCII LRC (Longitudinal Redundancy Check)
  static int calculateLrc(List<int> bytes, [int start = 0, int? end]) {
    final stop = end ?? bytes.length;
    int sum = 0;
    for (int i = start; i < stop; i++) {
      sum += bytes[i];
    }
    return ((-sum) & 0xFF);
  }

  /// Checks if the last byte matches the LRC of the preceding payload
  static bool checkLrc(List<int> bytes) {
    if (bytes.length < 2) return false;
    final expected = bytes.last;
    final calculated = calculateLrc(bytes, 0, bytes.length - 1);
    return calculated == expected;
  }
}
