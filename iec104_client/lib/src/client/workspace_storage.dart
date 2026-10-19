import 'dart:convert';
import 'dart:io';
import '../models/connection_config.dart';
import 'station_data.dart';

const bool kIsWeb = identical(0, 0.0);

class WorkspaceStorage {
  static String? _cachedPath;

  static String get defaultFilePath => getWorkspaceFilePath();

  /// Returns the absolute path where the workspace file is stored
  static String getWorkspaceFilePath() {
    if (_cachedPath != null) return _cachedPath!;
    if (kIsWeb) {
      _cachedPath = 'localStorage:iec104_workspace';
      return _cachedPath!;
    }

    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['APPDATA'];

      if (home != null && home.isNotEmpty) {
        final baseDir = Platform.isWindows
            ? '$home\\iec104_flutter_client'
            : '$home/.local/share/iec104_flutter_client';
        final dir = Directory(baseDir);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _cachedPath = Platform.isWindows ? '$baseDir\\workspace.json' : '$baseDir/workspace.json';
        return _cachedPath!;
      }
    } catch (_) {}

    _cachedPath = 'workspace.json';
    return _cachedPath!;
  }

  /// Loads workspace connections list, supporting both list format and legacy single-client format
  static Future<List<Iec104ClientConnectionConfig>> loadConnections() async {
    if (kIsWeb) {
      return Iec104ClientConnectionConfig.createDefaultConnections();
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
                .map((e) => Iec104ClientConnectionConfig.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          } else if (decoded is Map<String, dynamic>) {
            // Legacy single client format migration
            final config = Iec104ClientConnectionConfig(
              name: 'IEC 104 TCP Default Server (Port 2404)',
              nameKey: 'preset_conn_iec104_default',
            );
            if (decoded['connection'] is Map<String, dynamic>) {
              final conn = decoded['connection'] as Map<String, dynamic>;
              config.host = conn['host'] as String? ?? config.host;
              config.port = conn['port'] as int? ?? config.port;
              config.k = conn['k'] as int? ?? config.k;
              config.w = conn['w'] as int? ?? config.w;
              config.t0 = conn['t0'] as int? ?? config.t0;
              config.t1 = conn['t1'] as int? ?? config.t1;
              config.t2 = conn['t2'] as int? ?? config.t2;
              config.t3 = conn['t3'] as int? ?? config.t3;
              config.cotSize = conn['cotSize'] as int? ?? config.cotSize;
              config.caSize = conn['caSize'] as int? ?? config.caSize;
              config.ioaSize = conn['ioaSize'] as int? ?? config.ioaSize;
              config.originatorAddress = conn['originatorAddress'] as int? ?? config.originatorAddress;
              config.defaultCa = conn['defaultCa'] as int? ?? config.defaultCa;
              config.autoStartDt = conn['autoStartDt'] as bool? ?? config.autoStartDt;
              config.autoGeneralInterrogation = conn['autoGeneralInterrogation'] as bool? ?? config.autoGeneralInterrogation;
              config.generalInterrogationPeriod = conn['generalInterrogationPeriod'] as int? ?? config.generalInterrogationPeriod;
              config.clockSyncPeriod = conn['clockSyncPeriod'] as int? ?? config.clockSyncPeriod;
              config.counterInterrogationPeriod = conn['counterInterrogationPeriod'] as int? ?? config.counterInterrogationPeriod;
            }
            if (decoded['stations'] is List) {
              config.stations.clear();
              for (final s in decoded['stations']) {
                if (s is Map<String, dynamic>) {
                  final ca = s['commonAddress'] as int? ?? 1;
                  final st = ClientStationModel(
                    commonAddress: ca,
                    name: s['name'] as String? ?? 'Station #$ca',
                    nameKey: s['nameKey'] as String?,
                  );
                  st.loadFromJson(s);
                  config.stations.add(st);
                }
              }
            }
            config.syncConfigToClient();
            return [config];
          }
        }
      }
    } catch (_) {}

    return Iec104ClientConnectionConfig.createDefaultConnections();
  }

  /// Saves connection list to persistent storage atomically
  static Future<bool> saveConnections(List<Iec104ClientConnectionConfig> configs) async {
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

  /// Saves workspace dictionary to persistent file atomically (backward compatibility)
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

  /// Loads workspace dictionary from persistent file (backward compatibility)
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
