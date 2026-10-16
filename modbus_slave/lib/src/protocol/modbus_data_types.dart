import 'dart:typed_data';

/// Modbus 32-bit and 64-bit Byte Order / Endianness
enum ModbusByteOrder {
  abcd('ABCD (高字优先/大端 Big-Endian)'),
  cdab('CDAB (低字优先/字交换 Little-Endian Word Swap)'),
  badc('BADC (字节交换 Byte Swap)'),
  dcba('DCBA (低字优先/小端 Little-Endian)');

  final String label;
  const ModbusByteOrder(this.label);
}

/// Register Data Display Formats
enum RegisterDataFormat {
  hex16('16位 十六进制 (Hex 16)'),
  bin16('16位 二进制 (Bin 16)'),
  signed16('16位 有符号整数 (Int16)'),
  unsigned16('16位 无符号整数 (UInt16)'),
  signed32('32位 有符号整数 (Int32)'),
  unsigned32('32位 无符号整数 (UInt32)'),
  float32('32位 单精度浮点 (Float)'),
  signed64('64位 有符号整数 (Int64)'),
  double64('64位 双精度浮点 (Double)'),
  asciiString('ASCII 字符串');

  final String label;
  const RegisterDataFormat(this.label);

  int get wordCount {
    switch (this) {
      case RegisterDataFormat.hex16:
      case RegisterDataFormat.bin16:
      case RegisterDataFormat.signed16:
      case RegisterDataFormat.unsigned16:
      case RegisterDataFormat.asciiString:
        return 1;
      case RegisterDataFormat.signed32:
      case RegisterDataFormat.unsigned32:
      case RegisterDataFormat.float32:
        return 2;
      case RegisterDataFormat.signed64:
      case RegisterDataFormat.double64:
        return 4;
    }
  }
}

class ModbusDataConverter {
  /// Converts a single 16-bit register value (0..65535) into display string
  static String formatSingleRegister(int rawValue, RegisterDataFormat format) {
    final v = rawValue & 0xFFFF;
    switch (format) {
      case RegisterDataFormat.hex16:
        return '0x${v.toRadixString(16).padLeft(4, "0").toUpperCase()}';
      case RegisterDataFormat.bin16:
        final b = v.toRadixString(2).padLeft(16, '0');
        return '${b.substring(0, 4)} ${b.substring(4, 8)} ${b.substring(8, 12)} ${b.substring(12, 16)}';
      case RegisterDataFormat.signed16:
        final s = v > 32767 ? v - 65536 : v;
        return s.toString();
      case RegisterDataFormat.unsigned16:
        return v.toString();
      default:
        return v.toString();
    }
  }

  /// Reorders 4 bytes according to the given ModbusByteOrder
  static Uint8List reorder32Bytes(Uint8List fourBytes, ModbusByteOrder order) {
    if (fourBytes.length < 4) return fourBytes;
    final a = fourBytes[0];
    final b = fourBytes[1];
    final c = fourBytes[2];
    final d = fourBytes[3];

    switch (order) {
      case ModbusByteOrder.abcd:
        return Uint8List.fromList([a, b, c, d]);
      case ModbusByteOrder.cdab:
        return Uint8List.fromList([c, d, a, b]);
      case ModbusByteOrder.badc:
        return Uint8List.fromList([b, a, d, c]);
      case ModbusByteOrder.dcba:
        return Uint8List.fromList([d, c, b, a]);
    }
  }

  /// Inverse reorder 4 bytes from normalized back to specified ModbusByteOrder
  static Uint8List inverseReorder32Bytes(Uint8List normalized, ModbusByteOrder order) {
    if (normalized.length < 4) return normalized;
    final a = normalized[0];
    final b = normalized[1];
    final c = normalized[2];
    final d = normalized[3];

    switch (order) {
      case ModbusByteOrder.abcd:
        return Uint8List.fromList([a, b, c, d]);
      case ModbusByteOrder.cdab:
        return Uint8List.fromList([c, d, a, b]);
      case ModbusByteOrder.badc:
        return Uint8List.fromList([b, a, d, c]);
      case ModbusByteOrder.dcba:
        return Uint8List.fromList([d, c, b, a]);
    }
  }

  /// Parses two 16-bit registers into a 32-bit Float with specified ByteOrder
  static double registersToFloat32(int reg1, int reg2, [ModbusByteOrder order = ModbusByteOrder.abcd]) {
    final raw = Uint8List(4);
    final bd = ByteData.sublistView(raw);
    bd.setUint16(0, reg1 & 0xFFFF, Endian.big);
    bd.setUint16(2, reg2 & 0xFFFF, Endian.big);

    final normalized = reorder32Bytes(raw, order);
    final normalBd = ByteData.sublistView(normalized);
    return normalBd.getFloat32(0, Endian.big);
  }

  /// Converts a Float32 into two 16-bit registers with specified ByteOrder
  static List<int> float32ToRegisters(double value, [ModbusByteOrder order = ModbusByteOrder.abcd]) {
    final raw = Uint8List(4);
    final bd = ByteData.sublistView(raw);
    bd.setFloat32(0, value, Endian.big);

    final stored = inverseReorder32Bytes(raw, order);
    final storedBd = ByteData.sublistView(stored);
    return [storedBd.getUint16(0, Endian.big), storedBd.getUint16(2, Endian.big)];
  }

  /// Parses two 16-bit registers into a 32-bit signed integer
  static int registersToInt32(int reg1, int reg2, [ModbusByteOrder order = ModbusByteOrder.abcd]) {
    final raw = Uint8List(4);
    final bd = ByteData.sublistView(raw);
    bd.setUint16(0, reg1 & 0xFFFF, Endian.big);
    bd.setUint16(2, reg2 & 0xFFFF, Endian.big);

    final normalized = reorder32Bytes(raw, order);
    final normalBd = ByteData.sublistView(normalized);
    return normalBd.getInt32(0, Endian.big);
  }

  /// Converts an Int32 into two 16-bit registers
  static List<int> int32ToRegisters(int value, [ModbusByteOrder order = ModbusByteOrder.abcd]) {
    final raw = Uint8List(4);
    final bd = ByteData.sublistView(raw);
    bd.setInt32(0, value, Endian.big);

    final stored = inverseReorder32Bytes(raw, order);
    final storedBd = ByteData.sublistView(stored);
    return [storedBd.getUint16(0, Endian.big), storedBd.getUint16(2, Endian.big)];
  }

  /// Parses two 16-bit registers into a 32-bit unsigned integer
  static int registersToUInt32(int reg1, int reg2, [ModbusByteOrder order = ModbusByteOrder.abcd]) {
    final raw = Uint8List(4);
    final bd = ByteData.sublistView(raw);
    bd.setUint16(0, reg1 & 0xFFFF, Endian.big);
    bd.setUint16(2, reg2 & 0xFFFF, Endian.big);

    final normalized = reorder32Bytes(raw, order);
    final normalBd = ByteData.sublistView(normalized);
    return normalBd.getUint32(0, Endian.big);
  }

  /// Converts a UInt32 into two 16-bit registers
  static List<int> uint32ToRegisters(int value, [ModbusByteOrder order = ModbusByteOrder.abcd]) {
    final raw = Uint8List(4);
    final bd = ByteData.sublistView(raw);
    bd.setUint32(0, value, Endian.big);

    final stored = inverseReorder32Bytes(raw, order);
    final storedBd = ByteData.sublistView(stored);
    return [storedBd.getUint16(0, Endian.big), storedBd.getUint16(2, Endian.big)];
  }

  /// Parses four 16-bit registers into a 64-bit Double float
  static double registersToDouble64(int r1, int r2, int r3, int r4) {
    final raw = Uint8List(8);
    final bd = ByteData.sublistView(raw);
    bd.setUint16(0, r1 & 0xFFFF, Endian.big);
    bd.setUint16(2, r2 & 0xFFFF, Endian.big);
    bd.setUint16(4, r3 & 0xFFFF, Endian.big);
    bd.setUint16(6, r4 & 0xFFFF, Endian.big);
    return bd.getFloat64(0, Endian.big);
  }

  /// Converts a Double64 into four 16-bit registers
  static List<int> double64ToRegisters(double value) {
    final raw = Uint8List(8);
    final bd = ByteData.sublistView(raw);
    bd.setFloat64(0, value, Endian.big);
    return [
      bd.getUint16(0, Endian.big),
      bd.getUint16(2, Endian.big),
      bd.getUint16(4, Endian.big),
      bd.getUint16(6, Endian.big),
    ];
  }

  /// Parses four 16-bit registers into a 64-bit signed integer
  static int registersToInt64(int r1, int r2, int r3, int r4) {
    final raw = Uint8List(8);
    final bd = ByteData.sublistView(raw);
    bd.setUint16(0, r1 & 0xFFFF, Endian.big);
    bd.setUint16(2, r2 & 0xFFFF, Endian.big);
    bd.setUint16(4, r3 & 0xFFFF, Endian.big);
    bd.setUint16(6, r4 & 0xFFFF, Endian.big);
    return bd.getInt64(0, Endian.big);
  }

  /// Converts an Int64 into four 16-bit registers
  static List<int> int64ToRegisters(int value) {
    final raw = Uint8List(8);
    final bd = ByteData.sublistView(raw);
    bd.setInt64(0, value, Endian.big);
    return [
      bd.getUint16(0, Endian.big),
      bd.getUint16(2, Endian.big),
      bd.getUint16(4, Endian.big),
      bd.getUint16(6, Endian.big),
    ];
  }

  /// Converts an ASCII string into 16-bit registers
  static List<int> stringToRegisters(String str) {
    final bytes = str.codeUnits;
    final regs = <int>[];
    for (int i = 0; i < bytes.length; i += 2) {
      final high = bytes[i];
      final low = (i + 1 < bytes.length) ? bytes[i + 1] : 0;
      regs.add((high << 8) | low);
    }
    return regs;
  }

  /// Converts 16-bit registers into an ASCII string
  static String registersToString(List<int> regs) {
    final chars = <int>[];
    for (final r in regs) {
      final high = (r >> 8) & 0xFF;
      final low = r & 0xFF;
      if (high != 0) chars.add(high);
      if (low != 0) chars.add(low);
    }
    return String.fromCharCodes(chars);
  }

  /// Converts a list of 16-bit registers into byte array (big endian)
  static Uint8List registersToBytes(List<int> registers) {
    final bytes = Uint8List(registers.length * 2);
    final bd = ByteData.sublistView(bytes);
    for (int i = 0; i < registers.length; i++) {
      bd.setUint16(i * 2, registers[i] & 0xFFFF, Endian.big);
    }
    return bytes;
  }

  /// Parses bytes into a typed value based on format and byte order
  static dynamic parseValue(Uint8List bytes, RegisterDataFormat format, [ModbusByteOrder byteOrder = ModbusByteOrder.abcd]) {
    if (bytes.isEmpty) return 0;
    final bd = ByteData.sublistView(bytes);
    switch (format) {
      case RegisterDataFormat.hex16:
        return '0x${bd.getUint16(0, Endian.big).toRadixString(16).padLeft(4, "0").toUpperCase()}';
      case RegisterDataFormat.bin16:
        return bd.getUint16(0, Endian.big).toRadixString(2).padLeft(16, "0");
      case RegisterDataFormat.signed16:
        return bd.getInt16(0, Endian.big);
      case RegisterDataFormat.unsigned16:
        return bd.getUint16(0, Endian.big);
      case RegisterDataFormat.signed32:
        if (bytes.length < 4) return 0;
        final reordered = reorder32Bytes(bytes.sublist(0, 4), byteOrder);
        return ByteData.sublistView(reordered).getInt32(0, Endian.big);
      case RegisterDataFormat.unsigned32:
        if (bytes.length < 4) return 0;
        final reordered = reorder32Bytes(bytes.sublist(0, 4), byteOrder);
        return ByteData.sublistView(reordered).getUint32(0, Endian.big);
      case RegisterDataFormat.float32:
        if (bytes.length < 4) return 0.0;
        final reordered = reorder32Bytes(bytes.sublist(0, 4), byteOrder);
        return ByteData.sublistView(reordered).getFloat32(0, Endian.big);
      case RegisterDataFormat.signed64:
        if (bytes.length < 8) return 0;
        return bd.getInt64(0, Endian.big);
      case RegisterDataFormat.double64:
        if (bytes.length < 8) return 0.0;
        return bd.getFloat64(0, Endian.big);
      case RegisterDataFormat.asciiString:
        return String.fromCharCodes(bytes.where((b) => b != 0));
    }
  }

  /// Parses user input text according to format into register word values
  static List<int>? parseInputTextToWords(String text, RegisterDataFormat format, [ModbusByteOrder byteOrder = ModbusByteOrder.abcd]) {
    final t = text.trim();
    if (t.isEmpty) return null;

    try {
      switch (format) {
        case RegisterDataFormat.hex16:
          var clean = t;
          if (clean.toLowerCase().startsWith('0x')) clean = clean.substring(2);
          final val = int.parse(clean, radix: 16);
          return [val & 0xFFFF];

        case RegisterDataFormat.bin16:
          final clean = t.replaceAll(' ', '');
          final val = int.parse(clean, radix: 2);
          return [val & 0xFFFF];

        case RegisterDataFormat.signed16:
          final val = int.parse(t);
          return [val & 0xFFFF];

        case RegisterDataFormat.unsigned16:
          final val = int.parse(t);
          return [val & 0xFFFF];

        case RegisterDataFormat.signed32:
          final val = int.parse(t);
          return int32ToRegisters(val, byteOrder);

        case RegisterDataFormat.unsigned32:
          final val = int.parse(t);
          return uint32ToRegisters(val, byteOrder);

        case RegisterDataFormat.float32:
          final val = double.parse(t);
          return float32ToRegisters(val, byteOrder);

        case RegisterDataFormat.signed64:
          final val = int.parse(t);
          return int64ToRegisters(val);

        case RegisterDataFormat.double64:
          final val = double.parse(t);
          return double64ToRegisters(val);

        case RegisterDataFormat.asciiString:
          return stringToRegisters(t);
      }
    } catch (_) {
      return null;
    }
  }
}
