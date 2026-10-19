import 'dart:convert';
import 'dart:io';
import 'client_variable_model.dart';
import 'connection_config.dart';

class ClientWorkspaceData {
  final List<ConnectionConfig> connections;
  final List<ClientVariableModel> monitoredVariables;

  ClientWorkspaceData({
    required this.connections,
    required this.monitoredVariables,
  });
}

class ClientWorkspaceStorage {
  static const String _defaultDirName = 'iec61850_client';
  static const String _defaultFileName = 'workspace.json';

  static String get defaultStorageDirectory {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/$_defaultDirName';
  }

  static String get defaultFilePath => '$defaultStorageDirectory/$_defaultFileName';

  /// Loads workspace configuration
  static Future<ClientWorkspaceData> loadWorkspace() async {
    try {
      final file = File(defaultFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        if (json is Map<String, dynamic>) {
          final conns = <ConnectionConfig>[];
          if (json['Connections'] != null) {
            for (var c in (json['Connections'] as List)) {
              conns.add(ConnectionConfig.fromJson(Map<String, dynamic>.from(c)));
            }
          }
          if (conns.isEmpty) {
            conns.addAll(ConnectionConfig.createDefaultConnections());
          }
          final vars = <ClientVariableModel>[];
          if (json['MonitoredVariables'] != null) {
            for (var v in (json['MonitoredVariables'] as List)) {
              vars.add(ClientVariableModel.fromJson(Map<String, dynamic>.from(v)));
            }
          }
          return ClientWorkspaceData(connections: conns, monitoredVariables: vars);
        }
      }
    } catch (_) {}

    // Default connections
    return ClientWorkspaceData(
      connections: ConnectionConfig.createDefaultConnections(),
      monitoredVariables: [],
    );
  }

  /// Saves workspace configuration
  static Future<void> saveWorkspace(List<ConnectionConfig> connections, List<ClientVariableModel> monitoredVars) async {
    try {
      final dir = Directory(defaultStorageDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(defaultFilePath);
      final data = {
        'Connections': connections.map((c) => c.toJson()).toList(),
        'MonitoredVariables': monitoredVars.map((v) => v.toJson()).toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }
}
