import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/scl_models.dart';
import '../models/scl_parser.dart';
import '../models/server_config.dart';
import '../models/server_variable_model.dart';
import '../services/simulation_service.dart';
import '../services/traffic_logger.dart';
import 'goose_publisher.dart';
import 'iec61850_server_engine.dart';
import 'iso_acse_mms.dart';
import 'tpkt_cotp.dart';

class ClientSession {
  final String id;
  final Socket socket;
  final String remoteEndpoint;
  final List<int> rxBuffer = [];
  DateTime connectedAt;

  ClientSession({
    required this.id,
    required this.socket,
    required this.remoteEndpoint,
  }) : connectedAt = DateTime.now();
}

class Iec61850ServerManager {
  final ServerConfig config;
  late final Iec61850ServerEngine engine;
  final GoosePublisherService gooseService = GoosePublisherService.instance;
  final SimulationService simulationService = SimulationService.instance;
  final TrafficLogger logger = TrafficLogger.instance;

  ServerSocket? _serverSocket;
  final Map<String, ClientSession> _sessions = {};
  int _clientSequence = 0;

  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notifyListeners() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  Iec61850ServerManager({required this.config}) {
    engine = Iec61850ServerEngine(config: config);
    engine.onReportGenerated = _broadcastReport;

    // Connect simulation changes to report triggering
    simulationService.onVariableUpdated = (variable) {
      _checkAndTriggerReportsForVariable(variable);
    };
  }

  bool get isRunning => config.isRunning;
  int get clientCount => _sessions.length;

  Future<bool> startServer() async {
    if (isRunning) return true;

    try {
      final bindIp = config.ip == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(config.ip);
      _serverSocket = await ServerSocket.bind(bindIp, config.port, shared: true);

      config.isRunning = true;
      config.statusMessage = '服务已启动: ${bindIp.address}:${config.port}';
      config.notifyUpdated();

      _serverSocket!.listen(
        _onClientConnected,
        onError: (err) {
          config.statusMessage = '服务监听异常: $err';
          config.notifyUpdated();
        },
        onDone: () {
          stopServer();
        },
      );

      // Start background services (1000ms telemetry cycle)
      simulationService.start(intervalMs: 1000);
      gooseService.startAll();

      _notifyListeners();
      return true;
    } catch (e) {
      config.isRunning = false;
      if (e is SocketException && e.osError?.errorCode == 13) {
        config.statusMessage = '启动失败: 端口 ${config.port} 需要超级用户权限 (EACCES)。可切换为非特权端口 (如 10102) 测试。';
      } else {
        config.statusMessage = '启动失败: $e';
      }
      config.notifyUpdated();
      _notifyListeners();
      return false;
    }
  }

  void stopServer() {
    for (final session in List.of(_sessions.values)) {
      try {
        session.socket.destroy();
      } catch (_) {}
    }
    _sessions.clear();

    _serverSocket?.close();
    _serverSocket = null;

    simulationService.stop();
    gooseService.stopAll();

    config.isRunning = false;
    config.clientCount = 0;
    config.statusMessage = '服务已停止';
    config.notifyUpdated();
    _notifyListeners();
  }

  void restartServer() {
    stopServer();
    Future.delayed(const Duration(milliseconds: 300), () {
      startServer();
    });
  }

  void loadScl(SclParseResult result) {
    config.sclFilePath = result.iedName;
    engine.loadScl(result);
    simulationService.setVariables(result.variables);
    gooseService.initialize(
      controls: result.gseControls,
      dataSets: result.dataSets,
      allVariables: result.variables,
    );
    config.notifyUpdated();
    _notifyListeners();
  }

  void _onClientConnected(Socket socket) {
    final clientId = 'Client_${++_clientSequence}';
    final endpoint = '${socket.remoteAddress.address}:${socket.remotePort}';
    final session = ClientSession(id: clientId, socket: socket, remoteEndpoint: endpoint);

    _sessions[clientId] = session;
    engine.registerClient(clientId, endpoint);
    config.clientCount = _sessions.length;
    config.notifyUpdated();
    _notifyListeners();

    logger.log(
      direction: TrafficDirection.rx,
      clientEndpoint: endpoint,
      protocol: 'TCP',
      service: 'Connect',
      rawBytes: Uint8List(0),
      summary: 'Client connected: $endpoint ($clientId)',
    );

    socket.listen(
      (data) => _onClientData(session, data),
      onError: (err) {
        _onClientDisconnected(session, 'Error: $err');
      },
      onDone: () {
        _onClientDisconnected(session, 'Connection closed');
      },
      cancelOnError: true,
    );
  }

  void _onClientDisconnected(ClientSession session, String reason) {
    _sessions.remove(session.id);
    engine.unregisterClient(session.id);
    config.clientCount = _sessions.length;
    config.notifyUpdated();
    _notifyListeners();

    logger.log(
      direction: TrafficDirection.rx,
      clientEndpoint: session.remoteEndpoint,
      protocol: 'TCP',
      service: 'Disconnect',
      rawBytes: Uint8List(0),
      summary: 'Client disconnected: ${session.remoteEndpoint} ($reason)',
    );
  }

  void _onClientData(ClientSession session, List<int> chunk) {
    session.rxBuffer.addAll(chunk);
    config.rxCount++;
    config.notifyUpdated();

    while (session.rxBuffer.isNotEmpty) {
      final bufferBytes = Uint8List.fromList(session.rxBuffer);
      final frame = TpktFrame.extract(bufferBytes);
      if (frame == null) {
        // Not enough data for a complete TPKT packet yet
        break;
      }

      session.rxBuffer.removeRange(0, frame.consumed);
      _handleTpktPayload(session, frame.payload);
    }
  }

  void _handleTpktPayload(ClientSession session, Uint8List tpktPayload) {
    if (tpktPayload.isEmpty) return;

    // 1. COTP Connection Request (CR)
    if (CotpFrame.isConnectionRequest(tpktPayload)) {
      logger.log(
        direction: TrafficDirection.rx,
        clientEndpoint: session.remoteEndpoint,
        protocol: 'COTP',
        service: 'Connection Request (CR)',
        rawBytes: tpktPayload,
        summary: 'COTP CR received',
      );

      final cc = CotpFrame.buildConnectionConfirm(dstRef: 0x0001, srcRef: 0x0001);
      final txTpkt = TpktFrame.wrap(cc);
      session.socket.add(txTpkt);
      config.txCount++;

      logger.log(
        direction: TrafficDirection.tx,
        clientEndpoint: session.remoteEndpoint,
        protocol: 'COTP',
        service: 'Connection Confirm (CC)',
        rawBytes: txTpkt,
        summary: 'COTP CC replied',
      );
      return;
    }

    // 2. COTP Data Transfer (DT)
    final cotpData = CotpFrame.extractDataPayload(tpktPayload);
    if (cotpData == null || cotpData.isEmpty) return;

    // Check if ACSE AARQ
    if (IsoAcseMms.isAarq(cotpData)) {
      logger.log(
        direction: TrafficDirection.rx,
        clientEndpoint: session.remoteEndpoint,
        protocol: 'ACSE',
        service: 'Association Request (AARQ)',
        rawBytes: cotpData,
        summary: 'ACSE AARQ received with MMS Initiate Request',
      );

      final aare = IsoAcseMms.buildAareWithMmsInitiate();
      final cotpDt = CotpFrame.wrapDataTransfer(aare);
      final txTpkt = TpktFrame.wrap(cotpDt);
      session.socket.add(txTpkt);
      config.txCount++;

      logger.log(
        direction: TrafficDirection.tx,
        clientEndpoint: session.remoteEndpoint,
        protocol: 'ACSE',
        service: 'Association Response (AARE - Accepted)',
        rawBytes: txTpkt,
        summary: 'ACSE AARE replied with MMS Initiate Response',
      );
      return;
    }

    // 3. MMS PDU inside Session / Presentation
    final mmsPdu = IsoAcseMms.extractMmsPdu(cotpData) ?? cotpData;
    final mmsResp = engine.processMmsPdu(
      mmsPdu,
      clientId: session.id,
      clientEndpoint: session.remoteEndpoint,
    );

    if (mmsResp != null) {
      final presPdu = IsoAcseMms.wrapMmsPdu(mmsResp);
      final cotpDt = CotpFrame.wrapDataTransfer(presPdu);
      final txTpkt = TpktFrame.wrap(cotpDt);
      session.socket.add(txTpkt);
      config.txCount++;

      logger.log(
        direction: TrafficDirection.tx,
        clientEndpoint: session.remoteEndpoint,
        protocol: 'MMS',
        service: 'Confirmed Response',
        rawBytes: txTpkt,
        summary: 'MMS response sent (${mmsResp.length} bytes)',
      );
    }
  }

  void _broadcastReport(dynamic rcb, Uint8List unconfirmedPdu) {
    if (_sessions.isEmpty) return;

    final presPdu = IsoAcseMms.wrapMmsPdu(unconfirmedPdu);
    final cotpDt = CotpFrame.wrapDataTransfer(presPdu);
    final txTpkt = TpktFrame.wrap(cotpDt);

    for (final session in _sessions.values) {
      try {
        session.socket.add(txTpkt);
        config.txCount++;
      } catch (_) {}
    }
  }

  void _checkAndTriggerReportsForVariable(ServerVariableModel variable) {
    if (_sessions.isEmpty) return;

    final now = DateTime.now();
    for (final rcb in engine.reportControls) {
      // 没开启使能 RptEna = FALSE 不推送变更报告
      if (!rcb.rptEna) continue;

      // 遵守缓冲时间防抖抑制
      if (rcb.lastReportTime != null && rcb.bufTime > 0) {
        if (now.difference(rcb.lastReportTime!).inMilliseconds < rcb.bufTime) {
          continue;
        }
      }

      final ds = engine.dataSets.firstWhere((d) => d.name == rcb.datSet, orElse: () => SclDataSet(name: '', ldInst: '', lnName: ''));
      if (ds.name.isNotEmpty) {
        final matches = ds.entries.any((fcda) =>
            variable.ldInst == fcda.ldInst &&
            variable.lnName == fcda.fullLnName &&
            variable.doName == fcda.doName &&
            (fcda.daName == null || variable.daName == fcda.daName));
        if (matches) {
          engine.triggerReport(rcb, isGI: false);
        }
      }
    }
  }
}
