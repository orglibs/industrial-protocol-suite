import 'dart:typed_data';
import '../i18n/app_i18n.dart';
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
          connectionName: connection.displayName,
          unitId: unitId,
          functionCode: fc,
          rawBytes: requestAdu.encode(),
          description: AppI18n.instance.tf('traffic_unconfigured_ignore', {'id': unitId}),
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
        connectionName: connection.displayName,
        unitId: unitId,
        functionCode: fc,
        rawBytes: requestAdu.encode(),
        description: AppI18n.instance.tf('traffic_unconfigured_error', {'id': unitId}),
      );
      TrafficLogger.instance.log(
        direction: TrafficDirection.tx,
        connectionName: connection.displayName,
        unitId: unitId,
        functionCode: fc | 0x80,
        rawBytes: respAdu.encode(),
        description: AppI18n.instance.t('traffic_gateway_unavailable'),
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
          reqSummary = AppI18n.instance.tf('traffic_fc01_req', {'start': req.startAddress, 'qty': req.quantity});
          final bits = slave.handleReadCoils(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadBitsResponse(0x01, bits);
          respSummary = AppI18n.instance.tf('traffic_fc01_resp', {'bits': bits.length, 'bytes': (bits.length + 7) ~/ 8});
          break;

        case 0x02: // Read Discrete Inputs
          final req = ModbusPdu.parseReadBitsRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc02_req', {'start': req.startAddress, 'qty': req.quantity});
          final bits = slave.handleReadDiscreteInputs(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadBitsResponse(0x02, bits);
          respSummary = AppI18n.instance.tf('traffic_fc02_resp', {'bits': bits.length, 'bytes': (bits.length + 7) ~/ 8});
          break;

        case 0x03: // Read Holding Registers
          final req = ModbusPdu.parseReadRegistersRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc03_req', {'start': req.startAddress, 'qty': req.quantity});
          final regs = slave.handleReadHoldingRegisters(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadRegistersResponse(0x03, regs);
          respSummary = AppI18n.instance.tf('traffic_fc03_resp', {'words': regs.length, 'bytes': regs.length * 2});
          break;

        case 0x04: // Read Input Registers
          final req = ModbusPdu.parseReadRegistersRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc04_req', {'start': req.startAddress, 'qty': req.quantity});
          final regs = slave.handleReadInputRegisters(req.startAddress, req.quantity);
          respPdu = ModbusPdu.buildReadRegistersResponse(0x04, regs);
          respSummary = AppI18n.instance.tf('traffic_fc04_resp', {'words': regs.length, 'bytes': regs.length * 2});
          break;

        case 0x05: // Write Single Coil
          final req = ModbusPdu.parseWriteSingleCoilRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc05_req', {'addr': req.address, 'val': req.value});
          slave.handleWriteSingleCoil(req.address, req.value);
          respPdu = ModbusPdu.buildWriteSingleCoilResponse(req.address, req.value);
          respSummary = AppI18n.instance.tf('traffic_fc05_resp', {'addr': req.address, 'val': req.value});
          break;

        case 0x06: // Write Single Register
          final req = ModbusPdu.parseWriteSingleRegisterRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc06_req', {'addr': req.address, 'val': '0x${req.value.toRadixString(16).padLeft(4, "0").toUpperCase()}'});
          slave.handleWriteSingleRegister(req.address, req.value);
          respPdu = ModbusPdu.buildWriteSingleRegisterResponse(req.address, req.value);
          respSummary = AppI18n.instance.tf('traffic_fc06_resp', {'addr': req.address, 'val': req.value});
          break;

        case 0x08: // Diagnostics
          final req = ModbusPdu.parseDiagnosticsRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc08_req', {'sub': '0x${req.subFunction.toRadixString(16)}', 'data': '0x${req.dataValue.toRadixString(16)}'});
          // Echo data
          respPdu = ModbusPdu.buildDiagnosticsResponse(req.subFunction, req.dataValue);
          respSummary = AppI18n.instance.t('traffic_fc08_resp');
          break;

        case 0x0F: // Write Multiple Coils
          final req = ModbusPdu.parseWriteMultipleCoilsRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc15_req', {'start': req.startAddress, 'qty': req.quantity});
          slave.handleWriteMultipleCoils(req.startAddress, req.quantity, req.values);
          respPdu = ModbusPdu.buildWriteMultipleCoilsResponse(req.startAddress, req.quantity);
          respSummary = AppI18n.instance.tf('traffic_fc15_resp', {'qty': req.quantity});
          break;

        case 0x10: // Write Multiple Registers
          final req = ModbusPdu.parseWriteMultipleRegistersRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc16_req', {'start': req.startAddress, 'qty': req.quantity});
          slave.handleWriteMultipleRegisters(req.startAddress, req.quantity, req.values);
          respPdu = ModbusPdu.buildWriteMultipleRegistersResponse(req.startAddress, req.quantity);
          respSummary = AppI18n.instance.tf('traffic_fc16_resp', {'qty': req.quantity});
          break;

        case 0x11: // Report Slave ID
          reqSummary = AppI18n.instance.t('traffic_fc17_req');
          respPdu = ModbusPdu.buildReportSlaveIdResponse(slave.slaveId, true, 'Modbus Slave Emulator v1.0.0');
          respSummary = AppI18n.instance.tf('traffic_fc17_resp', {'id': slave.slaveId});
          break;

        case 0x16: // Mask Write Register
          final req = ModbusPdu.parseMaskWriteRegisterRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc22_req', {'addr': req.address, 'and': '0x${req.andMask.toRadixString(16)}', 'or': '0x${req.orMask.toRadixString(16)}'});
          slave.handleMaskWriteRegister(req.address, req.andMask, req.orMask);
          respPdu = ModbusPdu.buildMaskWriteRegisterResponse(req.address, req.andMask, req.orMask);
          respSummary = AppI18n.instance.tf('traffic_fc22_resp', {'addr': req.address});
          break;

        case 0x17: // Read/Write Multiple Registers
          final req = ModbusPdu.parseReadWriteMultipleRegistersRequest(pdu);
          reqSummary = AppI18n.instance.tf('traffic_fc23_req', {'wAddr': req.writeAddress, 'wQty': req.writeQuantity, 'rAddr': req.readAddress, 'rQty': req.readQuantity});
          // Modbus standard: perform write first, then read
          slave.handleWriteMultipleRegisters(req.writeAddress, req.writeQuantity, req.writeValues);
          final readRegs = slave.handleReadHoldingRegisters(req.readAddress, req.readQuantity);
          respPdu = ModbusPdu.buildReadRegistersResponse(0x17, readRegs);
          respSummary = AppI18n.instance.tf('traffic_fc23_resp', {'count': readRegs.length});
          break;

        default:
          throw ModbusExceptionCode.illegalFunction;
      }
    } on ModbusExceptionCode catch (ec) {
      respPdu = ModbusPdu.buildExceptionResponse(fc, ec);
      respSummary = AppI18n.instance.tf('traffic_exception_resp', {'code': ec.code.toRadixString(16).padLeft(2, "0"), 'desc': ec.description});
    } catch (e) {
      respPdu = ModbusPdu.buildExceptionResponse(fc, ModbusExceptionCode.slaveDeviceFailure);
      respSummary = AppI18n.instance.tf('traffic_internal_fault', {'err': e});
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
      connectionName: connection.displayName,
      unitId: unitId,
      functionCode: fc,
      rawBytes: requestAdu.encode(),
      description: reqSummary,
    );

    TrafficLogger.instance.log(
      direction: ((respPdu[0] & 0x80) != 0) ? TrafficDirection.err : TrafficDirection.tx,
      connectionName: connection.displayName,
      unitId: unitId,
      functionCode: respPdu[0],
      rawBytes: respAdu.encode(),
      description: respSummary,
    );

    return respAdu;
  }
}
