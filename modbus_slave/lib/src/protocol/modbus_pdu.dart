import 'dart:convert';
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

class ModbusPdu {
  // ================= RESPONSE BUILDERS =================

  /// Builds Exception Response PDU: [FC | 0x80, ExceptionCode]
  static Uint8List buildExceptionResponse(int functionCode, ModbusExceptionCode exceptionCode) {
    return Uint8List.fromList([(functionCode | 0x80) & 0xFF, exceptionCode.code]);
  }

  /// Builds Read Bits Response (FC 01 / FC 02): [FC, ByteCount, BitBytes...]
  static Uint8List buildReadBitsResponse(int functionCode, List<bool> bits) {
    final byteCount = (bits.length + 7) ~/ 8;
    final bytes = Uint8List(2 + byteCount);
    bytes[0] = functionCode & 0xFF;
    bytes[1] = byteCount;

    for (int i = 0; i < bits.length; i++) {
      if (bits[i]) {
        final byteOffset = 2 + (i ~/ 8);
        final bitOffset = i % 8;
        bytes[byteOffset] |= (1 << bitOffset);
      }
    }
    return bytes;
  }

  /// Builds Read Registers Response (FC 03 / FC 04 / FC 23 read part): [FC, ByteCount, RegisterBytes...]
  static Uint8List buildReadRegistersResponse(int functionCode, List<int> registers) {
    final byteCount = registers.length * 2;
    final bytes = Uint8List(2 + byteCount);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = functionCode & 0xFF;
    bytes[1] = byteCount;

    for (int i = 0; i < registers.length; i++) {
      bd.setUint16(2 + i * 2, registers[i] & 0xFFFF, Endian.big);
    }
    return bytes;
  }

  /// Builds Write Single Coil Response (FC 05): Echoes Address and Value
  static Uint8List buildWriteSingleCoilResponse(int address, bool value) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.writeSingleCoil.code;
    bd.setUint16(1, address, Endian.big);
    bd.setUint16(3, value ? 0xFF00 : 0x0000, Endian.big);
    return bytes;
  }

  /// Builds Write Single Register Response (FC 06): Echoes Address and Value
  static Uint8List buildWriteSingleRegisterResponse(int address, int value) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.writeSingleRegister.code;
    bd.setUint16(1, address, Endian.big);
    bd.setUint16(3, value & 0xFFFF, Endian.big);
    return bytes;
  }

  /// Builds Write Multiple Coils Response (FC 15): [FC, StartAddr(2), Quantity(2)]
  static Uint8List buildWriteMultipleCoilsResponse(int startAddress, int quantity) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.writeMultipleCoils.code;
    bd.setUint16(1, startAddress, Endian.big);
    bd.setUint16(3, quantity, Endian.big);
    return bytes;
  }

  /// Builds Write Multiple Registers Response (FC 16): [FC, StartAddr(2), Quantity(2)]
  static Uint8List buildWriteMultipleRegistersResponse(int startAddress, int quantity) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.writeMultipleRegisters.code;
    bd.setUint16(1, startAddress, Endian.big);
    bd.setUint16(3, quantity, Endian.big);
    return bytes;
  }

  /// Builds Diagnostics Response (FC 08): Echoes SubFunction and Data
  static Uint8List buildDiagnosticsResponse(int subFunction, int dataValue) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.diagnostics.code;
    bd.setUint16(1, subFunction, Endian.big);
    bd.setUint16(3, dataValue & 0xFFFF, Endian.big);
    return bytes;
  }

  /// Builds Mask Write Register Response (FC 22): Echoes Address, AndMask, OrMask
  static Uint8List buildMaskWriteRegisterResponse(int address, int andMask, int orMask) {
    final bytes = Uint8List(7);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.maskWriteRegister.code;
    bd.setUint16(1, address, Endian.big);
    bd.setUint16(3, andMask & 0xFFFF, Endian.big);
    bd.setUint16(5, orMask & 0xFFFF, Endian.big);
    return bytes;
  }

  /// Builds Report Slave ID Response (FC 17): [FC, ByteCount, SlaveId, RunIndicatorStatus, ...Data]
  static Uint8List buildReportSlaveIdResponse(int slaveId, bool isRunning, String additionalData) {
    final strBytes = utf8.encode(additionalData);
    final byteCount = 2 + strBytes.length;
    final bytes = Uint8List(2 + byteCount);
    bytes[0] = ModbusFunctionCode.reportSlaveId.code;
    bytes[1] = byteCount;
    bytes[2] = slaveId & 0xFF;
    bytes[3] = isRunning ? 0xFF : 0x00;
    bytes.setRange(4, 4 + strBytes.length, strBytes);
    return bytes;
  }

  // ================= REQUEST PARSERS =================

  /// Parses Read Bits Request (FC 01 / FC 02): (startAddress, quantity)
  static ({int startAddress, int quantity}) parseReadBitsRequest(Uint8List pdu) {
    if (pdu.length < 5) throw FormatException('Read bits request PDU too short');
    final bd = ByteData.sublistView(pdu);
    return (
      startAddress: bd.getUint16(1, Endian.big),
      quantity: bd.getUint16(3, Endian.big),
    );
  }

  /// Parses Read Registers Request (FC 03 / FC 04): (startAddress, quantity)
  static ({int startAddress, int quantity}) parseReadRegistersRequest(Uint8List pdu) {
    if (pdu.length < 5) throw FormatException('Read registers request PDU too short');
    final bd = ByteData.sublistView(pdu);
    return (
      startAddress: bd.getUint16(1, Endian.big),
      quantity: bd.getUint16(3, Endian.big),
    );
  }

  /// Parses Write Single Coil Request (FC 05): (address, value)
  static ({int address, bool value}) parseWriteSingleCoilRequest(Uint8List pdu) {
    if (pdu.length < 5) throw FormatException('Write single coil request PDU too short');
    final bd = ByteData.sublistView(pdu);
    final addr = bd.getUint16(1, Endian.big);
    final val = bd.getUint16(3, Endian.big);
    return (address: addr, value: val == 0xFF00);
  }

  /// Parses Write Single Register Request (FC 06): (address, value)
  static ({int address, int value}) parseWriteSingleRegisterRequest(Uint8List pdu) {
    if (pdu.length < 5) throw FormatException('Write single register request PDU too short');
    final bd = ByteData.sublistView(pdu);
    final addr = bd.getUint16(1, Endian.big);
    final val = bd.getUint16(3, Endian.big);
    return (address: addr, value: val);
  }

  /// Parses Write Multiple Coils Request (FC 15): (startAddress, quantity, values)
  static ({int startAddress, int quantity, List<bool> values}) parseWriteMultipleCoilsRequest(Uint8List pdu) {
    if (pdu.length < 6) throw FormatException('Write multiple coils request PDU too short');
    final bd = ByteData.sublistView(pdu);
    final startAddr = bd.getUint16(1, Endian.big);
    final quantity = bd.getUint16(3, Endian.big);
    final byteCount = pdu[5];

    if (pdu.length < 6 + byteCount) throw FormatException('Write multiple coils byte count mismatch');

    final values = <bool>[];
    for (int i = 0; i < quantity; i++) {
      final byteOffset = 6 + (i ~/ 8);
      final bitOffset = i % 8;
      values.add(((pdu[byteOffset] >> bitOffset) & 1) == 1);
    }

    return (startAddress: startAddr, quantity: quantity, values: values);
  }

  /// Parses Write Multiple Registers Request (FC 16): (startAddress, quantity, values)
  static ({int startAddress, int quantity, List<int> values}) parseWriteMultipleRegistersRequest(Uint8List pdu) {
    if (pdu.length < 6) throw FormatException('Write multiple registers request PDU too short');
    final bd = ByteData.sublistView(pdu);
    final startAddr = bd.getUint16(1, Endian.big);
    final quantity = bd.getUint16(3, Endian.big);
    final byteCount = pdu[5];

    if (pdu.length < 6 + byteCount || byteCount != quantity * 2) {
      throw FormatException('Write multiple registers byte count mismatch');
    }

    final values = <int>[];
    for (int i = 0; i < quantity; i++) {
      values.add(bd.getUint16(6 + i * 2, Endian.big));
    }

    return (startAddress: startAddr, quantity: quantity, values: values);
  }

  /// Parses Diagnostics Request (FC 08): (subFunction, dataValue)
  static ({int subFunction, int dataValue}) parseDiagnosticsRequest(Uint8List pdu) {
    if (pdu.length < 5) throw FormatException('Diagnostics request PDU too short');
    final bd = ByteData.sublistView(pdu);
    return (
      subFunction: bd.getUint16(1, Endian.big),
      dataValue: bd.getUint16(3, Endian.big),
    );
  }

  /// Parses Mask Write Register Request (FC 22): (address, andMask, orMask)
  static ({int address, int andMask, int orMask}) parseMaskWriteRegisterRequest(Uint8List pdu) {
    if (pdu.length < 7) throw FormatException('Mask write register request PDU too short');
    final bd = ByteData.sublistView(pdu);
    return (
      address: bd.getUint16(1, Endian.big),
      andMask: bd.getUint16(3, Endian.big),
      orMask: bd.getUint16(5, Endian.big),
    );
  }

  /// Parses Read/Write Multiple Registers Request (FC 23)
  static ({
    int readAddress,
    int readQuantity,
    int writeAddress,
    int writeQuantity,
    List<int> writeValues,
  }) parseReadWriteMultipleRegistersRequest(Uint8List pdu) {
    if (pdu.length < 10) throw FormatException('Read/Write multiple registers request PDU too short');
    final bd = ByteData.sublistView(pdu);
    final readAddr = bd.getUint16(1, Endian.big);
    final readQty = bd.getUint16(3, Endian.big);
    final writeAddr = bd.getUint16(5, Endian.big);
    final writeQty = bd.getUint16(7, Endian.big);
    final writeByteCount = pdu[9];

    if (pdu.length < 10 + writeByteCount || writeByteCount != writeQty * 2) {
      throw FormatException('Read/Write multiple registers byte count mismatch');
    }

    final writeValues = <int>[];
    for (int i = 0; i < writeQty; i++) {
      writeValues.add(bd.getUint16(10 + i * 2, Endian.big));
    }

    return (
      readAddress: readAddr,
      readQuantity: readQty,
      writeAddress: writeAddr,
      writeQuantity: writeQty,
      writeValues: writeValues,
    );
  }

  // ================= CLIENT REQUEST BUILDERS & RESPONSE PARSERS =================

  /// Builds Read Bits Request PDU (FC 01 / FC 02)
  static Uint8List buildReadBitsPdu(int functionCode, int startAddress, int quantity) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = functionCode & 0xFF;
    bd.setUint16(1, startAddress, Endian.big);
    bd.setUint16(3, quantity, Endian.big);
    return bytes;
  }

  /// Builds Read Registers Request PDU (FC 03 / FC 04)
  static Uint8List buildReadRegistersPdu(int functionCode, int startAddress, int quantity) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = functionCode & 0xFF;
    bd.setUint16(1, startAddress, Endian.big);
    bd.setUint16(3, quantity, Endian.big);
    return bytes;
  }

  /// Builds Write Single Coil Request PDU (FC 05)
  static Uint8List buildWriteSingleCoilPdu(int address, bool value) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.writeSingleCoil.code;
    bd.setUint16(1, address, Endian.big);
    bd.setUint16(3, value ? 0xFF00 : 0x0000, Endian.big);
    return bytes;
  }

  /// Builds Write Single Register Request PDU (FC 06)
  static Uint8List buildWriteSingleRegisterPdu(int address, int value) {
    final bytes = Uint8List(5);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.writeSingleRegister.code;
    bd.setUint16(1, address, Endian.big);
    bd.setUint16(3, value & 0xFFFF, Endian.big);
    return bytes;
  }

  /// Builds Write Multiple Registers Request PDU (FC 16)
  static Uint8List buildWriteMultipleRegistersPdu(int startAddress, List<int> values) {
    final byteCount = values.length * 2;
    final bytes = Uint8List(6 + byteCount);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.writeMultipleRegisters.code;
    bd.setUint16(1, startAddress, Endian.big);
    bd.setUint16(3, values.length, Endian.big);
    bytes[5] = byteCount;
    for (int i = 0; i < values.length; i++) {
      bd.setUint16(6 + i * 2, values[i] & 0xFFFF, Endian.big);
    }
    return bytes;
  }

  /// Builds Mask Write Register Request PDU (FC 22)
  static Uint8List buildMaskWriteRegisterPdu(int address, int andMask, int orMask) {
    final bytes = Uint8List(7);
    final bd = ByteData.sublistView(bytes);
    bytes[0] = ModbusFunctionCode.maskWriteRegister.code;
    bd.setUint16(1, address, Endian.big);
    bd.setUint16(3, andMask & 0xFFFF, Endian.big);
    bd.setUint16(5, orMask & 0xFFFF, Endian.big);
    return bytes;
  }

  /// Parses Read Bits Response PDU (FC 01 / FC 02)
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

  /// Parses Read Registers Response PDU (FC 03 / FC 04 / FC 23)
  static List<int> parseReadRegistersResponse(Uint8List pdu) {
    if (pdu.length < 2) throw const FormatException('Register response PDU too short');
    final byteCount = pdu[1];
    final regCount = byteCount ~/ 2;
    final registers = <int>[];
    final data = ByteData.sublistView(pdu);
    for (int i = 0; i < regCount; i++) {
      registers.add(data.getUint16(2 + i * 2, Endian.big));
    }
    return registers;
  }
}
