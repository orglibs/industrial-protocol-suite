import 'dart:io';
import '../i18n/app_i18n.dart';
import '../protocol/iec61850_server_manager.dart';

class ServerConfig {
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
  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  String ip;
  int port;
  String? sclFilePath;
  String fileTransferDirectory;
  String? localNetworkCard;

  Iec61850ServerManager? _manager;
  Iec61850ServerManager get manager {
    _manager ??= Iec61850ServerManager(config: this);
    return _manager!;
  }
  set manager(Iec61850ServerManager val) {
    _manager = val;
  }
  void attachManager(Iec61850ServerManager val) {
    _manager = val;
  }

  // Runtime status fields
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  set isRunning(bool val) {
    if (_isRunning != val) {
      _isRunning = val;
      notifyListeners();
    }
  }

  String? _statusMessage;
  String? get statusMessage => _statusMessage;
  set statusMessage(String? val) {
    _statusMessage = val;
    notifyListeners();
  }

  int clientCount = 0;
  int rxCount = 0;
  int txCount = 0;
  int activeReportsCount = 0;
  int activeGooseCount = 0;

  ServerConfig({
    String? id,
    this.name = 'IEC 61850 MMS Server',
    this.nameKey,
    this.ip = '0.0.0.0',
    this.port = 102,
    this.sclFilePath,
    String? fileTransferDirectory,
    this.localNetworkCard,
    Iec61850ServerManager? manager,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        fileTransferDirectory = fileTransferDirectory ?? _defaultFileDir() {
    if (manager != null) {
      _manager = manager;
    }
  }

  static String _defaultFileDir() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/iec61850_server/files';
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
    'SclFilePath': sclFilePath,
    'FileTransferDirectory': fileTransferDirectory,
    'LocalNetworkCard': localNetworkCard,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    final id = json['Id'] as String? ?? json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
    final name = json['Name'] as String? ?? json['name'] as String? ?? 'IEC 61850 MMS Server';
    String? nameKey = json['NameKey'] as String? ?? json['nameKey'] as String?;
    if (nameKey == null || nameKey.isEmpty) {
      if (name.contains('Control') || name.contains('10102') || name.contains('Switchgear') || name.contains('开关')) {
        nameKey = 'preset_iec61850_server_control';
      } else if (name.contains('Wind') || name.contains('10103') || name.contains('61400') || name.contains('风电')) {
        nameKey = 'preset_iec61850_server_wind';
      } else if (name == 'IEC 61850 MMS Default Server (Port 102)' || name == 'IEC 61850 MMS Server' || name.contains('IEC 61850 MMS') || name.contains('102') || name.contains('Default') || name.contains('默认')) {
        nameKey = 'preset_iec61850_server_default';
      }
    }

    return ServerConfig(
      id: id,
      name: name,
      nameKey: nameKey,
      ip: json['Ip'] as String? ?? json['ip'] as String? ?? '0.0.0.0',
      port: json['Port'] as int? ?? json['port'] as int? ?? 102,
      sclFilePath: json['SclFilePath'] as String? ?? json['sclFilePath'] as String?,
      fileTransferDirectory: json['FileTransferDirectory'] as String? ?? json['fileTransferDirectory'] as String?,
      localNetworkCard: json['LocalNetworkCard'] as String? ?? json['localNetworkCard'] as String?,
    );
  }

  static List<ServerConfig> createDefaultConnections() {
    return [
      ServerConfig(
        id: 'conn-default-102',
        name: 'IEC 61850 MMS Default Substation Server (Port 102)',
        nameKey: 'preset_iec61850_server_default',
        ip: '0.0.0.0',
        port: 102,
        sclFilePath: 'assets/examples/server_example_basic_io.icd',
      ),
      ServerConfig(
        id: 'conn-control-10102',
        name: 'IEC 61850 MMS Control & Switchgear Server (Port 10102)',
        nameKey: 'preset_iec61850_server_control',
        ip: '0.0.0.0',
        port: 10102,
        sclFilePath: 'assets/examples/server_example_control.icd',
      ),
      ServerConfig(
        id: 'conn-wind-10103',
        name: 'IEC 61850 MMS Wind Power & Settings Server (Port 10103)',
        nameKey: 'preset_iec61850_server_wind',
        ip: '0.0.0.0',
        port: 10103,
        sclFilePath: 'assets/examples/server_example_61400_25.icd',
      ),
    ];
  }
}
