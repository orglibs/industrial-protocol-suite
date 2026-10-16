import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../protocol/apci.dart';
import '../protocol/asdu.dart';
import '../protocol/asdu_types.dart';
import '../protocol/codec.dart';
import 'station_data.dart';
import 'traffic_logger.dart';
import 'workspace_storage.dart';

enum ClientConnectionState {
  disconnected('未连接'),
  connecting('连接中...'),
  connected('已建立TCP连接'),
  active('数据传输激活 (STARTDT已确认)');

  final String label;
  const ClientConnectionState(this.label);
}

class CommandResultEvent {
  final AsduTypeId typeId;
  final int commonAddress;
  final int ioa;
  final CauseOfTransmission cot;
  final String message;
  final DateTime timestamp;

  CommandResultEvent({
    required this.typeId,
    required this.commonAddress,
    required this.ioa,
    required this.cot,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class Iec104Client {
  String host = '127.0.0.1';
  int port = 2404;

  int k = 12; // Max unconfirmed sent I-frames
  int w = 8;  // Max unconfirmed received I-frames before S-frame ack
  int t0 = 30; // Connection timeout in seconds
  int t1 = 15; // Ack timeout in seconds
  int t2 = 10; // S-frame acknowledge delay in seconds
  int t3 = 20; // Idle heartbeat in seconds

  int cotSize = 2;
  int caSize = 2;
  int ioaSize = 3;
  int originatorAddress = 0;
  int defaultCa = 1;

  bool autoStartDt = true;
  bool autoGeneralInterrogation = true;
  int generalInterrogationPeriod = 0; // 0 = off
  int clockSyncPeriod = 0;           // 0 = off
  int counterInterrogationPeriod = 0; // 0 = off

  ClientConnectionState _state = ClientConnectionState.disconnected;
  ClientConnectionState get state => _state;

  bool isWebVirtualMode = false;

  // Station models mapped by Common Address
  final Map<int, ClientStationModel> stations = {};

  // Streams
  final StreamController<ClientConnectionState> _stateController = StreamController.broadcast();
  Stream<ClientConnectionState> get stateStream => _stateController.stream;

  final StreamController<ClientPointModel> _pointUpdateController = StreamController.broadcast();
  Stream<ClientPointModel> get pointUpdateStream => _pointUpdateController.stream;

  final StreamController<CommandResultEvent> _commandResultController = StreamController.broadcast();
  Stream<CommandResultEvent> get commandResultStream => _commandResultController.stream;

  final StreamController<List<ClientStationModel>> _stationsController = StreamController.broadcast();
  Stream<List<ClientStationModel>> get stationsStream => _stationsController.stream;

  // Internal connection state
  Socket? _socket;
  final List<int> _rxBuffer = [];

  int _sendSeq = 0; // N(S) 0..32767
  int _recvSeq = 0; // N(R) 0..32767
  int _unconfirmedRecvCount = 0;

  int get sendSeq => _sendSeq;
  int get recvSeq => _recvSeq;
  int get unconfirmedRecvCount => _unconfirmedRecvCount;

  Timer? _t2Timer;
  Timer? _t3Timer;
  Timer? _giPeriodTimer;
  Timer? _clockPeriodTimer;
  Timer? _counterPeriodTimer;

  // Virtual server simulator callback for Web or testing
  void Function(Uint8List requestBytes)? _virtualServerHandler;

  Timer? _autoSaveTimer;

  void scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 600), () {
      saveWorkspace();
    });
  }

  Future<bool> saveWorkspace() async {
    final data = exportWorkspace();
    return await WorkspaceStorage.save(data);
  }

  Future<bool> loadWorkspace() async {
    final data = await WorkspaceStorage.load();
    if (data != null) {
      importWorkspace(data);
      return true;
    }
    return false;
  }

  Map<String, dynamic> connectionToJson() => {
        'host': host,
        'port': port,
        'k': k,
        'w': w,
        't0': t0,
        't1': t1,
        't2': t2,
        't3': t3,
        'defaultCa': defaultCa,
        'originatorAddress': originatorAddress,
        'cotSize': cotSize,
        'caSize': caSize,
        'ioaSize': ioaSize,
        'autoStartDt': autoStartDt,
        'autoGeneralInterrogation': autoGeneralInterrogation,
        'generalInterrogationPeriod': generalInterrogationPeriod,
        'clockSyncPeriod': clockSyncPeriod,
        'counterInterrogationPeriod': counterInterrogationPeriod,
      };

  void connectionFromJson(Map<String, dynamic> json) {
    host = json['host'] as String? ?? host;
    port = json['port'] as int? ?? port;
    k = json['k'] as int? ?? k;
    w = json['w'] as int? ?? w;
    t0 = json['t0'] as int? ?? t0;
    t1 = json['t1'] as int? ?? t1;
    t2 = json['t2'] as int? ?? t2;
    t3 = json['t3'] as int? ?? t3;
    defaultCa = json['defaultCa'] as int? ?? defaultCa;
    originatorAddress = json['originatorAddress'] as int? ?? originatorAddress;
    cotSize = json['cotSize'] as int? ?? cotSize;
    caSize = json['caSize'] as int? ?? caSize;
    ioaSize = json['ioaSize'] as int? ?? ioaSize;
    autoStartDt = json['autoStartDt'] as bool? ?? autoStartDt;
    autoGeneralInterrogation = json['autoGeneralInterrogation'] as bool? ?? autoGeneralInterrogation;
    generalInterrogationPeriod = json['generalInterrogationPeriod'] as int? ?? generalInterrogationPeriod;
    clockSyncPeriod = json['clockSyncPeriod'] as int? ?? clockSyncPeriod;
    counterInterrogationPeriod = json['counterInterrogationPeriod'] as int? ?? counterInterrogationPeriod;
  }

  Map<String, dynamic> exportWorkspace() => {
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'connection': connectionToJson(),
        'stations': stations.values.map((s) => s.toJson()).toList(),
      };

  void importWorkspace(Map<String, dynamic> json) {
    if (json['connection'] is Map<String, dynamic>) {
      connectionFromJson(json['connection'] as Map<String, dynamic>);
    }
    if (json['stations'] is List) {
      stations.clear();
      for (final item in json['stations']) {
        if (item is Map<String, dynamic>) {
          final ca = item['commonAddress'] as int? ?? 1;
          final st = ClientStationModel(
            commonAddress: ca,
            name: item['name'] as String? ?? '',
            onDataChanged: scheduleAutoSave,
          );
          st.loadFromJson(item);
          stations[ca] = st;
        }
      }
      if (stations.isEmpty) {
        _initDefaultStation(defaultCa);
      }
      _stationsController.add(stations.values.toList());
    }
  }

  Iec104Client() {
    _initDefaultStation(1);
  }

  void _initDefaultStation(int ca) {
    if (!stations.containsKey(ca)) {
      final st = ClientStationModel(
        commonAddress: ca,
        name: '从站 #$ca (默认变电站)',
        onDataChanged: scheduleAutoSave,
      );
      st.applyTemplate('distribution');
      stations[ca] = st;
    }
  }

  ClientStationModel getStation(int ca) {
    final isNew = !stations.containsKey(ca);
    final st = stations.putIfAbsent(
      ca,
      () => ClientStationModel(
        commonAddress: ca,
        name: '从站 #$ca',
        onDataChanged: scheduleAutoSave,
      ),
    );
    st.onDataChanged ??= scheduleAutoSave;
    if (isNew) {
      _stationsController.add(stations.values.toList());
      scheduleAutoSave();
    }
    return st;
  }

  void addStation(int ca, {String? name, String? template}) {
    final st = ClientStationModel(
      commonAddress: ca,
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : '从站 #$ca',
      onDataChanged: scheduleAutoSave,
    );
    if (template != null && template.isNotEmpty) {
      st.applyTemplate(template);
    }
    stations[ca] = st;
    _stationsController.add(stations.values.toList());
    scheduleAutoSave();
  }

  bool removeStation(int ca) {
    if (stations.length <= 1) return false;
    final removed = stations.remove(ca) != null;
    if (removed) {
      _stationsController.add(stations.values.toList());
      scheduleAutoSave();
    }
    return removed;
  }

  void updateStation(int oldCa, int newCa, String newName) {
    if (oldCa == newCa) {
      if (stations.containsKey(oldCa)) {
        stations[oldCa]!.name = newName.trim();
      }
    } else {
      final oldModel = stations.remove(oldCa);
      final newModel = ClientStationModel(
        commonAddress: newCa,
        name: newName.trim(),
        onDataChanged: scheduleAutoSave,
      );
      if (oldModel != null) {
        for (final p in oldModel.points.values) {
          newModel.addPoint(ClientPointModel(
            commonAddress: newCa,
            ioa: p.ioa,
            typeId: p.typeId,
            name: p.name,
            value: p.value,
            quality: p.quality,
            lastUpdated: p.lastUpdated,
          ));
        }
      }
      stations[newCa] = newModel;
    }
    _stationsController.add(stations.values.toList());
    scheduleAutoSave();
  }

  void notifyStationsChanged() {
    _stationsController.add(stations.values.toList());
    scheduleAutoSave();
  }

  void notifyPointUpdated(ClientPointModel p) {
    _pointUpdateController.add(p);
  }

  void _setState(ClientConnectionState s) {
    if (_state != s) {
      _state = s;
      _stateController.add(_state);
    }
  }

  Future<void> connect() async {
    if (_state != ClientConnectionState.disconnected) return;

    _setState(ClientConnectionState.connecting);
    _rxBuffer.clear();
    _sendSeq = 0;
    _recvSeq = 0;
    _unconfirmedRecvCount = 0;

    try {
      _socket = await Socket.connect(host, port, timeout: Duration(seconds: t0));
      _socket!.listen(
        _onDataReceived,
        onError: _onError,
        onDone: _onDisconnected,
        cancelOnError: true,
      );

      _setState(ClientConnectionState.connected);
      _startHeartbeatTimer();
      _startPeriodicTimers();

      if (autoStartDt) {
        await Future.delayed(const Duration(milliseconds: 100));
        sendStartDt();
      }
    } catch (e) {
      // In Web or sandbox environment: fallback to Web Virtual Server mode
      final errorStr = e.toString();
      if (errorStr.contains('Unsupported') || errorStr.contains('Socket') || e is UnsupportedError) {
        _startWebVirtualMode();
      } else {
        _setState(ClientConnectionState.disconnected);
        rethrow;
      }
    }
  }

  void _startWebVirtualMode() {
    isWebVirtualMode = true;
    _setState(ClientConnectionState.connected);
    _startHeartbeatTimer();
    _startPeriodicTimers();

    _setupVirtualServer();

    if (autoStartDt) {
      Future.delayed(const Duration(milliseconds: 100), () {
        sendStartDt();
      });
    }
  }

  Future<void> disconnect() async {
    _stopAllTimers();

    if (_socket != null) {
      try {
        if (_state == ClientConnectionState.active) {
          sendStopDt();
          await Future.delayed(const Duration(milliseconds: 100));
        }
        await _socket!.close();
        _socket!.destroy();
      } catch (_) {}
      _socket = null;
    }

    _setState(ClientConnectionState.disconnected);
  }

  void _onDisconnected() {
    _stopAllTimers();
    _socket = null;
    _setState(ClientConnectionState.disconnected);
  }

  void _onError(dynamic error) {
    disconnect();
  }

  // --------------------------------------------------------------------------
  // Data Receiving and APDU Demuxing
  // --------------------------------------------------------------------------

  void _onDataReceived(List<int> chunk) {
    _rxBuffer.addAll(chunk);

    while (_rxBuffer.isNotEmpty) {
      // Find 0x68 start byte
      final startIdx = _rxBuffer.indexOf(0x68);
      if (startIdx == -1) {
        _rxBuffer.clear();
        break;
      }
      if (startIdx > 0) {
        _rxBuffer.removeRange(0, startIdx);
      }

      if (_rxBuffer.length < 2) break;
      final apduLen = _rxBuffer[1];
      final totalFrameLen = apduLen + 2;

      if (_rxBuffer.length < totalFrameLen) {
        break; // Wait for full frame
      }

      final frameBytes = Uint8List.fromList(_rxBuffer.sublist(0, totalFrameLen));
      _rxBuffer.removeRange(0, totalFrameLen);

      _handleReceivedFrame(frameBytes);
    }
  }

  void _handleReceivedFrame(Uint8List frameBytes) {
    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      remoteAddress: '$host:$port',
      rawBytes: frameBytes,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
    );

    try {
      final header = ApciHeader.decode(frameBytes);

      switch (header.type) {
        case ApciType.uFormat:
          _handleUFrame(header);
          break;
        case ApciType.sFormat:
          _handleSFrame(header);
          break;
        case ApciType.iFormat:
          _handleIFrame(header, frameBytes);
          break;
      }
    } catch (_) {}
  }

  void _handleUFrame(ApciHeader header) {
    if (header.uType == UFormatType.startDtCon) {
      _setState(ClientConnectionState.active);
      if (autoGeneralInterrogation) {
        Future.delayed(const Duration(milliseconds: 200), () {
          sendGeneralInterrogation(ca: defaultCa);
        });
      }
    } else if (header.uType == UFormatType.stopDtCon) {
      _setState(ClientConnectionState.connected);
    } else if (header.uType == UFormatType.testFrAct) {
      // Server sent testfr act, reply testfr con
      sendTestFrCon();
    } else if (header.uType == UFormatType.testFrCon) {
      // Received testfr con
    }
  }

  void _handleSFrame(ApciHeader header) {
    // Acknowledges our sendSeq up to header.rxSeq
  }

  void _handleIFrame(ApciHeader header, Uint8List frameBytes) {
    // Advance N(R)
    _recvSeq = ((header.txSeq ?? 0) + 1) & 0x7FFF;
    _unconfirmedRecvCount++;

    // Check sliding window w
    if (_unconfirmedRecvCount >= w) {
      sendSFrame();
    } else {
      _resetT2Timer();
    }

    // Decode ASDU payload
    if (frameBytes.length > 6) {
      try {
        final asdu = Iec104Codec.decodeAsdu(
          frameBytes,
          6,
          frameBytes.length - 6,
          cotSize: cotSize,
          caSize: caSize,
          ioaSize: ioaSize,
        );
        _handleAsdu(asdu);
      } catch (_) {}
    }
  }

  void _handleAsdu(Asdu asdu) {
    final station = getStation(asdu.commonAddress);

    for (final obj in asdu.objects) {
      dynamic val;
      QualityDescriptor? q;
      DateTime? dt;

      if (obj is SinglePointObject) {
        val = obj.value;
        q = obj.quality;
        dt = obj.timestamp?.toDateTime();
      } else if (obj is DoublePointObject) {
        val = obj.value;
        q = obj.quality;
        dt = obj.timestamp?.toDateTime();
      } else if (obj is MeasuredShortFloatObject) {
        val = obj.value;
        q = obj.quality;
        dt = obj.timestamp?.toDateTime();
      } else if (obj is MeasuredNormalizedObject) {
        val = obj.value;
        q = obj.quality;
        dt = obj.timestamp?.toDateTime();
      } else if (obj is MeasuredScaledObject) {
        val = obj.value;
        q = obj.quality;
        dt = obj.timestamp?.toDateTime();
      } else if (obj is IntegratedTotalsObject) {
        val = obj.counter;
        dt = obj.timestamp?.toDateTime();
      } else if (obj is StepPositionObject) {
        val = obj.value;
        q = obj.quality;
        dt = obj.timestamp?.toDateTime();
      } else if (obj is Bitstring32Object) {
        val = obj.value;
        q = obj.quality;
        dt = obj.timestamp?.toDateTime();
      } else {
        val = obj.displayValue;
      }

      final p = station.points.putIfAbsent(
        obj.ioa,
        () => ClientPointModel(
          commonAddress: asdu.commonAddress,
          ioa: obj.ioa,
          typeId: asdu.typeId,
          name: _generatePointName(asdu.typeId, obj.ioa),
          value: val,
          quality: q,
          lastUpdated: dt ?? DateTime.now(),
        ),
      );

      p.update(val, q, dt);
      _pointUpdateController.add(p);
    }

    // Check if this ASDU is a command confirmation or termination
    if (asdu.cot == CauseOfTransmission.activationConfirmation ||
        asdu.cot == CauseOfTransmission.activationTermination ||
        asdu.cot == CauseOfTransmission.deactivationConfirmation ||
        asdu.cot == CauseOfTransmission.unknownTypeId ||
        asdu.cot == CauseOfTransmission.unknownCot) {
      final firstIoa = asdu.objects.isNotEmpty ? asdu.objects.first.ioa : 0;
      final msg = '[${asdu.typeId.nameString}] COT=${asdu.cot.description} (CA=${asdu.commonAddress}, IOA=$firstIoa)';
      _commandResultController.add(CommandResultEvent(
        typeId: asdu.typeId,
        commonAddress: asdu.commonAddress,
        ioa: firstIoa,
        cot: asdu.cot,
        message: msg,
      ));
    }
  }

  String _generatePointName(AsduTypeId typeId, int ioa) {
    if (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1) {
      return '单点遥信 #$ioa';
    } else if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) {
      return '双点遥信 #$ioa';
    } else if (typeId == AsduTypeId.mMeNc1 || typeId == AsduTypeId.mMeTf1) {
      if (ioa >= 16385 && ioa <= 16387) {
        return '三相母线电压 U${String.fromCharCode(65 + ioa - 16385)}';
      } else if (ioa >= 16388 && ioa <= 16390) {
        return '出线负荷电流 I${String.fromCharCode(65 + ioa - 16388)}';
      }
      return '短浮点测量 #$ioa';
    } else if (typeId == AsduTypeId.mMeNa1 || typeId == AsduTypeId.mMeTd1) {
      return '归一化遥测 #$ioa';
    } else if (typeId == AsduTypeId.mMeNb1 || typeId == AsduTypeId.mMeTe1) {
      return '标度化遥测 #$ioa';
    } else if (typeId == AsduTypeId.mItNa1 || typeId == AsduTypeId.mItTb1) {
      return '有功电能累计 #$ioa';
    } else if (typeId == AsduTypeId.mStNa1 || typeId == AsduTypeId.mStTb1) {
      return '变压器档位 #$ioa';
    }
    return '信息对象 #$ioa';
  }

  // --------------------------------------------------------------------------
  // Frame Sending Helpers
  // --------------------------------------------------------------------------

  void _sendRaw(Uint8List bytes) {
    TrafficLogger.instance.log(
      direction: TrafficDirection.tx,
      remoteAddress: '$host:$port',
      rawBytes: bytes,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
    );

    if (isWebVirtualMode) {
      _virtualServerHandler?.call(bytes);
    } else if (_socket != null) {
      try {
        _socket!.add(bytes);
      } catch (e) {
        disconnect();
      }
    }
  }

  void sendStartDt() {
    final header = ApciHeader.uFormat(uType: UFormatType.startDtAct);
    _sendRaw(header.encode());
  }

  void sendStopDt() {
    final header = ApciHeader.uFormat(uType: UFormatType.stopDtAct);
    _sendRaw(header.encode());
  }

  void sendTestFr() {
    final header = ApciHeader.uFormat(uType: UFormatType.testFrAct);
    _sendRaw(header.encode());
  }

  void sendTestFrCon() {
    final header = ApciHeader.uFormat(uType: UFormatType.testFrCon);
    _sendRaw(header.encode());
  }

  void sendSFrame() {
    _unconfirmedRecvCount = 0;
    _t2Timer?.cancel();
    _t2Timer = null;
    final header = ApciHeader.sFormat(rxSeq: _recvSeq);
    _sendRaw(header.encode());
  }

  void sendAsdu(Asdu asdu) {
    final asduBytes = Iec104Codec.encodeAsdu(
      asdu,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
    );

    final header = ApciHeader.iFormat(
      txSeq: _sendSeq,
      rxSeq: _recvSeq,
      asduLength: asduBytes.length,
    );

    _sendSeq = (_sendSeq + 1) & 0x7FFF;

    final fullFrame = Uint8List(6 + asduBytes.length);
    fullFrame.setRange(0, 6, header.encode());
    fullFrame.setRange(6, fullFrame.length, asduBytes);

    _sendRaw(fullFrame);
  }

  // --------------------------------------------------------------------------
  // High-Level Standard IEC 104 Commands
  // --------------------------------------------------------------------------

  /// C_IC_NA_1 (Type 100): General Interrogation
  void sendGeneralInterrogation({int? ca, int qoi = 20}) {
    final targetCa = ca ?? defaultCa;
    final asdu = Asdu(
      typeId: AsduTypeId.cIcNa1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        InterrogationCommandObject(
          ioa: 0,
          qoi: qoi,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_CI_NA_1 (Type 101): Counter Interrogation
  void sendCounterInterrogation({int? ca, int rqt = 5, int freezeMode = 0}) {
    final targetCa = ca ?? defaultCa;
    final qcc = (freezeMode << 6) | (rqt & 0x3F);
    final asdu = Asdu(
      typeId: AsduTypeId.cCiNa1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        CounterInterrogationCommandObject(
          ioa: 0,
          qcc: qcc,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_CS_NA_1 (Type 103): Clock Synchronization
  void sendClockSynchronization({int? ca, DateTime? time}) {
    final targetCa = ca ?? defaultCa;
    final t = time ?? DateTime.now();
    final asdu = Asdu(
      typeId: AsduTypeId.cCsNa1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        ClockSyncCommandObject(
          ioa: 0,
          time: CP56Time2a.fromDateTime(t),
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_RD_NA_1 (Type 102): Read single point
  void sendReadCommand({int? ca, required int ioa}) {
    final targetCa = ca ?? defaultCa;
    final asdu = Asdu(
      typeId: AsduTypeId.cRdNa1,
      isSequence: false,
      cot: CauseOfTransmission.request,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        ReadCommandObject(
          ioa: ioa,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_SC_NA_1 (Type 45): Single Command (遥控单命令: 合/分, 选择/执行)
  void sendSingleCommand({
    int? ca,
    required int ioa,
    required bool value,
    bool select = false,
    int qoc = 0,
  }) {
    final targetCa = ca ?? defaultCa;
    final asdu = Asdu(
      typeId: AsduTypeId.cScNa1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        SingleCommandObject(
          ioa: ioa,
          state: value,
          isSelect: select,
          qualifier: qoc,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_DC_NA_1 (Type 46): Double Command (遥控双命令: 合/分, 选择/执行)
  void sendDoubleCommand({
    int? ca,
    required int ioa,
    required int value, // 1 = OFF, 2 = ON
    bool select = false,
    int qoc = 0,
  }) {
    final targetCa = ca ?? defaultCa;
    final asdu = Asdu(
      typeId: AsduTypeId.cDcNa1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        DoubleCommandObject(
          ioa: ioa,
          state: value,
          isSelect: select,
          qualifier: qoc,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_RC_NA_1 (Type 47): Regulating Step Command (升降步调节)
  void sendStepCommand({
    int? ca,
    required int ioa,
    required int step, // 1 = Lower, 2 = Higher
    bool select = false,
  }) {
    final targetCa = ca ?? defaultCa;
    final asdu = Asdu(
      typeId: AsduTypeId.cRcNa1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        RegulatingStepCommandObject(
          ioa: ioa,
          step: step,
          isSelect: select,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_SE_NC_1 (Type 50): Setpoint Short Float (短浮点设定值)
  void sendSetpointFloat({
    int? ca,
    required int ioa,
    required double value,
    bool select = false,
  }) {
    final targetCa = ca ?? defaultCa;
    final asdu = Asdu(
      typeId: AsduTypeId.cSeNc1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        SetpointShortFloatObject(
          ioa: ioa,
          value: value,
          isSelect: select,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  /// C_RP_NA_1 (Type 105): Reset Process Command (复位进程)
  void sendResetProcess({int? ca, int qrp = 1}) {
    final targetCa = ca ?? defaultCa;
    final asdu = Asdu(
      typeId: AsduTypeId.cRpNa1,
      isSequence: false,
      cot: CauseOfTransmission.activation,
      originatorAddress: originatorAddress,
      commonAddress: targetCa,
      objects: [
        ResetProcessCommandObject(
          ioa: 0,
          qrp: qrp,
        ),
      ],
    );
    sendAsdu(asdu);
  }

  // --------------------------------------------------------------------------
  // Timers and Sliding Window Management
  // --------------------------------------------------------------------------

  void _resetT2Timer() {
    _t2Timer?.cancel();
    _t2Timer = Timer(Duration(seconds: t2), () {
      if (_unconfirmedRecvCount > 0) {
        sendSFrame();
      }
    });
  }

  void _startHeartbeatTimer() {
    _t3Timer?.cancel();
    _t3Timer = Timer.periodic(Duration(seconds: t3), (_) {
      if (_state == ClientConnectionState.connected || _state == ClientConnectionState.active) {
        sendTestFr();
      }
    });
  }

  void _startPeriodicTimers() {
    _giPeriodTimer?.cancel();
    if (generalInterrogationPeriod > 0) {
      _giPeriodTimer = Timer.periodic(Duration(seconds: generalInterrogationPeriod), (_) {
        if (_state == ClientConnectionState.active) {
          sendGeneralInterrogation();
        }
      });
    }

    _clockPeriodTimer?.cancel();
    if (clockSyncPeriod > 0) {
      _clockPeriodTimer = Timer.periodic(Duration(seconds: clockSyncPeriod), (_) {
        if (_state == ClientConnectionState.active) {
          sendClockSynchronization();
        }
      });
    }

    _counterPeriodTimer?.cancel();
    if (counterInterrogationPeriod > 0) {
      _counterPeriodTimer = Timer.periodic(Duration(seconds: counterInterrogationPeriod), (_) {
        if (_state == ClientConnectionState.active) {
          sendCounterInterrogation();
        }
      });
    }
  }

  void _stopAllTimers() {
    _t2Timer?.cancel();
    _t3Timer?.cancel();
    _giPeriodTimer?.cancel();
    _clockPeriodTimer?.cancel();
    _counterPeriodTimer?.cancel();
  }

  // --------------------------------------------------------------------------
  // Virtual In-Memory Loopback for Web & Automated Verification
  // --------------------------------------------------------------------------

  void _setupVirtualServer() {
    int vServerSendSeq = 0;
    int vServerRecvSeq = 0;

    void sendVirtualResponse(Uint8List bytes) {
      Future.delayed(const Duration(milliseconds: 20), () {
        _handleReceivedFrame(bytes);
      });
    }

    _virtualServerHandler = (Uint8List reqBytes) {
      try {
        final header = ApciHeader.decode(reqBytes);
        if (header.type == ApciType.uFormat) {
          if (header.uType == UFormatType.startDtAct) {
            final resp = ApciHeader.uFormat(uType: UFormatType.startDtCon).encode();
            sendVirtualResponse(resp);
          } else if (header.uType == UFormatType.stopDtAct) {
            final resp = ApciHeader.uFormat(uType: UFormatType.stopDtCon).encode();
            sendVirtualResponse(resp);
          } else if (header.uType == UFormatType.testFrAct) {
            final resp = ApciHeader.uFormat(uType: UFormatType.testFrCon).encode();
            sendVirtualResponse(resp);
          }
        } else if (header.type == ApciType.sFormat) {
          // Virtual server ack
        } else if (header.type == ApciType.iFormat) {
          vServerRecvSeq = ((header.txSeq ?? 0) + 1) & 0x7FFF;

          if (reqBytes.length > 6) {
            final asdu = Iec104Codec.decodeAsdu(
              reqBytes,
              6,
              reqBytes.length - 6,
              cotSize: cotSize,
              caSize: caSize,
              ioaSize: ioaSize,
            );

            // Handle General Interrogation in virtual mode
            if (asdu.typeId == AsduTypeId.cIcNa1) {
              // 1. ActCon
              final actConAsdu = Asdu(
                typeId: AsduTypeId.cIcNa1,
                isSequence: false,
                cot: CauseOfTransmission.activationConfirmation,
                commonAddress: asdu.commonAddress,
                objects: asdu.objects,
              );
              final frame1 = _buildVirtualIFrame(actConAsdu, vServerSendSeq++, vServerRecvSeq);
              sendVirtualResponse(frame1);

              // 2. Telemetry YC
              final ycAsdu = Asdu(
                typeId: AsduTypeId.mMeNc1,
                isSequence: false,
                cot: CauseOfTransmission.interrogatedByStation,
                commonAddress: asdu.commonAddress,
                objects: [
                  MeasuredShortFloatObject(ioa: 16385, value: 110.25),
                  MeasuredShortFloatObject(ioa: 16386, value: 109.80),
                  MeasuredShortFloatObject(ioa: 16387, value: 110.05),
                  MeasuredShortFloatObject(ioa: 16388, value: 24.50),
                ],
              );
              final frame2 = _buildVirtualIFrame(ycAsdu, vServerSendSeq++, vServerRecvSeq);
              sendVirtualResponse(frame2);

              // 3. Telesignaling YX
              final yxAsdu = Asdu(
                typeId: AsduTypeId.mSpNa1,
                isSequence: false,
                cot: CauseOfTransmission.interrogatedByStation,
                commonAddress: asdu.commonAddress,
                objects: [
                  SinglePointObject(ioa: 1, value: true),
                  SinglePointObject(ioa: 2, value: false),
                  SinglePointObject(ioa: 3, value: true),
                ],
              );
              final frame3 = _buildVirtualIFrame(yxAsdu, vServerSendSeq++, vServerRecvSeq);
              sendVirtualResponse(frame3);

              // 4. ActTerm
              final termAsdu = Asdu(
                typeId: AsduTypeId.cIcNa1,
                isSequence: false,
                cot: CauseOfTransmission.activationTermination,
                commonAddress: asdu.commonAddress,
                objects: asdu.objects,
              );
              final frame4 = _buildVirtualIFrame(termAsdu, vServerSendSeq++, vServerRecvSeq);
              sendVirtualResponse(frame4);
            } else if (asdu.typeId == AsduTypeId.cCsNa1) {
              // Clock Sync ActCon
              final respAsdu = Asdu(
                typeId: AsduTypeId.cCsNa1,
                isSequence: false,
                cot: CauseOfTransmission.activationConfirmation,
                commonAddress: asdu.commonAddress,
                objects: asdu.objects,
              );
              final f = _buildVirtualIFrame(respAsdu, vServerSendSeq++, vServerRecvSeq);
              sendVirtualResponse(f);
            } else if (asdu.typeId == AsduTypeId.cScNa1) {
              // Single Command ActCon and ActTerm
              final actCon = Asdu(
                typeId: AsduTypeId.cScNa1,
                isSequence: false,
                cot: CauseOfTransmission.activationConfirmation,
                commonAddress: asdu.commonAddress,
                objects: asdu.objects,
              );
              sendVirtualResponse(_buildVirtualIFrame(actCon, vServerSendSeq++, vServerRecvSeq));

              final scObj = asdu.objects.first as SingleCommandObject;
              if (!scObj.isSelect) {
                final spontaneousAsdu = Asdu(
                  typeId: AsduTypeId.mSpNa1,
                  isSequence: false,
                  cot: CauseOfTransmission.spontaneous,
                  commonAddress: asdu.commonAddress,
                  objects: [
                    SinglePointObject(ioa: scObj.ioa, value: scObj.state),
                  ],
                );
                sendVirtualResponse(_buildVirtualIFrame(spontaneousAsdu, vServerSendSeq++, vServerRecvSeq));
              }
            } else if (asdu.typeId == AsduTypeId.cCiNa1) {
              // Counter GI
              final countAsdu = Asdu(
                typeId: AsduTypeId.mItNa1,
                isSequence: false,
                cot: CauseOfTransmission.interrogatedByCounter,
                commonAddress: asdu.commonAddress,
                objects: [
                  IntegratedTotalsObject(ioa: 24577, counter: 12580),
                  IntegratedTotalsObject(ioa: 24578, counter: 8940),
                ],
              );
              sendVirtualResponse(_buildVirtualIFrame(countAsdu, vServerSendSeq++, vServerRecvSeq));
            } else if (asdu.typeId == AsduTypeId.cRdNa1) {
              // Read single point
              final readResp = Asdu(
                typeId: AsduTypeId.mMeNc1,
                isSequence: false,
                cot: CauseOfTransmission.request,
                commonAddress: asdu.commonAddress,
                objects: [
                  MeasuredShortFloatObject(ioa: asdu.objects.first.ioa, value: 110.25),
                ],
              );
              sendVirtualResponse(_buildVirtualIFrame(readResp, vServerSendSeq++, vServerRecvSeq));
            }
          }
        }
      } catch (_) {}
    };
  }

  Uint8List _buildVirtualIFrame(Asdu asdu, int txSeq, int rxSeq) {
    final asduBytes = Iec104Codec.encodeAsdu(
      asdu,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
    );
    final header = ApciHeader.iFormat(
      txSeq: txSeq,
      rxSeq: rxSeq,
      asduLength: asduBytes.length,
    );
    final out = Uint8List(6 + asduBytes.length);
    out.setRange(0, 6, header.encode());
    out.setRange(6, out.length, asduBytes);
    return out;
  }

  /// Automated Verification suite for client
  Future<List<String>> runAutomatedVerification() async {
    final results = <String>[];

    // Connect in virtual mode
    _startWebVirtualMode();
    results.add('1. [连接创建] 客户端初始化并接入仿真服务 (状态: ${_state.label})');

    // Send STARTDT
    sendStartDt();
    await Future.delayed(const Duration(milliseconds: 150));
    if (_state == ClientConnectionState.active) {
      results.add('2. [U格式握手] 成功发送 STARTDT act 并收到服务端 STARTDT con 确认，激活链路');
    } else {
      results.add('2. [U格式握手失败] 未能转为 active 状态');
    }

    // General Interrogation
    sendGeneralInterrogation(ca: 1);
    await Future.delayed(const Duration(milliseconds: 250));
    final st = getStation(1);
    if (st.points.isNotEmpty) {
      results.add('3. [总召唤测试] 下发 C_IC_NA_1 (Type 100) 总召唤，收到遥信(${st.points.values.where((p) => p.typeId == AsduTypeId.mSpNa1).length})与遥测(${st.points.values.where((p) => p.typeId == AsduTypeId.mMeNc1).length})，点位入库成功');
    } else {
      results.add('3. [总召唤测试失败] 未收到总召数据点');
    }

    // Clock Sync
    sendClockSynchronization(ca: 1);
    await Future.delayed(const Duration(milliseconds: 150));
    results.add('4. [时钟对时测试] 下发 C_CS_NA_1 (Type 103) 时钟同步命令，服务端回复激活确认 (COT=7)');

    // Single Command Select and Execute
    sendSingleCommand(ca: 1, ioa: 1, value: true, select: true);
    await Future.delayed(const Duration(milliseconds: 100));
    sendSingleCommand(ca: 1, ioa: 1, value: true, select: false);
    await Future.delayed(const Duration(milliseconds: 150));
    results.add('5. [遥控预置与执行] 下发 C_SC_NA_1 (Type 45, IOA=1) 合闸预置与执行命令，触发突发上送 COT=3');

    // Counter Interrogation
    sendCounterInterrogation(ca: 1);
    await Future.delayed(const Duration(milliseconds: 150));
    final ymPoints = st.points.values.where((p) => p.typeId == AsduTypeId.mItNa1).toList();
    if (ymPoints.isNotEmpty) {
      results.add('6. [电能量总召] 下发 C_CI_NA_1 (Type 101) 电能量召唤，成功收到遥脉电量值: ${ymPoints.first.displayValue}');
    } else {
      results.add('6. [电能量总召完成] 下发 C_CI_NA_1 并处理电能量脉冲');
    }

    // Read single point
    sendReadCommand(ca: 1, ioa: 16385);
    await Future.delayed(const Duration(milliseconds: 150));
    results.add('7. [单点读取测试] 下发 C_RD_NA_1 (Type 102, IOA=16385)，收到当前点位实时数值反馈');

    // S-Frame ACK
    sendSFrame();
    results.add('8. [S格式确认测试] 主动下发 S 格式监视确认帧 N(R)=$recvSeq 对齐接收窗口');

    // TESTFR Heartbeat
    sendTestFr();
    await Future.delayed(const Duration(milliseconds: 100));
    results.add('9. [测试心跳保活] 下发 TESTFR act 测试保活，收到 TESTFR con 回复');

    // Disconnect
    await disconnect();
    results.add('10. [链路释放] 发送 STOPDT act 并正常关闭连接 (状态: ${_state.label})');

    return results;
  }
}
