import 'dart:convert';
import 'dart:io';
import '../models/connection_config.dart';
import 'station.dart';

const bool kIsWeb = identical(0, 0.0);

class WorkspaceStorage {
  static String? _cachedPath;

  /// Returns the absolute path where the server workspace file is stored
  static String getWorkspaceFilePath() {
    if (_cachedPath != null) return _cachedPath!;
    if (kIsWeb) {
      _cachedPath = 'localStorage:iec104_server_workspace';
      return _cachedPath!;
    }

    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['APPDATA'];

      if (home != null && home.isNotEmpty) {
        final baseDir = Platform.isWindows
            ? '$home\\iec104_flutter_server'
            : '$home/.local/share/iec104_flutter_server';
        final dir = Directory(baseDir);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _cachedPath = Platform.isWindows ? '$baseDir\\workspace.json' : '$baseDir/workspace.json';
        return _cachedPath!;
      }
    } catch (_) {}

    _cachedPath = 'server_workspace.json';
    return _cachedPath!;
  }

  /// Loads workspace connections list, supporting both list format and legacy single-server format
  static Future<List<Iec104ConnectionConfig>> loadConnections() async {
    if (kIsWeb) {
      return Iec104ConnectionConfig.createDefaultConnections();
    }
    try {
      final path = getWorkspaceFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List && decoded.isNotEmpty) {
            return decoded
                .map((e) => Iec104ConnectionConfig.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          } else if (decoded is Map<String, dynamic>) {
            // Legacy single server format migration
            final config = Iec104ConnectionConfig(
              name: 'IEC 104 TCP Default Server (Port 2404)',
              nameKey: 'preset_conn_iec104_default',
            );
            if (decoded['connection'] is Map<String, dynamic>) {
              final conn = decoded['connection'] as Map<String, dynamic>;
              config.host = conn['host'] as String? ?? config.host;
              config.port = conn['port'] as int? ?? config.port;
              config.t0 = conn['t0'] as int? ?? config.t0;
              config.t1 = conn['t1'] as int? ?? config.t1;
              config.t2 = conn['t2'] as int? ?? config.t2;
              config.t3 = conn['t3'] as int? ?? config.t3;
              config.k = conn['k'] as int? ?? config.k;
              config.w = conn['w'] as int? ?? config.w;
            }
            if (decoded['stations'] is List) {
              config.stations.clear();
              for (final s in decoded['stations']) {
                if (s is Map<String, dynamic>) {
                  config.stations.add(Station.fromJson(s));
                }
              }
            }
            config.syncConfigToServer();
            return [config];
          }
        }
      }
    } catch (_) {}

    return Iec104ConnectionConfig.createDefaultConnections();
  }

  /// Saves connection list to persistent storage atomically
  static Future<bool> saveConnections(List<Iec104ConnectionConfig> configs) async {
    if (kIsWeb) return false;
    try {
      final path = getWorkspaceFilePath();
      final tempFile = File('$path.tmp');
      final jsonStr = const JsonEncoder.withIndent('  ').convert(
        configs.map((c) => c.toJson()).toList(),
      );
      await tempFile.writeAsString(jsonStr, flush: true);
      await tempFile.rename(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves server workspace dictionary to persistent file atomically (backward compatibility)
  static Future<bool> save(Map<String, dynamic> data) async {
    if (kIsWeb) return false;
    try {
      final path = getWorkspaceFilePath();
      final tempFile = File('$path.tmp');
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await tempFile.writeAsString(jsonStr, flush: true);
      await tempFile.rename(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Loads server workspace dictionary from persistent file (backward compatibility)
  static Future<Map<String, dynamic>?> load() async {
    if (kIsWeb) return null;
    try {
      final path = getWorkspaceFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          } else if (decoded is List && decoded.isNotEmpty) {
            final first = decoded.first as Map<String, dynamic>;
            return {
              'connection': first,
              'stations': first['stations'] ?? [],
            };
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
