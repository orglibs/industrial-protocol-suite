import 'dart:convert';
import 'dart:io';

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

  /// Saves server workspace dictionary to persistent file atomically
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

  /// Loads server workspace dictionary from persistent file
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
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
