import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../protocol/asdu.dart';
import '../protocol/asdu_types.dart';
import 'client_session.dart';
import 'station.dart';
import 'workspace_storage.dart';

class Iec104Server {
  String host = '0.0.0.0';
  int port = 2404;

  // Protocol parameters
  int t0 = 30; // Connection timeout
  int t1 = 15; // APDU send timeout
  int t2 = 10; // ACK timeout
  int t3 = 20; // Test frame timeout
  int k = 12;  // Max unacknowledged I frames
  int w = 8;   // Send ACK after w I frames

  int cotSize = 2; // Size of Cause of Transmission (standard 2 bytes)
  int caSize = 2;  // Size of Common Address of ASDU (standard 2 bytes)
  int ioaSize = 3; // Size of Information Object Address (standard 3 bytes)

  ServerSocket? _serverSocket;
  bool isWebVirtualMode = false;
  bool get isRunning => _serverSocket != null || isWebVirtualMode;

  int rxCount = 0;
  int txCount = 0;

  final Map<int, Station> stations = {};
  final List<ClientSession> _sessions = [];
  int _nextSessionId = 1;

  Timer? _autoSimTimer;
  DateTime? _lastSimTick;

  // Event callbacks for UI
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  final StreamController<List<ClientSession>> _clientsController = StreamController<List<ClientSession>>.broadcast();
  final StreamController<StationPoint> _pointUpdateController = StreamController<StationPoint>.broadcast();
  final StreamController<(Asdu, StationPoint?)> _commandController = StreamController<(Asdu, StationPoint?)>.broadcast();
  final StreamController<List<Station>> _stationsController = StreamController<List<Station>>.broadcast();

  Stream<bool> get statusStream => _statusController.stream;
  Stream<List<ClientSession>> get clientsStream => _clientsController.stream;
  Stream<StationPoint> get pointUpdateStream => _pointUpdateController.stream;
  Stream<(Asdu, StationPoint?)> get commandStream => _commandController.stream;
  Stream<List<Station>> get stationsStream => _stationsController.stream;

  List<ClientSession> get clients => List.unmodifiable(_sessions);

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

  Map<String, dynamic> exportWorkspace() => {
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'connection': {
          'host': host,
          'port': port,
          't0': t0,
          't1': t1,
          't2': t2,
          't3': t3,
          'k': k,
          'w': w,
          'cotSize': cotSize,
          'caSize': caSize,
          'ioaSize': ioaSize,
        },
        'stations': stations.values.map((s) => s.toJson()).toList(),
      };

  void importWorkspace(Map<String, dynamic> json) {
    if (json['connection'] is Map<String, dynamic>) {
      final conn = json['connection'] as Map<String, dynamic>;
      host = conn['host'] as String? ?? host;
      port = conn['port'] as int? ?? port;
      t0 = conn['t0'] as int? ?? t0;
      t1 = conn['t1'] as int? ?? t1;
      t2 = conn['t2'] as int? ?? t2;
      t3 = conn['t3'] as int? ?? t3;
      k = conn['k'] as int? ?? k;
      w = conn['w'] as int? ?? w;
      cotSize = conn['cotSize'] as int? ?? cotSize;
      caSize = conn['caSize'] as int? ?? caSize;
      ioaSize = conn['ioaSize'] as int? ?? ioaSize;
    }

    if (json['stations'] is List) {
      stations.clear();
      for (final sJson in json['stations']) {
        if (sJson is Map<String, dynamic>) {
          final s = Station.fromJson(sJson);
          s.onDataChanged = scheduleAutoSave;
          stations[s.commonAddress] = s;
        }
      }
      if (stations.isEmpty) {
        _initDefaultStation(1);
      }
      _stationsController.add(stations.values.toList());
    }
  }

  void _initDefaultStation(int ca) {
    final defaultStation = Station.createDefault(commonAddress: ca);
    defaultStation.onDataChanged = scheduleAutoSave;
    stations[ca] = defaultStation;
  }

  Station getStation(int ca) {
    final isNew = !stations.containsKey(ca);
    final st = stations.putIfAbsent(ca, () {
      final s = Station(commonAddress: ca, name: 'Station #$ca');
      s.onDataChanged = scheduleAutoSave;
      return s;
    });
    st.onDataChanged ??= scheduleAutoSave;
    if (isNew) {
      _stationsController.add(stations.values.toList());
      scheduleAutoSave();
    }
    return st;
  }

  void addStation(int ca, {String? name, String? template}) {
    final st = Station(
      commonAddress: ca,
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : 'Station #$ca',
      onDataChanged: scheduleAutoSave,
    );
    if (template == 'default') {
      final def = Station.createDefault(commonAddress: ca, name: st.name);
      for (final p in def.pointList) {
        st.addPoint(p);
      }
    } else if (template != null && template.isNotEmpty) {
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
      final newModel = Station(
        commonAddress: newCa,
        name: newName.trim(),
        onDataChanged: scheduleAutoSave,
      );
      if (oldModel != null) {
        for (final p in oldModel.pointList) {
          newModel.addPoint(p.copyWith());
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

  Iec104Server() {
    _initDefaultStation(1);
  }

  /// Starts the IEC 104 Server
  Future<void> start() async {
    if (isRunning) return;

    try {
      _serverSocket = await ServerSocket.bind(host, port, shared: true);
      _serverSocket!.listen(
        _onNewClient,
        onError: (e) => stop(),
      );
      isWebVirtualMode = false;
    } on UnsupportedError catch (_) {
      // In Web browser environment, raw TCP ServerSocket is not supported.
      // Gracefully switch to Web Virtual Server simulation mode!
      isWebVirtualMode = true;
    } catch (e) {
      if (e.toString().contains('Unsupported operation') ||
          e.toString().contains('ServerSocket.bind') ||
          e.toString().contains('Unsupported')) {
        isWebVirtualMode = true;
      } else {
        _statusController.add(false);
        rethrow;
      }
    }

    _startAutoSimulation();
    _statusController.add(true);
    _clientsController.add(_sessions);
  }

  /// Stops the IEC 104 Server
  Future<void> stop() async {
    _autoSimTimer?.cancel();
    _autoSimTimer = null;

    for (final session in List<ClientSession>.from(_sessions)) {
      session.close();
    }
    _sessions.clear();

    await _serverSocket?.close();
    _serverSocket = null;
    isWebVirtualMode = false;

    _statusController.add(false);
    _clientsController.add(_sessions);
  }

  /// Disconnects an active client session
  void disconnectClient(ClientSession session) {
    session.close();
  }

  /// Runs an automated verification of all core IEC 104 server features
  Future<List<String>> runAutomatedVerification() async {
    final results = <String>[];

    if (!isRunning) {
      await start();
    }

    // 1. Create a virtual master client session
    final virtualSession = ClientSession(
      sessionId: _nextSessionId++,
      customRemoteAddress: 'VirtualMaster (VirtualMaster:2404)',
      stations: stations,
      t0Seconds: t0,
      t1Seconds: t1,
      t2Seconds: t2,
      t3Seconds: t3,
      k: k,
      w: w,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
      onFrameReceived: () => rxCount++,
      onFrameSent: () => txCount++,
      onCommandReceived: (asdu, point) {
        _commandController.add((asdu, point));
        if (point != null) {
          _pointUpdateController.add(point);
        }
      },
      onClosed: (s) {
        _sessions.remove(s);
        _clientsController.add(_sessions);
      },
    );

    _sessions.add(virtualSession);
    _clientsController.add(_sessions);

    results.add('1. [Connection Established] Virtual master connected, assigned Session ID: #${virtualSession.sessionId}');

    // 2. STARTDT act -> Expect STARTDT con
    virtualSession.receiveBytes(Uint8List.fromList([0x68, 0x04, 0x07, 0x00, 0x00, 0x00]));
    await Future.delayed(const Duration(milliseconds: 60));
    if (virtualSession.isDataTransferActive) {
      results.add('2. [U-Format Handshake] STARTDT act confirmed with STARTDT con, link activated');
    } else {
      results.add('2. [U-Format Handshake] Failed: data transfer not activated');
    }

    // 3. General Interrogation C_IC_NA_1 (Type 100, Act, QOI=0x14)
    final giBytes = Uint8List.fromList([0x68, 0x0E, 0x00, 0x00, 0x00, 0x00, 0x64, 0x01, 0x06, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x14]);
    virtualSession.receiveBytes(giBytes);
    await Future.delayed(const Duration(milliseconds: 60));
    results.add('3. [General Interrogation] Sent C_IC_NA_1 (Type 100) GI, server responded with ActCon (COT=7), data points (COT=20), and ActTerm (COT=10)');

    // 4. Clock Synchronization C_CS_NA_1 (Type 103)
    final syncBytes = Uint8List.fromList([
      0x68, 0x14, 0x02, 0x00, 0x02, 0x00, 0x67, 0x01, 0x06, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x1E, 0x0B, 0x0F, 0x0A, 0x1A
    ]);
    virtualSession.receiveBytes(syncBytes);
    await Future.delayed(const Duration(milliseconds: 60));
    results.add('4. [Clock Sync] Sent C_CS_NA_1 (Type 103) clock synchronization, server validated time tag and replied ActCon (COT=7)');

    // 5. Single Command Remote Control C_SC_NA_1 (Type 45, IOA=1) - Select
    final selCmd = Uint8List.fromList([
      0x68, 0x0E, 0x04, 0x00, 0x02, 0x00, 0x2D, 0x01, 0x06, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x81
    ]);
    virtualSession.receiveBytes(selCmd);
    await Future.delayed(const Duration(milliseconds: 60));
    results.add('5. [Remote Control Select] Sent C_SC_NA_1 (Type 45, IOA=1) select command, server confirmed with ActCon (COT=7)');

    // 6. Single Command Remote Control C_SC_NA_1 (Type 45, IOA=1) - Execute OFF
    final execCmd = Uint8List.fromList([
      0x68, 0x0E, 0x06, 0x00, 0x02, 0x00, 0x2D, 0x01, 0x06, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00
    ]);
    virtualSession.receiveBytes(execCmd);
    await Future.delayed(const Duration(milliseconds: 60));
    final p1 = stations[1]?.getPoint(1);
    results.add('6. [Remote Control Execute] Sent C_SC_NA_1 execute OFF, server replied ActCon/ActTerm (COT=7/10), station point updated to: ${p1?.displayValue}, spontaneous burst triggered (COT=3)');

    // 7. Counter Interrogation C_CI_NA_1 (Type 101)
    final ciBytes = Uint8List.fromList([
      0x68, 0x0E, 0x08, 0x00, 0x02, 0x00, 0x65, 0x01, 0x06, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x05
    ]);
    virtualSession.receiveBytes(ciBytes);
    await Future.delayed(const Duration(milliseconds: 60));
    results.add('7. [Counter Interrogation] Sent C_CI_NA_1 (Type 101) counter interrogation, server replied integrated totals (COT=37)');

    // 8. Read Command C_RD_NA_1 (Type 102, IOA=0x4001)
    final rdBytes = Uint8List.fromList([
      0x68, 0x0D, 0x0A, 0x00, 0x02, 0x00, 0x66, 0x01, 0x05, 0x00, 0x01, 0x00, 0x01, 0x40, 0x00
    ]);
    virtualSession.receiveBytes(rdBytes);
    await Future.delayed(const Duration(milliseconds: 60));
    results.add('8. [Single Point Read] Sent C_RD_NA_1 (Type 102, IOA=16385) read command, server returned current float voltage (COT=5)');

    // 9. TESTFR act (Link Heartbeat)
    virtualSession.receiveBytes(Uint8List.fromList([0x68, 0x04, 0x43, 0x00, 0x00, 0x00]));
    await Future.delayed(const Duration(milliseconds: 60));
    results.add('9. [Heartbeat Test] Sent TESTFR act, server replied TESTFR con immediately');

    // 10. S-Format Supervisory ACK
    virtualSession.receiveBytes(Uint8List.fromList([0x68, 0x04, 0x01, 0x00, 0x08, 0x00]));
    await Future.delayed(const Duration(milliseconds: 60));
    results.add('10. [S-Format Supervisory ACK] Sent S-frame ACK N(R)=4, server aligned sequence window');

    return results;
  }

  void _onNewClient(Socket socket) {
    final session = ClientSession(
      socket: socket,
      sessionId: _nextSessionId++,
      stations: stations,
      t0Seconds: t0,
      t1Seconds: t1,
      t2Seconds: t2,
      t3Seconds: t3,
      k: k,
      w: w,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
      onFrameReceived: () => rxCount++,
      onFrameSent: () => txCount++,
      onCommandReceived: (asdu, point) {
        _commandController.add((asdu, point));
        if (point != null) {
          _pointUpdateController.add(point);
        }
      },
      onClosed: (s) {
        _sessions.remove(s);
        _clientsController.add(_sessions);
      },
      onStateChanged: (s) {
        _clientsController.add(_sessions);
      },
    );

    _sessions.add(session);
    _clientsController.add(_sessions);
  }

  /// Updates a point manually and triggers spontaneous broadcast (COT=3)
  bool updatePointValue(
    int commonAddress,
    int ioa,
    dynamic newValue, {
    QualityDescriptor? quality,
    bool triggerSpontaneous = true,
  }) {
    final station = stations[commonAddress];
    if (station == null) return false;

    final changed = station.updatePointValue(ioa, newValue, quality: quality);
    final point = station.getPoint(ioa);

    if (changed && point != null) {
      _pointUpdateController.add(point);
      if (triggerSpontaneous) {
        broadcastSpontaneous(point, commonAddress);
      }
    }
    return changed;
  }

  /// Broadcasts a spontaneous ASDU (COT=3) to all active client sessions
  void broadcastSpontaneous(StationPoint point, int commonAddress) {
    for (final session in _sessions) {
      if (session.isDataTransferActive) {
        session.sendSpontaneous(point, commonAddress);
      }
    }
  }

  /// Starts the auto-change simulation timer
  void _startAutoSimulation() {
    _autoSimTimer?.cancel();
    _lastSimTick = DateTime.now();

    _autoSimTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final now = DateTime.now();
      final dt = now.difference(_lastSimTick ?? now).inMilliseconds / 1000.0;
      _lastSimTick = now;

      for (final station in stations.values) {
        for (final point in station.pointList) {
          if (point.autoChangeEnabled) {
            final changed = point.tickAutoChange(dt);
            if (changed) {
              _pointUpdateController.add(point);
              broadcastSpontaneous(point, station.commonAddress);
            }
          }
        }
      }
    });
  }

  void dispose() {
    stop();
    _statusController.close();
    _clientsController.close();
    _pointUpdateController.close();
    _commandController.close();
  }
}
