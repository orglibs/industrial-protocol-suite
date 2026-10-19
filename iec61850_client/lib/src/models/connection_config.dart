import '../i18n/app_i18n.dart';

class ConnectionConfig {
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
  String get displayName {
    if (nameKey != null && nameKey!.isNotEmpty) {
      final translated = AppI18n.instance.t(nameKey!);
      if (translated != nameKey) return translated;
    }
    if (name.isNotEmpty && RegExp(r'[\u4e00-\u9fff]').hasMatch(name)) {
      final inferred = inferNameKeyFromName(name, id);
      if (inferred != null) {
        final translated = AppI18n.instance.t(inferred);
        if (translated != inferred) return translated;
      }
    }
    return name;
  }

  String ip;
  int port;
  int localTsap;
  int remoteTsap;
  String? boundSclPath;
  String? get sclFilePath => boundSclPath;
  set sclFilePath(String? val) => boundSclPath = val;
  bool autoConnect;
  int pollIntervalMs;

  // Runtime state
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  set isConnected(bool val) {
    if (_isConnected != val) {
      _isConnected = val;
      notifyListeners();
    }
  }

  String? _statusMessage;
  String? get statusMessage => _statusMessage;
  set statusMessage(String? val) {
    _statusMessage = val;
    notifyListeners();
  }

  int rxCount = 0;
  int txCount = 0;
  DateTime? lastConnectTime;
  DateTime? lastDisconnectTime;

  ConnectionConfig({
    required this.id,
    this.name = 'IEC 61850 Server Connection',
    this.nameKey,
    this.ip = '127.0.0.1',
    this.port = 102,
    this.localTsap = 0x0001,
    this.remoteTsap = 0x0001,
    this.boundSclPath,
    this.autoConnect = false,
    this.pollIntervalMs = 1000,
  });

  static List<ConnectionConfig> createDefaultConnections() {
    return [
      ConnectionConfig(
        id: 'conn_bay_controller',
        name: 'Substation Bay Controller (Basic I/O 102)',
        nameKey: 'preset_conn_basic_io',
        ip: '127.0.0.1',
        port: 102,
        localTsap: 0x0001,
        remoteTsap: 0x0001,
        boundSclPath: 'assets/examples/server_example_basic_io.icd',
        autoConnect: false,
        pollIntervalMs: 1000,
      ),
      ConnectionConfig(
        id: 'conn_transformer_ied',
        name: 'Main Transformer Protection IED (Control 10102)',
        nameKey: 'preset_conn_control',
        ip: '127.0.0.1',
        port: 10102,
        localTsap: 0x0001,
        remoteTsap: 0x0001,
        boundSclPath: 'assets/examples/server_example_control.icd',
        autoConnect: false,
        pollIntervalMs: 1000,
      ),
      ConnectionConfig(
        id: 'conn_goose_ied',
        name: 'Distribution Automation GOOSE IED (GOOSE 20102)',
        nameKey: 'preset_conn_goose',
        ip: '127.0.0.1',
        port: 20102,
        localTsap: 0x0001,
        remoteTsap: 0x0001,
        boundSclPath: 'assets/examples/server_example_goose.icd',
        autoConnect: false,
        pollIntervalMs: 1000,
      ),
    ];
  }

  ConnectionConfig copyWith({
    String? id,
    String? name,
    String? nameKey,
    String? ip,
    int? port,
    int? localTsap,
    int? remoteTsap,
    String? boundSclPath,
    bool? autoConnect,
    int? pollIntervalMs,
  }) {
    return ConnectionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      localTsap: localTsap ?? this.localTsap,
      remoteTsap: remoteTsap ?? this.remoteTsap,
      boundSclPath: boundSclPath ?? this.boundSclPath,
      autoConnect: autoConnect ?? this.autoConnect,
      pollIntervalMs: pollIntervalMs ?? this.pollIntervalMs,
    );
  }

  void notifyUpdated() {
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'NameKey': nameKey,
    'Ip': ip,
    'Port': port,
    'LocalTsap': localTsap,
    'RemoteTsap': remoteTsap,
    'BoundSclPath': boundSclPath,
    'AutoConnect': autoConnect,
    'PollIntervalMs': pollIntervalMs,
  };

  static String? inferNameKeyFromName(String name, [String? id]) {
    if (id == 'conn_default' ||
        name.contains('Local Test Server') ||
        name.contains('IEC 61850 Server Connection') ||
        name.contains('本地测试连接') ||
        name.contains('本地测试')) {
      return 'preset_iec61850_client_conn';
    }
    if (id == 'conn_bay_controller' ||
        name.contains('Basic I/O') ||
        name.contains('Bay Controller') ||
        name.contains('变电站间隔控制器') ||
        name.contains('间隔控制器') ||
        name.contains('间隔') ||
        name.contains('ベイコントローラ')) {
      return 'preset_conn_basic_io';
    }
    if (id == 'conn_transformer_ied' ||
        name.contains('Control') ||
        name.contains('Transformer') ||
        name.contains('10102') ||
        name.contains('主变测控保护终端') ||
        name.contains('主变') ||
        name.contains('主変圧器')) {
      return 'preset_conn_control';
    }
    if (id == 'conn_goose_ied' ||
        name.contains('GOOSE') ||
        name.contains('20102') ||
        name.contains('智能配网GOOSE终端') ||
        name.contains('智能配网') ||
        name.contains('配网')) {
      return 'preset_conn_goose';
    }
    return null;
  }

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    final id = (json['Id'] ?? json['id']) as String? ?? 'conn_${DateTime.now().millisecondsSinceEpoch}';
    final name = (json['Name'] ?? json['name']) as String? ?? 'IEC 61850 Server Connection';
    String? nameKey = (json['NameKey'] ?? json['nameKey']) as String?;

    if (nameKey == null || nameKey.isEmpty) {
      nameKey = inferNameKeyFromName(name, id);
    }

    return ConnectionConfig(
      id: id,
      name: name,
      nameKey: nameKey,
      ip: (json['Ip'] ?? json['ip']) as String? ?? '127.0.0.1',
      port: (json['Port'] ?? json['port']) as int? ?? 102,
      localTsap: (json['LocalTsap'] ?? json['localTsap']) as int? ?? 0x0001,
      remoteTsap: (json['RemoteTsap'] ?? json['remoteTsap']) as int? ?? 0x0001,
      boundSclPath: (json['BoundSclPath'] ?? json['boundSclPath']) as String?,
      autoConnect: (json['AutoConnect'] ?? json['autoConnect']) as bool? ?? false,
      pollIntervalMs: (json['PollIntervalMs'] ?? json['pollIntervalMs']) as int? ?? 1000,
    );
  }
}
