import 'dart:typed_data';

/// Standard Modbus Function Codes
enum ModbusFunctionCode {
  readCoils(0x01, '01: 读线圈状态 (Read Coils)'),
  readDiscreteInputs(0x02, '02: 读离散输入 (Read Discrete Inputs)'),
  readHoldingRegisters(0x03, '03: 读保持寄存器 (Read Holding Registers)'),
  readInputRegisters(0x04, '04: 读输入寄存器 (Read Input Registers)'),
  writeSingleCoil(0x05, '05: 写单个线圈 (Write Single Coil)'),
  writeSingleRegister(0x06, '06: 写单个保持寄存器 (Write Single Register)'),
  readExceptionStatus(0x07, '07: 读异常状态 (Read Exception Status)'),
  diagnostics(0x08, '08: 诊断测试 (Diagnostics)'),
  getCommEventCounter(0x0B, '11: 获取通信事件计数器 (Get Comm Event Counter)'),
  getCommEventLog(0x0C, '12: 获取通信事件记录 (Get Comm Event Log)'),
  writeMultipleCoils(0x0F, '15: 写多个线圈 (Write Multiple Coils)'),
  writeMultipleRegisters(0x10, '16: 写多个保持寄存器 (Write Multiple Registers)'),
  reportSlaveId(0x11, '17: 报告从机标识 (Report Slave ID)'),
  maskWriteRegister(0x16, '22: 屏蔽写寄存器 (Mask Write Register)'),
  readWriteMultipleRegisters(0x17, '23: 读/写多个寄存器 (Read/Write Multiple Registers)');

  final int code;
  final String label;
  const ModbusFunctionCode(this.code, this.label);

  static ModbusFunctionCode? fromCode(int code) {
    for (final fc in ModbusFunctionCode.values) {
      if (fc.code == code) return fc;
    }
    return null;
  }
}

/// Modbus Exception Codes (0x80 + Function Code)
enum ModbusExceptionCode {
  illegalFunction(0x01, '非法功能码 (Illegal Function)'),
  illegalDataAddress(0x02, '非法数据地址 (Illegal Data Address)'),
  illegalDataValue(0x03, '非法数据值 (Illegal Data Value)'),
  slaveDeviceFailure(0x04, '从站设备故障 (Slave Device Failure)'),
  acknowledge(0x05, '确认 (Acknowledge)'),
  slaveDeviceBusy(0x06, '从机忙 (Slave Device Busy)'),
  negativeAcknowledge(0x07, '否定应答 (Negative Acknowledge)'),
  memoryParityError(0x08, '内存奇偶校验错误 (Memory Parity Error)'),
  gatewayPathUnavailable(0x0A, '网关路径不可用 (Gateway Path Unavailable)'),
  gatewayTargetFailed(0x0B, '网关目标设备未响应 (Gateway Target Device Failed to Respond)');

  final int code;
  final String description;
  const ModbusExceptionCode(this.code, this.description);

  static ModbusExceptionCode fromCode(int code) {
    for (final ec in ModbusExceptionCode.values) {
      if (ec.code == code) return ec;
    }
    return ModbusExceptionCode.slaveDeviceFailure;
  }
}

class ModbusResponseException implements Exception {
  final int functionCode;
  final ModbusExceptionCode exceptionCode;

  ModbusResponseException(this.functionCode, this.exceptionCode);

  @override
  String toString() =>
      'ModbusException(FC=0x${functionCode.toRadixString(16).padLeft(2, "0")}, Code=${exceptionCode.code} [${exceptionCode.description}])';
}

/// Modbus Protocol Data Unit (PDU) builder and parser
class ModbusPdu {
  /// Builds Read Coils (FC 01) or Read Discrete Inputs (FC 02) PDU
  static Uint8List buildReadBitsPdu(int functionCode, int startAddress, int quantity) {
    if (quantity < 1 || quantity > 2000) {
      throw ArgumentError('Quantity of coils/inputs must be between 1 and 2000');
    }
    final data = ByteData(5);
    data.setUint8(0, functionCode);
    data.setUint16(1, startAddress, Endian.big);
    data.setUint16(3, quantity, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Builds Read Holding Registers (FC 03) or Read Input Registers (FC 04) PDU
  static Uint8List buildReadRegistersPdu(int functionCode, int startAddress, int quantity) {
    if (quantity < 1 || quantity > 125) {
      throw ArgumentError('Quantity of registers must be between 1 and 125');
    }
    final data = ByteData(5);
    data.setUint8(0, functionCode);
    data.setUint16(1, startAddress, Endian.big);
    data.setUint16(3, quantity, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Builds Write Single Coil (FC 05) PDU
  static Uint8List buildWriteSingleCoilPdu(int coilAddress, bool value) {
    final data = ByteData(5);
    data.setUint8(0, ModbusFunctionCode.writeSingleCoil.code);
    data.setUint16(1, coilAddress, Endian.big);
    data.setUint16(3, value ? 0xFF00 : 0x0000, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Builds Write Single Register (FC 06) PDU
  static Uint8List buildWriteSingleRegisterPdu(int registerAddress, int value) {
    final data = ByteData(5);
    data.setUint8(0, ModbusFunctionCode.writeSingleRegister.code);
    data.setUint16(1, registerAddress, Endian.big);
    data.setUint16(3, value & 0xFFFF, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Builds Write Multiple Coils (FC 15) PDU
  static Uint8List buildWriteMultipleCoilsPdu(int startAddress, List<bool> values) {
    if (values.isEmpty || values.length > 1968) {
      throw ArgumentError('Values count must be between 1 and 1968');
    }
    final byteCount = (values.length + 7) ~/ 8;
    final bytes = Uint8List(6 + byteCount);
    final data = ByteData.sublistView(bytes);

    data.setUint8(0, ModbusFunctionCode.writeMultipleCoils.code);
    data.setUint16(1, startAddress, Endian.big);
    data.setUint16(3, values.length, Endian.big);
    data.setUint8(5, byteCount);

    for (int i = 0; i < values.length; i++) {
      if (values[i]) {
        final byteIndex = 6 + (i ~/ 8);
        final bitIndex = i % 8;
        bytes[byteIndex] |= (1 << bitIndex);
      }
    }
    return bytes;
  }

  /// Builds Write Multiple Registers (FC 16) PDU
  static Uint8List buildWriteMultipleRegistersPdu(int startAddress, List<int> values) {
    if (values.isEmpty || values.length > 123) {
      throw ArgumentError('Values count must be between 1 and 123');
    }
    final byteCount = values.length * 2;
    final bytes = Uint8List(6 + byteCount);
    final data = ByteData.sublistView(bytes);

    data.setUint8(0, ModbusFunctionCode.writeMultipleRegisters.code);
    data.setUint16(1, startAddress, Endian.big);
    data.setUint16(3, values.length, Endian.big);
    data.setUint8(5, byteCount);

    for (int i = 0; i < values.length; i++) {
      data.setUint16(6 + i * 2, values[i] & 0xFFFF, Endian.big);
    }
    return bytes;
  }

  /// Builds Mask Write Register (FC 22) PDU
  static Uint8List buildMaskWriteRegisterPdu(int address, int andMask, int orMask) {
    final data = ByteData(7);
    data.setUint8(0, ModbusFunctionCode.maskWriteRegister.code);
    data.setUint16(1, address, Endian.big);
    data.setUint16(3, andMask & 0xFFFF, Endian.big);
    data.setUint16(5, orMask & 0xFFFF, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Builds Read/Write Multiple Registers (FC 23) PDU
  static Uint8List buildReadWriteMultipleRegistersPdu({
    required int readAddress,
    required int readQuantity,
    required int writeAddress,
    required List<int> writeValues,
  }) {
    final writeByteCount = writeValues.length * 2;
    final bytes = Uint8List(10 + writeByteCount);
    final data = ByteData.sublistView(bytes);

    data.setUint8(0, ModbusFunctionCode.readWriteMultipleRegisters.code);
    data.setUint16(1, readAddress, Endian.big);
    data.setUint16(3, readQuantity, Endian.big);
    data.setUint16(5, writeAddress, Endian.big);
    data.setUint16(7, writeValues.length, Endian.big);
    data.setUint8(9, writeByteCount);

    for (int i = 0; i < writeValues.length; i++) {
      data.setUint16(10 + i * 2, writeValues[i] & 0xFFFF, Endian.big);
    }
    return bytes;
  }

  /// Builds Diagnostics (FC 08) PDU
  static Uint8List buildDiagnosticsPdu(int subFunction, int dataValue) {
    final data = ByteData(5);
    data.setUint8(0, ModbusFunctionCode.diagnostics.code);
    data.setUint16(1, subFunction, Endian.big);
    data.setUint16(3, dataValue, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Builds Simple Function without params (e.g. Report Slave ID 0x11, Read Exception Status 0x07)
  static Uint8List buildSimplePdu(int functionCode) {
    return Uint8List.fromList([functionCode]);
  }

  /// Checks if PDU is an error/exception response
  static bool isExceptionResponse(Uint8List pdu) {
    if (pdu.isEmpty) return false;
    return (pdu[0] & 0x80) != 0;
  }

  /// Parses error/exception PDU
  static ModbusResponseException parseException(Uint8List pdu) {
    final originalFc = pdu[0] & 0x7F;
    final code = pdu.length > 1 ? pdu[1] : 0x04;
    return ModbusResponseException(originalFc, ModbusExceptionCode.fromCode(code));
  }

  /// Parses response bits for FC 01 / FC 02
  static List<bool> parseReadBitsResponse(Uint8List pdu, int expectedCount) {
    if (pdu.length < 2) throw const FormatException('Bit response PDU too short');
    final byteCount = pdu[1];
    if (pdu.length < 2 + byteCount) throw const FormatException('Bit response PDU length mismatch');
    final bits = <bool>[];
    for (int i = 0; i < expectedCount; i++) {
      final byteOffset = 2 + (i ~/ 8);
      if (byteOffset < pdu.length) {
        final bitOffset = i % 8;
        bits.add(((pdu[byteOffset] >> bitOffset) & 1) == 1);
      } else {
        bits.add(false);
      }
    }
    return bits;
  }

  /// Parses response registers for FC 03 / FC 04 / FC 23
  static Uint16List parseReadRegistersResponse(Uint8List pdu) {
    if (pdu.length < 2) throw const FormatException('Register response PDU too short');
    final byteCount = pdu[1];
    final regCount = byteCount ~/ 2;
    final registers = Uint16List(regCount);
    final data = ByteData.sublistView(pdu);
    for (int i = 0; i < regCount; i++) {
      registers[i] = data.getUint16(2 + i * 2, Endian.big);
    }
    return registers;
  }
}
