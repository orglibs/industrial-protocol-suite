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

  /// Loads workspace configuration
  static Future<WorkspaceData> loadWorkspace() async {
    try {
      final file = File(defaultFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        if (json is Map<String, dynamic>) {
          final config = ServerConfig.fromJson(Map<String, dynamic>.from(json['Config'] ?? {}));
          final vars = <ServerVariableModel>[];
          if (json['MonitoredVariables'] != null) {
            for (var v in (json['MonitoredVariables'] as List)) {
              vars.add(ServerVariableModel.fromJson(Map<String, dynamic>.from(v)));
            }
          }
          return WorkspaceData(config: config, monitoredVariables: vars);
        }
      }
    } catch (_) {}

    // Fallback default
    final defaultIcd = _findDefaultIcdPath();
    final config = ServerConfig(
      name: 'IEC 61850 MMS 默认服务 (Port 102)',
      ip: '0.0.0.0',
      port: 102,
      sclFilePath: defaultIcd,
    );
    return WorkspaceData(config: config, monitoredVariables: []);
  }

  static String? _findDefaultIcdPath() {
    final candidatePaths = [
      'assets/examples/server_example_basic_io.icd',
      '../iec61850_server/assets/examples/server_example_basic_io.icd',
      '/home/douqi/workspaces/nixiangwork/iec104serversimulator/iec61850_server/assets/examples/server_example_basic_io.icd',
      '/home/douqi/Downloads/IEC61850ServerSimulator-2.2.0.2-linux-x64/examples/server_example_basic_io.icd',
    ];
    for (final p in candidatePaths) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  /// Saves workspace configuration
  static Future<void> saveWorkspace(ServerConfig config, List<ServerVariableModel> monitoredVars) async {
    try {
      final dir = Directory(defaultStorageDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(defaultFilePath);
      final data = {
        'Config': config.toJson(),
        'MonitoredVariables': monitoredVars.map((v) => v.toJson()).toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }
}
