import 'dart:io';

class ServerConfig {
  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  String name;
  String ip;
  int port;
  String? sclFilePath;
  String fileTransferDirectory;
  String? localNetworkCard;

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
    this.name = 'IEC 61850 MMS Server',
    this.ip = '0.0.0.0',
    this.port = 102,
    this.sclFilePath,
    String? fileTransferDirectory,
    this.localNetworkCard,
  }) : fileTransferDirectory = fileTransferDirectory ?? _defaultFileDir();

  static String _defaultFileDir() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/iec61850_server/files';
  }

  void notifyUpdated() {
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'Name': name,
    'Ip': ip,
    'Port': port,
    'SclFilePath': sclFilePath,
    'FileTransferDirectory': fileTransferDirectory,
    'LocalNetworkCard': localNetworkCard,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      name: json['Name'] as String? ?? 'IEC 61850 MMS Server',
      ip: json['Ip'] as String? ?? '0.0.0.0',
      port: json['Port'] as int? ?? 102,
      sclFilePath: json['SclFilePath'] as String?,
      fileTransferDirectory: json['FileTransferDirectory'] as String?,
      localNetworkCard: json['LocalNetworkCard'] as String?,
    );
  }
}
