import 'dart:convert';
import 'dart:io';
import 'connection_config.dart';

class WorkspaceStorage {
  static const String _defaultDirName = 'modbus_master';
  static const String _defaultFileName = 'workspace.json';

  static String get defaultStorageDirectory {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/$_defaultDirName';
  }

  static String get defaultFilePath {
    return '$defaultStorageDirectory/$_defaultFileName';
  }

  static String get mmeOriginalFilePath {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/MODBUS_MASTER_EMULATOR/workspace_v3.json';
  }

  /// Loads workspace connections, trying in priority:
  /// 1. Our app storage: ~/.local/share/modbus_master/workspace.json
  /// 2. Original MME storage: ~/.local/share/MODBUS_MASTER_EMULATOR/workspace_v3.json
  /// 3. Default preset with virtual slave and realistic registers
  static Future<List<ConnectionConfig>> loadConnections() async {
    try {
      final file = File(defaultFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content);
        if (list is List && list.isNotEmpty) {
          return list.map((e) => ConnectionConfig.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      }

      // Try fallback to MME
      final mmeFile = File(mmeOriginalFilePath);
      if (await mmeFile.exists()) {
        final content = await mmeFile.readAsString();
        final list = jsonDecode(content);
        if (list is List && list.isNotEmpty) {
          return list.map((e) => ConnectionConfig.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      }
    } catch (e) {
      // If error occurs, fallback to defaults
    }

    return [
      ConnectionConfig(
        name: '本地虚拟从站 (Virtual Test)',
        mode: ModbusTransportMode.virtual,
        ip: '127.0.0.1',
        port: 502,
        slaves: [ConnectionConfig.createDefaultSlave()],
      ),
      ConnectionConfig(
        name: 'Modbus RTU 串口通信 (Serial/COM)',
        mode: ModbusTransportMode.serialRtu,
        serialPortName: '/dev/ttyUSB0',
        baudRate: 9600,
        dataBits: 8,
        parity: 0,
        stopBits: 1,
        messageFrameFormat: 1,
        slaves: [ConnectionConfig.createDefaultSlave()],
      ),
      ConnectionConfig(
        name: 'Modbus TCP 默认连接',
        mode: ModbusTransportMode.tcp,
        ip: '127.0.0.1',
        port: 502,
        slaves: [ConnectionConfig.createDefaultSlave()],
      ),
    ];
  }

  /// Saves connection list to default storage file
  static Future<void> saveConnections(List<ConnectionConfig> configs) async {
    try {
      final dir = Directory(defaultStorageDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(defaultFilePath);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(
        configs.map((c) => c.toJson()).toList(),
      );
      await file.writeAsString(jsonStr);
    } catch (e) {
      // ignore or log
    }
  }

  /// Import from custom file path
  static Future<List<ConnectionConfig>> importFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) throw Exception('文件不存在: $path');
    final content = await file.readAsString();
    final list = jsonDecode(content);
    if (list is List) {
      return list.map((e) => ConnectionConfig.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception('文件格式错误: 顶层必须为数组');
  }

  /// Export to custom file path
  static Future<void> exportToFile(String path, List<ConnectionConfig> configs) async {
    final file = File(path);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(
      configs.map((c) => c.toJson()).toList(),
    );
    await file.writeAsString(jsonStr);
  }
}
