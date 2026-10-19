import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../i18n/app_i18n.dart';
import '../models/connection_config.dart';
import '../services/traffic_logger.dart';
import '../services/virtual_slave.dart';
import 'modbus_frame.dart';
import 'modbus_pdu.dart';
import 'serial_port_adapter.dart';

enum ModbusConnectionState {
  disconnected,
  connecting,
  connected,
  error;

  String get label {
    switch (this) {
      case ModbusConnectionState.disconnected:
        return AppI18n.instance.t('disconnected');
      case ModbusConnectionState.connecting:
        return AppI18n.instance.t('connecting');
      case ModbusConnectionState.connected:
        return AppI18n.instance.t('connected');
      case ModbusConnectionState.error:
        return AppI18n.instance.t('connError');
    }
  }
}

class ModbusClient {
  ModbusTransportMode transportMode = ModbusTransportMode.tcp;
  String host = '127.0.0.1';
  int port = 502;
  String? serialPortName;
  int baudRate = 9600;
  int dataBits = 8;
  int parity = 0; // 0: None, 1: Odd, 2: Even
  int stopBits = 1;
  ModbusFrameType frameType = ModbusFrameType.tcp;
  Duration timeout = const Duration(seconds: 3);
  bool isVirtualMode = false;

  Socket? _socket;
  SerialPortAdapter? _serialAdapter;
  StreamSubscription? _serialSub;
  final List<int> _rxBuffer = [];
  int _transactionId = 1;

  ModbusConnectionState _state = ModbusConnectionState.disconnected;
  ModbusConnectionState get state => _state;

  final StreamController<ModbusConnectionState> _stateController = StreamController.broadcast();
  Stream<ModbusConnectionState> get stateStream => _stateController.stream;

  // Pending request completer
  Completer<Uint8List>? _pendingCompleter;
  int? _pendingTransactionId;

  // Virtual slave instance for testing or web mode
  VirtualModbusSlave virtualSlave = VirtualModbusSlave();

  ModbusClient() {
    _stateController.add(_state);
  }

  void _setState(ModbusConnectionState s) {
    if (_state != s) {
      _state = s;
      _stateController.add(_state);
    }
  }

  /// Connects to remote Modbus server, serial COM port, or activates virtual mode
  Future<void> connect() async {
    if (_state == ModbusConnectionState.connected) return;

    _setState(ModbusConnectionState.connecting);

    if (isVirtualMode || transportMode == ModbusTransportMode.virtual) {
      await Future.delayed(const Duration(milliseconds: 100));
      _setState(ModbusConnectionState.connected);
      return;
    }

    if (transportMode == ModbusTransportMode.serialRtu) {
      final port = serialPortName?.trim();
      if (port == null || port.isEmpty) {
        _setState(ModbusConnectionState.error);
        throw Exception(AppI18n.instance.t('errSpecifySerialPort'));
      }

      frameType = ModbusFrameType.rtu;
      try {
        _serialAdapter = SerialPortAdapter(
          portName: port,
          baudRate: baudRate,
          dataBits: dataBits,
          parity: parity,
          stopBits: stopBits,
        );
        _serialSub = _serialAdapter!.onData.listen(_onDataReceived);
        await _serialAdapter!.open();
        _setState(ModbusConnectionState.connected);
      } catch (e) {
        _setState(ModbusConnectionState.error);
        _serialSub?.cancel();
        _serialSub = null;
        _serialAdapter?.close();
        _serialAdapter = null;
        rethrow;
      }
      return;
    }

    try {
      _socket = await Socket.connect(host, port, timeout: timeout);
      _socket!.listen(
        _onDataReceived,
        onError: (err) {
          _setState(ModbusConnectionState.error);
          disconnect();
        },
        onDone: () {
          disconnect();
        },
      );
      _setState(ModbusConnectionState.connected);
    } catch (e) {
      _setState(ModbusConnectionState.error);
      rethrow;
    }
  }

  /// Disconnects client
  Future<void> disconnect() async {
    _socket?.destroy();
    _socket = null;

    _serialSub?.cancel();
    _serialSub = null;
    _serialAdapter?.close();
    _serialAdapter = null;

    _rxBuffer.clear();
    _pendingCompleter?.safeCompleteError(Exception('Disconnected'));
    _pendingCompleter = null;
    _setState(ModbusConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }


  void _onDataReceived(Uint8List data) {
    _rxBuffer.addAll(data);
    _tryParseRxBuffer();
  }

  void _tryParseRxBuffer() {
    if (_pendingCompleter == null || _rxBuffer.isEmpty) return;

    final raw = Uint8List.fromList(_rxBuffer);
    try {
      final adu = ModbusAdu.decode(raw, frameType);
      if (adu != null) {
        // Validate transaction ID if TCP
        if (frameType == ModbusFrameType.tcp && _pendingTransactionId != null) {
          if (adu.transactionId != _pendingTransactionId) {
            // Ignore mismatched transaction
            return;
          }
        }

        // Frame successfully decoded
        final consumedLen = frameType == ModbusFrameType.tcp
            ? adu.pdu.length + 7
            : (frameType == ModbusFrameType.rtu ? adu.pdu.length + 3 : raw.length);
        if (_rxBuffer.length >= consumedLen) {
          _rxBuffer.removeRange(0, consumedLen);
        } else {
          _rxBuffer.clear();
        }

        _pendingCompleter?.safeComplete(adu.pdu);
        _pendingCompleter = null;
      }
    } catch (e) {
      if (frameType == ModbusFrameType.rtu && _rxBuffer.length > 1) {
        // Discard first corrupted byte to resynchronize stream
        _rxBuffer.removeAt(0);
        _tryParseRxBuffer();
      } else {
        _rxBuffer.clear();
        _pendingCompleter?.safeCompleteError(e);
        _pendingCompleter = null;
      }
    }
  }

  /// Sends a Modbus PDU and awaits the response PDU
  Future<Uint8List> sendPdu({
    required int unitId,
    required Uint8List pdu,
    int? customTimeoutMs,
  }) async {
    if (_state != ModbusConnectionState.connected) {
      throw StateError('Modbus Master is not connected. Call connect() first.');
    }

    final txId = (_transactionId++) & 0xFFFF;
    final adu = ModbusAdu(
      frameType: frameType,
      unitId: unitId,
      transactionId: txId,
      pdu: pdu,
    );

    final rawBytes = adu.encode();
    final stopwatch = Stopwatch()..start();

    final fcCode = pdu[0];
    final fc = ModbusFunctionCode.fromCode(fcCode);
    final summary = '${fc?.label ?? "FC 0x${fcCode.toRadixString(16)}"} (${AppI18n.instance.t("unitIdLabel")}: $unitId)';

    final peerDesc = transportMode == ModbusTransportMode.serialRtu
        ? '$serialPortName @ $baudRate bps [ID:$unitId]'
        : '$host:$port [ID:$unitId]';

    TrafficLogger.instance.log(
      direction: TrafficDirection.tx,
      sourceOrTarget: peerDesc,
      rawBytes: rawBytes,
      summary: summary,
      protocolDetail: '${AppI18n.instance.t("sendRequest")}: PDU=${pdu.length} ${AppI18n.instance.t("bytesUnit")}, ${frameType.name}',
    );

    // If virtual mode, process internally with realistic delay
    if (isVirtualMode || transportMode == ModbusTransportMode.virtual) {
      await Future.delayed(const Duration(milliseconds: 15));
      final respAdu = virtualSlave.processRequest(adu);
      final respRaw = respAdu.encode();
      stopwatch.stop();

      final isErr = ModbusPdu.isExceptionResponse(respAdu.pdu);
      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        sourceOrTarget: peerDesc,
        rawBytes: respRaw,
        summary: isErr ? 'Exception Code: ${respAdu.pdu.length > 1 ? respAdu.pdu[1] : "?"}' : '${AppI18n.instance.t("statusOk")}: PDU=${respAdu.pdu.length}',
        protocolDetail: AppI18n.instance.t('virtualSlaveLocalResp'),
        isError: isErr,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );

      if (isErr) {
        throw ModbusPdu.parseException(respAdu.pdu);
      }
      return respAdu.pdu;
    }

    // Real Socket or Serial transmission
    _pendingCompleter = Completer<Uint8List>();
    _pendingTransactionId = txId;

    try {
      if (transportMode == ModbusTransportMode.serialRtu) {
        if (_serialAdapter == null || !_serialAdapter!.isOpen) {
          throw StateError(AppI18n.instance.t('errSerialNotOpen'));
        }
        _serialAdapter!.write(rawBytes);
      } else {
        if (_socket == null) {
          throw StateError(AppI18n.instance.t('errTcpNotConnected'));
        }
        _socket!.add(rawBytes);
        await _socket!.flush();
      }

      final respTimeout = customTimeoutMs != null
          ? Duration(milliseconds: customTimeoutMs)
          : timeout;

      final respPdu = await _pendingCompleter!.future.timeout(respTimeout);
      stopwatch.stop();

      final isErr = ModbusPdu.isExceptionResponse(respPdu);
      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        sourceOrTarget: peerDesc,
        rawBytes: respPdu,
        summary: isErr ? 'Exception Response' : AppI18n.instance.t('statusOk'),
        protocolDetail: '${AppI18n.instance.t("timeElapsed")}: ${stopwatch.elapsedMilliseconds} ms',
        isError: isErr,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );

      if (isErr) {
        throw ModbusPdu.parseException(respPdu);
      }
      return respPdu;
    } catch (e) {
      stopwatch.stop();
      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        sourceOrTarget: peerDesc,
        rawBytes: Uint8List(0),
        summary: '${AppI18n.instance.t("commTimeoutOrError")}: $e',
        protocolDetail: AppI18n.instance.t('reqFailed'),
        isError: true,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    } finally {
      _pendingCompleter = null;
    }
  }

  // --- High-Level Modbus Master Operations ---

  /// FC 01: Read Coils
  Future<List<bool>> readCoils({
    required int unitId,
    required int startAddress,
    required int quantity,
    int? customTimeoutMs,
  }) async {
    final reqPdu = ModbusPdu.buildReadBitsPdu(ModbusFunctionCode.readCoils.code, startAddress, quantity);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu, customTimeoutMs: customTimeoutMs);
    return ModbusPdu.parseReadBitsResponse(respPdu, quantity);
  }

  /// FC 02: Read Discrete Inputs
  Future<List<bool>> readDiscreteInputs({
    required int unitId,
    required int startAddress,
    required int quantity,
    int? customTimeoutMs,
  }) async {
    final reqPdu = ModbusPdu.buildReadBitsPdu(ModbusFunctionCode.readDiscreteInputs.code, startAddress, quantity);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu, customTimeoutMs: customTimeoutMs);
    return ModbusPdu.parseReadBitsResponse(respPdu, quantity);
  }

  /// FC 03: Read Holding Registers
  Future<Uint16List> readHoldingRegisters({
    required int unitId,
    required int startAddress,
    required int quantity,
    int? customTimeoutMs,
  }) async {
    final reqPdu = ModbusPdu.buildReadRegistersPdu(ModbusFunctionCode.readHoldingRegisters.code, startAddress, quantity);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu, customTimeoutMs: customTimeoutMs);
    return ModbusPdu.parseReadRegistersResponse(respPdu);
  }

  /// FC 04: Read Input Registers
  Future<Uint16List> readInputRegisters({
    required int unitId,
    required int startAddress,
    required int quantity,
    int? customTimeoutMs,
  }) async {
    final reqPdu = ModbusPdu.buildReadRegistersPdu(ModbusFunctionCode.readInputRegisters.code, startAddress, quantity);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu, customTimeoutMs: customTimeoutMs);
    return ModbusPdu.parseReadRegistersResponse(respPdu);
  }


  /// FC 05: Write Single Coil
  Future<bool> writeSingleCoil({
    required int unitId,
    required int address,
    required bool value,
  }) async {
    final reqPdu = ModbusPdu.buildWriteSingleCoilPdu(address, value);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu);
    return respPdu.length >= 5;
  }

  /// FC 06: Write Single Register
  Future<bool> writeSingleRegister({
    required int unitId,
    required int address,
    required int value,
  }) async {
    final reqPdu = ModbusPdu.buildWriteSingleRegisterPdu(address, value);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu);
    return respPdu.length >= 5;
  }

  /// FC 15: Write Multiple Coils
  Future<bool> writeMultipleCoils({
    required int unitId,
    required int startAddress,
    required List<bool> values,
  }) async {
    final reqPdu = ModbusPdu.buildWriteMultipleCoilsPdu(startAddress, values);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu);
    return respPdu.length >= 5;
  }

  /// FC 16: Write Multiple Registers
  Future<bool> writeMultipleRegisters({
    required int unitId,
    required int startAddress,
    required List<int> values,
  }) async {
    final reqPdu = ModbusPdu.buildWriteMultipleRegistersPdu(startAddress, values);
    final respPdu = await sendPdu(unitId: unitId, pdu: reqPdu);
    return respPdu.length >= 5;
  }

  /// FC 08: Diagnostics (Echo Query)
  Future<Uint8List> diagnostics({
    required int unitId,
    int subFunction = 0x0000,
    int dataValue = 0x1234,
  }) async {
    final reqPdu = ModbusPdu.buildDiagnosticsPdu(subFunction, dataValue);
    return await sendPdu(unitId: unitId, pdu: reqPdu);
  }

  /// FC 17: Report Slave ID
  Future<Uint8List> reportSlaveId({required int unitId}) async {
    final reqPdu = ModbusPdu.buildSimplePdu(ModbusFunctionCode.reportSlaveId.code);
    return await sendPdu(unitId: unitId, pdu: reqPdu);
  }

  /// FC 22: Mask Write Register
  Future<Uint8List> maskWriteRegister({
    required int unitId,
    required int address,
    required int andMask,
    required int orMask,
  }) async {
    final reqPdu = ModbusPdu.buildMaskWriteRegisterPdu(address, andMask, orMask);
    return await sendPdu(unitId: unitId, pdu: reqPdu);
  }
}

extension CompleterExt<T> on Completer<T> {
  void safeComplete(T value) {
    if (!isCompleted) complete(value);
  }

  void safeCompleteError(Object error) {
    if (!isCompleted) completeError(error);
  }
}
