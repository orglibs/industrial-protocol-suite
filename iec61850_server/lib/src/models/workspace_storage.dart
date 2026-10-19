import 'dart:convert';
import 'dart:io';
import 'server_config.dart';
import 'server_variable_model.dart';

class WorkspaceData {
  final ServerConfig config;
  final List<ServerVariableModel> monitoredVariables;

  WorkspaceData({
    required this.config,
    required this.monitoredVariables,
  });
}

class WorkspaceStorage {
  static const String _defaultDirName = 'iec61850_server';
  static const String _defaultFileName = 'workspace.json';

  static String get defaultStorageDirectory {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/$_defaultDirName';
  }

  static String get defaultFilePath => '$defaultStorageDirectory/$_defaultFileName';

  /// Loads all connections from workspace storage
  static Future<List<ServerConfig>> loadConnections() async {
    try {
      final file = File(defaultFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        if (json is Map<String, dynamic>) {
          if (json['Connections'] is List) {
            final list = <ServerConfig>[];
            for (final c in (json['Connections'] as List)) {
              if (c is Map<String, dynamic>) {
                list.add(ServerConfig.fromJson(c));
              }
            }
            if (list.isNotEmpty) return list;
          }
          if (json['Config'] != null) {
            final single = ServerConfig.fromJson(Map<String, dynamic>.from(json['Config']));
            return [single];
          }
        }
      }
    } catch (_) {}

    return ServerConfig.createDefaultConnections();
  }

  /// Saves all connections to workspace storage
  static Future<void> saveConnections(List<ServerConfig> connections) async {
    try {
      final dir = Directory(defaultStorageDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(defaultFilePath);
      final data = {
        'Version': 2,
        'Connections': connections.map((c) => c.toJson()).toList(),
        'Config': connections.isNotEmpty ? connections.first.toJson() : null,
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }

  /// Loads workspace configuration (single-connection legacy compatibility)
  static Future<WorkspaceData> loadWorkspace() async {
    final conns = await loadConnections();
    final first = conns.isNotEmpty ? conns.first : ServerConfig.createDefaultConnections().first;
    return WorkspaceData(config: first, monitoredVariables: []);
  }

  /// Saves workspace configuration (single-connection legacy compatibility)
  static Future<void> saveWorkspace(ServerConfig config, List<ServerVariableModel> monitoredVars) async {
    await saveConnections([config]);
  }
}
