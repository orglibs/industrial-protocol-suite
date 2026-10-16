import 'dart:convert';
import 'dart:io';
import 'connection_config.dart';

class WorkspaceStorage {
  static const String _defaultDirName = 'modbus_slave';
  static const String _defaultFileName = 'workspace.json';

  static String get defaultStorageDirectory {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/$_defaultDirName';
  }

  static String get defaultFilePath {
    return '$defaultStorageDirectory/$_defaultFileName';
  }

  static String get mseOriginalFilePath {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.local/share/MODBUS_SLAVE_EMULATOR/workspace.json';
  }

  /// Loads workspace connections, trying in priority:
  /// 1. Our app storage: ~/.local/share/modbus_slave/workspace.json
  /// 2. Original MSE storage: ~/.local/share/MODBUS_SLAVE_EMULATOR/workspace.json
  /// 3. Default preset with realistic slaves and registers
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

      // Fallback check MSE original
      final mseFile = File(mseOriginalFilePath);
      if (await mseFile.exists()) {
        final content = await mseFile.readAsString();
        final list = jsonDecode(content);
        if (list is List && list.isNotEmpty) {
          return list.map((e) => ConnectionConfig.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      }
    } catch (_) {
      // Fallback on error
    }

    return [
      ConnectionConfig(
        name: 'Modbus TCP 默认从站服务 (Port 502)',
        mode: ModbusTransportMode.tcp,
        ip: '0.0.0.0',
        port: 502,
        slaves: [ConnectionConfig.createDefaultSlave(1, '配电站主变从站 (Unit 1)')],
      ),
      ConnectionConfig(
        name: 'Modbus RTU 串口从站服务 (/dev/ttyUSB0)',
        mode: ModbusTransportMode.serialRtu,
        serialPortName: '/dev/ttyUSB0',
        baudRate: 9600,
        dataBits: 8,
        parity: 0,
        stopBits: 1,
        messageFrameFormat: 1,
        slaves: [ConnectionConfig.createDefaultSlave(2, '串口采集从站 (Unit 2)')],
      ),
      ConnectionConfig(
        name: 'Modbus RTU over TCP (Port 5020)',
        mode: ModbusTransportMode.rtuOverTcp,
        ip: '0.0.0.0',
        port: 5020,
        messageFrameFormat: 1,
        slaves: [ConnectionConfig.createDefaultSlave(3, '网关从站 (Unit 3)')],
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
    } catch (_) {
      // ignore
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
