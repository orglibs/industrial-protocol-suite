import 'dart:math';
import 'dart:typed_data';
import '../protocol/modbus_data_types.dart';
import '../protocol/modbus_frame.dart';
import '../protocol/modbus_pdu.dart';

class VirtualModbusSlave {
  final int slaveId;
  final String name;

  // Modbus tables: 0..65535
  final Map<int, bool> coils = {};
  final Map<int, bool> discreteInputs = {};
  final Map<int, int> holdingRegisters = {};
  final Map<int, int> inputRegisters = {};

  double _simTime = 0.0;

  VirtualModbusSlave({this.slaveId = 1, this.name = 'Virtual Slave #1'}) {
    _initDefaultData();
  }

  void _initDefaultData() {
    // 1. Initial Coils (0x0000..0x0010)
    coils[0] = true;  // 1#主变断路器分合
    coils[1] = true;  // 2#主变断路器分合
    coils[2] = false; // 10kV母联开关
    coils[3] = false; // 事故总告警
    for (int i = 4; i < 32; i++) {
      coils[i] = (i % 3 == 0);
    }

    // 2. Discrete Inputs (0x0000..0x0010)
    for (int i = 0; i < 32; i++) {
      discreteInputs[i] = (i % 2 == 1);
    }

    // 3. Holding Registers (40001 / Address 0..99)
    // 0..1: Float 母线AB线电压 10.0 kV
    final v1 = ModbusDataConverter.float32ToRegisters(10.05);
    holdingRegisters[0] = v1.$1;
    holdingRegisters[1] = v1.$2;

    // 2..3: Float A相出线电流 250.3 A
    final i1 = ModbusDataConverter.float32ToRegisters(250.3);
    holdingRegisters[2] = i1.$1;
    holdingRegisters[3] = i1.$2;

    // 4..5: Float 有功功率 2450.0 kW
    final p1 = ModbusDataConverter.float32ToRegisters(2450.0);
    holdingRegisters[4] = p1.$1;
    holdingRegisters[5] = p1.$2;

    // 6..7: Float 电网频率 50.02 Hz
    final f1 = ModbusDataConverter.float32ToRegisters(50.02);
    holdingRegisters[6] = f1.$1;
    holdingRegisters[7] = f1.$2;

    // 8: Int16 环境温度 (28°C)
    holdingRegisters[8] = 28;

    // 9: Int16 变压器档位 (3档)
    holdingRegisters[9] = 3;

    // 10..30: Sequential test registers
    for (int i = 10; i < 50; i++) {
      holdingRegisters[i] = 1000 + i * 10;
    }

    // 4. Input Registers (30001 / Address 0..30)
    for (int i = 0; i < 30; i++) {
      inputRegisters[i] = 2000 + i * 5;
    }
  }

  /// Ticks simulation clock and updates holding registers with realistic curve fluctuations
  void tickSimulation(double deltaSeconds) {
    _simTime += deltaSeconds;

    // Voltage sine wave fluctuation around 10.0kV (9.8kV ~ 10.2kV)
    final v = 10.0 + 0.2 * sin(_simTime * 0.5);
    final (vReg1, vReg2) = ModbusDataConverter.float32ToRegisters(v);
    holdingRegisters[0] = vReg1;
    holdingRegisters[1] = vReg2;

    // Current fluctuation
    final cur = 250.0 + 20.0 * sin(_simTime * 0.8 + 1.0);
    final (iReg1, iReg2) = ModbusDataConverter.float32ToRegisters(cur);
    holdingRegisters[2] = iReg1;
    holdingRegisters[3] = iReg2;

    // Frequency micro fluctuation
    final freq = 50.0 + 0.05 * sin(_simTime * 1.5);
    final (fReg1, fReg2) = ModbusDataConverter.float32ToRegisters(freq);
    holdingRegisters[6] = fReg1;
    holdingRegisters[7] = fReg2;
  }

  /// Processes an incoming ADU request and returns the corresponding response ADU
  ModbusAdu processRequest(ModbusAdu request) {
    final pdu = request.pdu;
    if (pdu.isEmpty) {
      return _buildException(request, 0x01, ModbusExceptionCode.illegalFunction);
    }

    final fcCode = pdu[0];
    final bd = ByteData.sublistView(pdu);

    switch (fcCode) {
      // FC 01: Read Coils
      case 0x01:
        if (pdu.length < 5) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final startAddr = bd.getUint16(1, Endian.big);
        final count = bd.getUint16(3, Endian.big);
        if (count < 1 || count > 2000) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);

        final byteCount = (count + 7) ~/ 8;
        final respBytes = Uint8List(2 + byteCount);
        respBytes[0] = fcCode;
        respBytes[1] = byteCount;
        for (int i = 0; i < count; i++) {
          final bitVal = coils[startAddr + i] ?? false;
          if (bitVal) {
            respBytes[2 + (i ~/ 8)] |= (1 << (i % 8));
          }
        }
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: respBytes);

      // FC 02: Read Discrete Inputs
      case 0x02:
        if (pdu.length < 5) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final startAddr = bd.getUint16(1, Endian.big);
        final count = bd.getUint16(3, Endian.big);
        if (count < 1 || count > 2000) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);

        final byteCount = (count + 7) ~/ 8;
        final respBytes = Uint8List(2 + byteCount);
        respBytes[0] = fcCode;
        respBytes[1] = byteCount;
        for (int i = 0; i < count; i++) {
          final bitVal = discreteInputs[startAddr + i] ?? false;
          if (bitVal) {
            respBytes[2 + (i ~/ 8)] |= (1 << (i % 8));
          }
        }
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: respBytes);

      // FC 03: Read Holding Registers
      case 0x03:
        if (pdu.length < 5) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final startAddr = bd.getUint16(1, Endian.big);
        final count = bd.getUint16(3, Endian.big);
        if (count < 1 || count > 125) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        if (startAddr > 10000 || startAddr + count > 10000) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataAddress);

        final byteCount = count * 2;
        final respBytes = Uint8List(2 + byteCount);
        final respBd = ByteData.sublistView(respBytes);
        respBytes[0] = fcCode;
        respBytes[1] = byteCount;
        for (int i = 0; i < count; i++) {
          final val = holdingRegisters[startAddr + i] ?? 0;
          respBd.setUint16(2 + i * 2, val & 0xFFFF, Endian.big);
        }
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: respBytes);

      // FC 04: Read Input Registers
      case 0x04:
        if (pdu.length < 5) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final startAddr = bd.getUint16(1, Endian.big);
        final count = bd.getUint16(3, Endian.big);
        if (count < 1 || count > 125) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        if (startAddr > 10000 || startAddr + count > 10000) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataAddress);


        final byteCount = count * 2;
        final respBytes = Uint8List(2 + byteCount);
        final respBd = ByteData.sublistView(respBytes);
        respBytes[0] = fcCode;
        respBytes[1] = byteCount;
        for (int i = 0; i < count; i++) {
          final val = inputRegisters[startAddr + i] ?? 0;
          respBd.setUint16(2 + i * 2, val & 0xFFFF, Endian.big);
        }
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: respBytes);

      // FC 05: Write Single Coil
      case 0x05:
        if (pdu.length < 5) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final addr = bd.getUint16(1, Endian.big);
        final val = bd.getUint16(3, Endian.big);
        coils[addr] = (val == 0xFF00);
        // Echo back request PDU on success
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: pdu);

      // FC 06: Write Single Register
      case 0x06:
        if (pdu.length < 5) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final addr = bd.getUint16(1, Endian.big);
        final val = bd.getUint16(3, Endian.big);
        holdingRegisters[addr] = val;
        // Echo back request PDU on success
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: pdu);

      // FC 15: Write Multiple Coils
      case 0x0F:
        if (pdu.length < 6) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final startAddr = bd.getUint16(1, Endian.big);
        final count = bd.getUint16(3, Endian.big);
        for (int i = 0; i < count; i++) {
          final byteIndex = 6 + (i ~/ 8);
          if (byteIndex < pdu.length) {
            final bitVal = ((pdu[byteIndex] >> (i % 8)) & 1) == 1;
            coils[startAddr + i] = bitVal;
          }
        }
        // Response: Function Code (1B) + Start Address (2B) + Quantity of Coils (2B)
        final resp = Uint8List(5);
        final rBd = ByteData.sublistView(resp);
        resp[0] = fcCode;
        rBd.setUint16(1, startAddr, Endian.big);
        rBd.setUint16(3, count, Endian.big);
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: resp);

      // FC 16: Write Multiple Registers
      case 0x10:
        if (pdu.length < 6) return _buildException(request, fcCode, ModbusExceptionCode.illegalDataValue);
        final startAddr = bd.getUint16(1, Endian.big);
        final count = bd.getUint16(3, Endian.big);
        for (int i = 0; i < count; i++) {
          final offset = 6 + i * 2;
          if (offset + 1 < pdu.length) {
            holdingRegisters[startAddr + i] = bd.getUint16(offset, Endian.big);
          }
        }
        // Response: Function Code (1B) + Start Address (2B) + Quantity of Registers (2B)
        final resp = Uint8List(5);
        final rBd = ByteData.sublistView(resp);
        resp[0] = fcCode;
        rBd.setUint16(1, startAddr, Endian.big);
        rBd.setUint16(3, count, Endian.big);
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: resp);

      // FC 08: Diagnostics
      case 0x08:
        // Echo query
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: pdu);

      // FC 17: Report Slave ID
      case 0x11:
        final idStr = 'ModbusMasterEmulator-VirtualSlave-v1.0';
        final resp = Uint8List(3 + idStr.length);
        resp[0] = fcCode;
        resp[1] = 1 + idStr.length; // byte count
        resp[2] = 0xFF;             // run indicator: ON
        resp.setRange(3, 3 + idStr.length, idStr.codeUnits);
        return ModbusAdu(frameType: request.frameType, unitId: request.unitId, transactionId: request.transactionId, pdu: resp);

      default:
        return _buildException(request, fcCode, ModbusExceptionCode.illegalFunction);
    }
  }

  ModbusAdu _buildException(ModbusAdu request, int fc, ModbusExceptionCode code) {
    final pdu = Uint8List.fromList([fc | 0x80, code.code]);
    return ModbusAdu(
      frameType: request.frameType,
      unitId: request.unitId,
      transactionId: request.transactionId,
      pdu: pdu,
    );
  }
}
