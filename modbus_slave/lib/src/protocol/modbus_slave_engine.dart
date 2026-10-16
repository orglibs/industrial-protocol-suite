import 'dart:typed_data';
import '../models/connection_config.dart';
import '../services/traffic_logger.dart';
import 'modbus_frame.dart';
import 'modbus_pdu.dart';

class ModbusSlaveEngine {
  /// Processes an incoming Modbus ADU request and returns the response ADU (or null if silent)
  static Future<ModbusAdu?> processRequest({
    required ConnectionConfig connection,
    required ModbusAdu requestAdu,
  }) async {
    final unitId = requestAdu.unitId;
    final pdu = requestAdu.pdu;

    if (pdu.isEmpty) return null;
    final fc = pdu[0];

    // Find target slave in connection
    final slave = connection.findSlave(unitId);

    if (slave == null) {
      // In RTU, unrecognized slave addresses are silently ignored to avoid bus collisions
      if (requestAdu.frameType == ModbusFrameType.rtu) {
        TrafficLogger.instance.log(
          direction: TrafficDirection.rx,
          connectionName: connection.name,
          unitId: unitId,
          functionCode: fc,
          rawBytes: requestAdu.encode(),
          description: '[未配置从站ID $unitId] 忽略RTU请求',
        );
        return null;
      }

      // In TCP, return Gateway Path Unavailable (0x0A)
      final respPdu = ModbusPdu.buildExceptionResponse(fc, ModbusExceptionCode.gatewayPathUnavailable);
      final respAdu = ModbusAdu(
        frameType: requestAdu.frameType,
        unitId: unitId,
        transactionId: requestAdu.transactionId,
        pdu: respPdu,
      );
      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        connectionName: connection.name,
        unitId: unitId,
        functionCode: fc,
        rawBytes: requestAdu.encode(),
        description: '[未配置从站ID $unitId] 异常应答 0x0A',
      );
      TrafficLogger.instance.log(
        direction: TrafficDirection.tx,
        connectionName: connection.name,
        unitId: unitId,
        functionCode: fc | 0x80,
        rawBytes: respAdu.encode(),
        description: '响应异常: 网关路径不可用 (0x0A)',
      );
      return respAdu;
    }

    // Response delay simulation (MSE feature)
    if (slave.responseDelay > 0) {
      await Future.delayed(Duration(milliseconds: slave.responseDelay));
    }

    Uint8List respPdu;
    String reqSummary = '';
    String respSummary = '';

    try {
      switch (fc) {
        case 0x01: // Read Coils
          final req = ModbusPdu.parseReadBitsRequest(pdu);
          reqSummary = '读线圈状态 [FC 01]: 起始=${req.startAddress}, 数量=${req.quantity}';
          final bits = slave.handleReadCoils(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadBitsResponse(0x01, bits);
          respSummary = '应答线圈数据: ${bits.length} 位, ${(bits.length + 7) ~/ 8} 字节';
          break;

        case 0x02: // Read Discrete Inputs
          final req = ModbusPdu.parseReadBitsRequest(pdu);
          reqSummary = '读离散输入 [FC 02]: 起始=${req.startAddress}, 数量=${req.quantity}';
          final bits = slave.handleReadDiscreteInputs(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadBitsResponse(0x02, bits);
          respSummary = '应答离散输入: ${bits.length} 位, ${(bits.length + 7) ~/ 8} 字节';
          break;

        case 0x03: // Read Holding Registers
          final req = ModbusPdu.parseReadRegistersRequest(pdu);
          reqSummary = '读保持寄存器 [FC 03]: 起始=${req.startAddress}, 数量=${req.quantity}';
          final regs = slave.handleReadHoldingRegisters(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadRegistersResponse(0x03, regs);
          respSummary = '应答保持寄存器: ${regs.length} 字 (${regs.length * 2} 字节)';
          break;

        case 0x04: // Read Input Registers
          final req = ModbusPdu.parseReadRegistersRequest(pdu);
          reqSummary = '读输入寄存器 [FC 04]: 起始=${req.startAddress}, 数量=${req.quantity}';
          final regs = slave.handleReadInputRegisters(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadRegistersResponse(0x04, regs);
          respSummary = '应答输入寄存器: ${regs.length} 字 (${regs.length * 2} 字节)';
          break;

        case 0x05: // Write Single Coil
          final req = ModbusPdu.parseWriteSingleCoilRequest(pdu);
          reqSummary = '写单个线圈 [FC 05]: 地址=${req.address}, 值=${req.value}';
          slave.handleWriteSingleCoil(req.address, req.value);
          respPdu = ModbusPdu.buildWriteSingleCoilResponse(req.address, req.value);
          respSummary = '写线圈成功回显: 地址=${req.address}, 值=${req.value}';
          break;

        case 0x06: // Write Single Register
          final req = ModbusPdu.parseWriteSingleRegisterRequest(pdu);
          reqSummary = '写单个寄存器 [FC 06]: 地址=${req.address}, 值=0x${req.value.toRadixString(16).padLeft(4, "0").toUpperCase()}';
          slave.handleWriteSingleRegister(req.address, req.value);
          respPdu = ModbusPdu.buildWriteSingleRegisterResponse(req.address, req.value);
          respSummary = '写寄存器成功回显: 地址=${req.address}, 值=${req.value}';
          break;

        case 0x08: // Diagnostics
          final req = ModbusPdu.parseDiagnosticsRequest(pdu);
          reqSummary = '诊断测试 [FC 08]: 子功能=0x${req.subFunction.toRadixString(16)}, 数据=0x${req.dataValue.toRadixString(16)}';
          // Echo data
          respPdu = ModbusPdu.buildDiagnosticsResponse(req.subFunction, req.dataValue);
          respSummary = '诊断测试回显成功';
          break;

        case 0x0F: // Write Multiple Coils
          final req = ModbusPdu.parseWriteMultipleCoilsRequest(pdu);
          reqSummary = '写多个线圈 [FC 15]: 起始=${req.startAddress}, 数量=${req.quantity}';
          slave.handleWriteMultipleCoils(req.startAddress, req.quantity, req.values);
          respPdu = ModbusPdu.buildWriteMultipleCoilsResponse(req.startAddress, req.quantity);
          respSummary = '写多个线圈成功: 数量=${req.quantity}';
          break;

        case 0x10: // Write Multiple Registers
          final req = ModbusPdu.parseWriteMultipleRegistersRequest(pdu);
          reqSummary = '写多个保持寄存器 [FC 16]: 起始=${req.startAddress}, 数量=${req.quantity}';
          slave.handleWriteMultipleRegisters(req.startAddress, req.quantity, req.values);
          respPdu = ModbusPdu.buildWriteMultipleRegistersResponse(req.startAddress, req.quantity);
          respSummary = '写多个寄存器成功: 数量=${req.quantity}';
          break;

        case 0x11: // Report Slave ID
          reqSummary = '报告从机标识 [FC 17]';
          respPdu = ModbusPdu.buildReportSlaveIdResponse(slave.slaveId, true, 'Modbus Slave Emulator v1.0.0');
          respSummary = '返回从机标识: ID=${slave.slaveId}, Modbus Slave Emulator';
          break;

        case 0x16: // Mask Write Register
          final req = ModbusPdu.parseMaskWriteRegisterRequest(pdu);
          reqSummary = '屏蔽写寄存器 [FC 22]: 地址=${req.address}, AND=0x${req.andMask.toRadixString(16)}, OR=0x${req.orMask.toRadixString(16)}';
          slave.handleMaskWriteRegister(req.address, req.andMask, req.orMask);
          respPdu = ModbusPdu.buildMaskWriteRegisterResponse(req.address, req.andMask, req.orMask);
          respSummary = '屏蔽写成功回显: 地址=${req.address}';
          break;

        case 0x17: // Read/Write Multiple Registers
          final req = ModbusPdu.parseReadWriteMultipleRegistersRequest(pdu);
          reqSummary = '读写多个寄存器 [FC 23]: 写起始=${req.writeAddress}(${req.writeQuantity}字), 读起始=${req.readAddress}(${req.readQuantity}字)';
          // Modbus standard: perform write first, then read
          slave.handleWriteMultipleRegisters(req.writeAddress, req.writeQuantity, req.writeValues);
          final readRegs = slave.handleReadHoldingRegisters(req.readAddress, req.readQuantity);
          respPdu = ModbusPdu.buildReadRegistersResponse(0x17, readRegs);
          respSummary = '读写多个寄存器成功: 返回 ${readRegs.length} 字';
          break;

        default:
          throw ModbusExceptionCode.illegalFunction;
      }
    } on ModbusExceptionCode catch (ec) {
      respPdu = ModbusPdu.buildExceptionResponse(fc, ec);
      respSummary = '异常响应: [0x${ec.code.toRadixString(16).padLeft(2, "0")}] ${ec.description}';
    } catch (e) {
      respPdu = ModbusPdu.buildExceptionResponse(fc, ModbusExceptionCode.slaveDeviceFailure);
      respSummary = '内部故障异常: $e';
    }

    final respAdu = ModbusAdu(
      frameType: requestAdu.frameType,
      unitId: unitId,
      transactionId: requestAdu.transactionId,
      pdu: respPdu,
    );

    // Log traffic
    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      connectionName: connection.name,
      unitId: unitId,
      functionCode: fc,
      rawBytes: requestAdu.encode(),
      description: reqSummary,
    );

    TrafficLogger.instance.log(
      direction: ((respPdu[0] & 0x80) != 0) ? TrafficDirection.err : TrafficDirection.tx,
      connectionName: connection.name,
      unitId: unitId,
      functionCode: respPdu[0],
      rawBytes: respAdu.encode(),
      description: respSummary,
    );

    return respAdu;
  }
}
