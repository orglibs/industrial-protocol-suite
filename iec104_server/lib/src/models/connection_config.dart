import '../i18n/app_i18n.dart';
import '../server/iec104_server.dart';
import '../server/station.dart';

class Iec104ConnectionConfig {
  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  String id;
  String name;
  String? nameKey;
  String host;
  int port;
  int t0;
  int t1;
  int t2;
  int t3;
  int k;
  int w;
  int cotSize;
  int caSize;
  int ioaSize;
  List<Station> stations;

  late final Iec104Server server;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;
  set statusMessage(String? val) {
    _statusMessage = val;
    notifyListeners();
  }

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  bool get isRunning => server.isRunning;
  int get clientCount => server.clients.length;
  int get rxCount => server.rxCount;
  int get txCount => server.txCount;

  Iec104ConnectionConfig({
    String? id,
    this.name = 'IEC 104 Server Connection',
    this.nameKey,
    this.host = '0.0.0.0',
    this.port = 2404,
    this.t0 = 30,
    this.t1 = 15,
    this.t2 = 10,
    this.t3 = 20,
    this.k = 12,
    this.w = 8,
    this.cotSize = 2,
    this.caSize = 2,
    this.ioaSize = 3,
    List<Station>? stations,
    Iec104Server? server,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        stations = stations ?? [] {
    this.server = server ?? Iec104Server();
    _initServer();
  }

  void _initServer() {
    server.host = host;
    server.port = port;
    server.t0 = t0;
    server.t1 = t1;
    server.t2 = t2;
    server.t3 = t3;
    server.k = k;
    server.w = w;
    server.cotSize = cotSize;
    server.caSize = caSize;
    server.ioaSize = ioaSize;

    server.stations.clear();
    for (final s in stations) {
      server.stations[s.commonAddress] = s;
      s.onDataChanged = notifyListeners;
    }

    server.statusStream.listen((_) => notifyListeners());
    server.clientsStream.listen((_) => notifyListeners());
    server.pointUpdateStream.listen((_) => notifyListeners());
    server.stationsStream.listen((_) => notifyListeners());
  }

  void syncConfigToServer() {
    server.host = host;
    server.port = port;
    server.t0 = t0;
    server.t1 = t1;
    server.t2 = t2;
    server.t3 = t3;
    server.k = k;
    server.w = w;
    server.cotSize = cotSize;
    server.caSize = caSize;
    server.ioaSize = ioaSize;

    server.stations.clear();
    for (final s in stations) {
      server.stations[s.commonAddress] = s;
      s.onDataChanged = notifyListeners;
    }
  }

  Station? findStation(int ca) {
    for (final s in stations) {
      if (s.commonAddress == ca) return s;
    }
    return null;
  }

  void addStation(Station station) {
    stations.removeWhere((s) => s.commonAddress == station.commonAddress);
    stations.add(station);
    station.onDataChanged = notifyListeners;
    server.stations[station.commonAddress] = station;
    notifyListeners();
  }

  bool removeStation(int ca) {
    if (stations.length <= 1) return false;
    stations.removeWhere((s) => s.commonAddress == ca);
    server.stations.remove(ca);
    notifyListeners();
    return true;
  }

  void updateStation(int oldCa, int newCa, String newName, [String? newNameKey]) {
    final st = findStation(oldCa);
    if (st == null) return;
    st.name = newName;
    if (newNameKey != null) st.nameKey = newNameKey;
    if (oldCa != newCa) {
      st.commonAddress = newCa;
      server.stations.remove(oldCa);
      server.stations[newCa] = st;
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameKey': nameKey,
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
        'stations': stations.map((s) => s.toJson()).toList(),
      };

  factory Iec104ConnectionConfig.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'IEC 104 Server Connection';
    final port = json['port'] as int? ?? 2404;
    String? nameKey = json['nameKey'] as String?;
    if (nameKey == null) {
      if (port == 2404) {
        nameKey = 'preset_conn_iec104_default';
      } else if (port == 2405) {
        nameKey = 'preset_conn_iec104_backup';
      } else if (port == 2406) {
        nameKey = 'preset_conn_iec104_ring';
      }
    }

    final config = Iec104ConnectionConfig(
      id: json['id'] as String?,
      name: name,
      nameKey: nameKey,
      host: json['host'] as String? ?? '0.0.0.0',
      port: port,
      t0: json['t0'] as int? ?? 30,
      t1: json['t1'] as int? ?? 15,
      t2: json['t2'] as int? ?? 10,
      t3: json['t3'] as int? ?? 20,
      k: json['k'] as int? ?? 12,
      w: json['w'] as int? ?? 8,
      cotSize: json['cotSize'] as int? ?? 2,
      caSize: json['caSize'] as int? ?? 2,
      ioaSize: json['ioaSize'] as int? ?? 3,
    );

    if (json['stations'] is List) {
      for (final sJson in json['stations']) {
        if (sJson is Map<String, dynamic>) {
          config.stations.add(Station.fromJson(sJson));
        }
      }
    }

    if (config.stations.isEmpty) {
      config.stations.add(Station.createDefault(commonAddress: 1));
    }

    config._initServer();
    return config;
  }

  static List<Iec104ConnectionConfig> createDefaultConnections() {
    return [
      Iec104ConnectionConfig(
        id: 'conn-1',
        name: 'IEC 104 TCP Default Server (Port 2404)',
        nameKey: 'preset_conn_iec104_default',
        host: '0.0.0.0',
        port: 2404,
        stations: [
          Station.createDefault(commonAddress: 1, name: '110kV Substation #1', nameKey: 'preset_station_110kv'),
          Station.createDistributionStation(commonAddress: 2, name: '10kV Distribution Station #2', nameKey: 'preset_station_10kv'),
        ],
      ),
      Iec104ConnectionConfig(
        id: 'conn-2',
        name: 'IEC 104 Backup Dispatch Server (Port 2405)',
        nameKey: 'preset_conn_iec104_backup',
        host: '0.0.0.0',
        port: 2405,
        stations: [
          Station.createSolarStation(commonAddress: 3, name: '35kV Solar Farm Station #3', nameKey: 'preset_station_solar'),
        ],
      ),
      Iec104ConnectionConfig(
        id: 'conn-3',
        name: 'IEC 104 Ring Test Server (Port 2406)',
        nameKey: 'preset_conn_iec104_ring',
        host: '0.0.0.0',
        port: 2406,
        stations: [
          Station.createStorageStation(commonAddress: 4, name: 'Smart Energy Storage BMS #4', nameKey: 'preset_station_bms'),
        ],
      ),
    ];
  }
}

class Iec104ServerManager {
  static final Iec104ServerManager instance = Iec104ServerManager._();
  Iec104ServerManager._();
  static List<Iec104ConnectionConfig> createDefaultPresets() =>
      Iec104ConnectionConfig.createDefaultConnections();

  bool isConnectionRunning(Iec104ConnectionConfig config) => config.isRunning;

  Future<void> startServer(Iec104ConnectionConfig config) async {
    config.syncConfigToServer();
    try {
      await config.server.start();
      config.statusMessage = 'Listening';
    } catch (e) {
      config.statusMessage = 'Start failed: $e';
      rethrow;
    } finally {
      config.notifyListeners();
    }
  }

  Future<void> stopServer(Iec104ConnectionConfig config) async {
    await config.server.stop();
    config.statusMessage = 'Stopped';
    config.notifyListeners();
  }

  Future<void> startAll(List<Iec104ConnectionConfig> configs) async {
    for (final c in configs) {
      try {
        await startServer(c);
      } catch (_) {}
    }
  }

  Future<void> stopAll(List<Iec104ConnectionConfig> configs) async {
    for (final c in configs) {
      try {
        await stopServer(c);
      } catch (_) {}
    }
  }
}
