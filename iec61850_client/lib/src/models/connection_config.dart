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
    this.name = 'IEC 61850 Server 连接',
    this.ip = '127.0.0.1',
    this.port = 102,
    this.localTsap = 0x0001,
    this.remoteTsap = 0x0001,
    this.boundSclPath,
    this.autoConnect = false,
    this.pollIntervalMs = 1000,
  });

  void notifyUpdated() {
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'Ip': ip,
    'Port': port,
    'LocalTsap': localTsap,
    'RemoteTsap': remoteTsap,
    'BoundSclPath': boundSclPath,
    'AutoConnect': autoConnect,
    'PollIntervalMs': pollIntervalMs,
  };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      id: json['Id'] as String? ?? 'conn_${DateTime.now().millisecondsSinceEpoch}',
      name: json['Name'] as String? ?? 'IEC 61850 Server 连接',
      ip: json['Ip'] as String? ?? '127.0.0.1',
      port: json['Port'] as int? ?? 102,
      localTsap: json['LocalTsap'] as int? ?? 0x0001,
      remoteTsap: json['RemoteTsap'] as int? ?? 0x0001,
      boundSclPath: json['BoundSclPath'] as String?,
      autoConnect: json['AutoConnect'] as bool? ?? false,
      pollIntervalMs: json['PollIntervalMs'] as int? ?? 1000,
    );
  }
}
