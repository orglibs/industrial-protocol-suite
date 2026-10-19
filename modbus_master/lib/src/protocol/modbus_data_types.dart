import 'dart:typed_data';
import '../i18n/app_i18n.dart';

/// Modbus 32-bit and 64-bit Byte Order / Endianness
enum ModbusByteOrder {
  abcd,
  cdab,
  badc,
  dcba;

  String get label {
    switch (this) {
      case ModbusByteOrder.abcd:
        return AppI18n.instance.t('orderAbcd');
      case ModbusByteOrder.cdab:
        return AppI18n.instance.t('orderCdab');
      case ModbusByteOrder.badc:
        return AppI18n.instance.t('orderBadc');
      case ModbusByteOrder.dcba:
        return AppI18n.instance.t('orderDcba');
    }
  }
}

/// Register Data Display Formats
enum RegisterDataFormat {
  hex16,
  bin16,
  signed16,
  unsigned16,
  signed32,
  unsigned32,
  float32,
  signed64,
  double64,
  asciiString;

  String get label {
    switch (this) {
      case RegisterDataFormat.hex16:
        return AppI18n.instance.t('fmtHex16');
      case RegisterDataFormat.bin16:
        return AppI18n.instance.t('fmtBin16');
      case RegisterDataFormat.signed16:
        return AppI18n.instance.t('fmtSigned16');
      case RegisterDataFormat.unsigned16:
        return AppI18n.instance.t('fmtUnsigned16');
      case RegisterDataFormat.signed32:
        return AppI18n.instance.t('fmtSigned32');
      case RegisterDataFormat.unsigned32:
        return AppI18n.instance.t('fmtUnsigned32');
      case RegisterDataFormat.float32:
        return AppI18n.instance.t('fmtFloat32');
      case RegisterDataFormat.signed64:
        return AppI18n.instance.t('fmtSigned64');
      case RegisterDataFormat.double64:
        return AppI18n.instance.t('fmtDouble64');
      case RegisterDataFormat.asciiString:
        return AppI18n.instance.t('fmtAscii');
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
  static (int, int) float32ToRegisters(double value, [ModbusByteOrder order = ModbusByteOrder.abcd]) {
    final raw = Uint8List(4);
    final bd = ByteData.sublistView(raw);
    bd.setFloat32(0, value, Endian.big);

    // Inverse reorder to match storage
    final a = raw[0];
    final b = raw[1];
    final c = raw[2];
    final d = raw[3];

    Uint8List stored;
    switch (order) {
      case ModbusByteOrder.abcd:
        stored = Uint8List.fromList([a, b, c, d]);
        break;
      case ModbusByteOrder.cdab:
        stored = Uint8List.fromList([c, d, a, b]);
        break;
      case ModbusByteOrder.badc:
        stored = Uint8List.fromList([b, a, d, c]);
        break;
      case ModbusByteOrder.dcba:
        stored = Uint8List.fromList([d, c, b, a]);
        break;
    }

    final storedBd = ByteData.sublistView(stored);
    return (storedBd.getUint16(0, Endian.big), storedBd.getUint16(2, Endian.big));
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
}

