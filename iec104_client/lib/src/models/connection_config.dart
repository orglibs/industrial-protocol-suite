import '../client/iec104_client.dart';
import '../client/station_data.dart';
import '../i18n/app_i18n.dart';

class Iec104ClientConnectionConfig {
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
  int originatorAddress;
  int defaultCa;
  bool autoStartDt;
  bool autoGeneralInterrogation;
  int generalInterrogationPeriod;
  int clockSyncPeriod;
  int counterInterrogationPeriod;
  List<ClientStationModel> stations;

  late final Iec104Client client;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;
  set statusMessage(String? val) {
    _statusMessage = val;
    notifyListeners();
  }

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  bool get isConnected =>
      client.state == ClientConnectionState.connected ||
      client.state == ClientConnectionState.active;

  bool get isActive => client.state == ClientConnectionState.active;

  Iec104ClientConnectionConfig({
    String? id,
    this.name = 'IEC 104 Client Connection',
    this.nameKey,
    this.host = '127.0.0.1',
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
    this.originatorAddress = 0,
    this.defaultCa = 1,
    this.autoStartDt = true,
    this.autoGeneralInterrogation = true,
    this.generalInterrogationPeriod = 0,
    this.clockSyncPeriod = 0,
    this.counterInterrogationPeriod = 0,
    List<ClientStationModel>? stations,
    Iec104Client? client,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        stations = stations ?? [] {
    this.client = client ?? Iec104Client();
    _initClient();
  }

  void _initClient() {
    syncConfigToClient();
    client.stateStream.listen((_) => notifyListeners());
    client.stationsStream.listen((_) => notifyListeners());
    client.pointUpdateStream.listen((_) => notifyListeners());
  }

  void syncConfigToClient() {
    client.host = host;
    client.port = port;
    client.t0 = t0;
    client.t1 = t1;
    client.t2 = t2;
    client.t3 = t3;
    client.k = k;
    client.w = w;
    client.cotSize = cotSize;
    client.caSize = caSize;
    client.ioaSize = ioaSize;
    client.originatorAddress = originatorAddress;
    client.defaultCa = defaultCa;
    client.autoStartDt = autoStartDt;
    client.autoGeneralInterrogation = autoGeneralInterrogation;
    client.generalInterrogationPeriod = generalInterrogationPeriod;
    client.clockSyncPeriod = clockSyncPeriod;
    client.counterInterrogationPeriod = counterInterrogationPeriod;

    if (stations.isNotEmpty) {
      client.stations.clear();
      for (final s in stations) {
        client.stations[s.commonAddress] = s;
        s.onDataChanged = () {
          notifyListeners();
          client.scheduleAutoSave();
        };
      }
    } else if (client.stations.isNotEmpty) {
      stations = client.stations.values.toList();
    }
  }

  void syncConfigFromClient() {
    host = client.host;
    port = client.port;
    t0 = client.t0;
    t1 = client.t1;
    t2 = client.t2;
    t3 = client.t3;
    k = client.k;
    w = client.w;
    cotSize = client.cotSize;
    caSize = client.caSize;
    ioaSize = client.ioaSize;
    originatorAddress = client.originatorAddress;
    defaultCa = client.defaultCa;
    autoStartDt = client.autoStartDt;
    autoGeneralInterrogation = client.autoGeneralInterrogation;
    generalInterrogationPeriod = client.generalInterrogationPeriod;
    clockSyncPeriod = client.clockSyncPeriod;
    counterInterrogationPeriod = client.counterInterrogationPeriod;
    stations = client.stations.values.toList();
  }

  ClientStationModel? findStation(int ca) {
    for (final s in stations) {
      if (s.commonAddress == ca) return s;
    }
    return null;
  }

  void addStation(ClientStationModel station) {
    stations.removeWhere((s) => s.commonAddress == station.commonAddress);
    stations.add(station);
    station.onDataChanged = () {
      notifyListeners();
      client.scheduleAutoSave();
    };
    client.stations[station.commonAddress] = station;
    notifyListeners();
  }

  bool removeStation(int ca) {
    if (stations.length <= 1) return false;
    stations.removeWhere((s) => s.commonAddress == ca);
    client.stations.remove(ca);
    notifyListeners();
    return true;
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
        'originatorAddress': originatorAddress,
        'defaultCa': defaultCa,
        'autoStartDt': autoStartDt,
        'autoGeneralInterrogation': autoGeneralInterrogation,
        'generalInterrogationPeriod': generalInterrogationPeriod,
        'clockSyncPeriod': clockSyncPeriod,
        'counterInterrogationPeriod': counterInterrogationPeriod,
        'stations': stations.map((s) => s.toJson()).toList(),
      };

  factory Iec104ClientConnectionConfig.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'IEC 104 Client Connection';
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

    final config = Iec104ClientConnectionConfig(
      id: json['id'] as String?,
      name: name,
      nameKey: nameKey,
      host: json['host'] as String? ?? '127.0.0.1',
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
      originatorAddress: json['originatorAddress'] as int? ?? 0,
      defaultCa: json['defaultCa'] as int? ?? 1,
      autoStartDt: json['autoStartDt'] as bool? ?? true,
      autoGeneralInterrogation: json['autoGeneralInterrogation'] as bool? ?? true,
      generalInterrogationPeriod: json['generalInterrogationPeriod'] as int? ?? 0,
      clockSyncPeriod: json['clockSyncPeriod'] as int? ?? 0,
      counterInterrogationPeriod: json['counterInterrogationPeriod'] as int? ?? 0,
    );

    if (json['stations'] is List) {
      for (final sJson in json['stations']) {
        if (sJson is Map<String, dynamic>) {
          final ca = sJson['commonAddress'] as int? ?? 1;
          final s = ClientStationModel(
            commonAddress: ca,
            name: sJson['name'] as String? ?? 'Station #$ca',
            nameKey: sJson['nameKey'] as String?,
          );
          s.loadFromJson(sJson);
          config.stations.add(s);
        }
      }
    }

    if (config.stations.isEmpty) {
      final s = ClientStationModel(
        commonAddress: 1,
        name: 'Station #1 (Default Substation)',
        nameKey: 'preset_station_110kv',
      );
      s.applyTemplate('distribution');
      config.stations.add(s);
    }

    config._initClient();
    return config;
  }

  static List<Iec104ClientConnectionConfig> createDefaultConnections() {
    // 1. Connection 1: Port 2404, CA=1 & CA=2
    final st1 = ClientStationModel(
      commonAddress: 1,
      name: '110kV Substation #1',
      nameKey: 'preset_station_110kv',
    )..applyTemplate('distribution');

    final st2 = ClientStationModel(
      commonAddress: 2,
      name: '10kV Distribution Station #2',
      nameKey: 'preset_station_10kv',
    )..applyTemplate('distribution');

    final conn1 = Iec104ClientConnectionConfig(
      id: 'client-conn-1',
      name: 'IEC 104 TCP Default Server (Port 2404)',
      nameKey: 'preset_conn_iec104_default',
      host: '127.0.0.1',
      port: 2404,
      defaultCa: 1,
      stations: [st1, st2],
    );

    // 2. Connection 2: Port 2405, CA=3
    final st3 = ClientStationModel(
      commonAddress: 3,
      name: '35kV Solar Farm Station #3',
      nameKey: 'preset_station_solar',
    )..applyTemplate('substation');

    final conn2 = Iec104ClientConnectionConfig(
      id: 'client-conn-2',
      name: 'IEC 104 Standby Dispatch Server (Port 2405)',
      nameKey: 'preset_conn_iec104_backup',
      host: '127.0.0.1',
      port: 2405,
      defaultCa: 3,
      stations: [st3],
    );

    // 3. Connection 3: Port 2406, CA=4
    final st4 = ClientStationModel(
      commonAddress: 4,
      name: 'Smart Energy Storage BMS #4',
      nameKey: 'preset_station_bms',
    )..applyTemplate('distribution');

    final conn3 = Iec104ClientConnectionConfig(
      id: 'client-conn-3',
      name: 'IEC 104 Ring Network Test Server (Port 2406)',
      nameKey: 'preset_conn_iec104_ring',
      host: '127.0.0.1',
      port: 2406,
      defaultCa: 4,
      stations: [st4],
    );

    return [conn1, conn2, conn3];
  }
}
