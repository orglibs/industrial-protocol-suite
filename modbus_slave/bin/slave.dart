// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'package:modbus_slave/src/models/connection_config.dart';
import 'package:modbus_slave/src/models/workspace_storage.dart';
import 'package:modbus_slave/src/protocol/modbus_server.dart';
import 'package:modbus_slave/src/services/simulation_service.dart';
import 'package:modbus_slave/src/services/traffic_logger.dart';

void main(List<String> args) async {
  print('================================================================');
  print('      Modbus Slave Emulator (MSE) - CLI 服务端运行程序           ');
  print('================================================================\n');

  if (args.contains('-h') || args.contains('--help')) {
    print('用法: dart run bin/slave.dart [参数]');
    print('参数说明:');
    print('  -p, --port <端口>       监听 TCP 端口 (默认: 5020)');
    print('  -i, --ip <IP地址>       监听 IP (默认: 0.0.0.0)');
    print('  -m, --mode <tcp|rtu-tcp|serial>  通信模式 (默认: tcp)');
    print('  -s, --serial <串口路径> 串口设备 (如 /dev/ttyUSB0)');
    print('  -b, --baud <波特率>     串口波特率 (默认: 9600)');
    print('  --sim                  开启波形数据自动仿真 (正弦/三角波)');
    print('  -h, --help             查看帮助');
    exit(0);
  }

  int port = 5020;
  String ip = '0.0.0.0';
  ModbusTransportMode mode = ModbusTransportMode.tcp;
  String? serialPort;
  int baudRate = 9600;
  bool enableSim = false;

  for (int i = 0; i < args.length; i++) {
    if ((args[i] == '-p' || args[i] == '--port') && i + 1 < args.length) {
      port = int.tryParse(args[i + 1]) ?? 5020;
    } else if ((args[i] == '-i' || args[i] == '--ip') && i + 1 < args.length) {
      ip = args[i + 1];
    } else if ((args[i] == '-m' || args[i] == '--mode') && i + 1 < args.length) {
      final m = args[i + 1].toLowerCase();
      if (m == 'rtu-tcp') mode = ModbusTransportMode.rtuOverTcp;
      if (m == 'serial') mode = ModbusTransportMode.serialRtu;
    } else if ((args[i] == '-s' || args[i] == '--serial') && i + 1 < args.length) {
      serialPort = args[i + 1];
    } else if ((args[i] == '-b' || args[i] == '--baud') && i + 1 < args.length) {
      baudRate = int.tryParse(args[i + 1]) ?? 9600;
    } else if (args[i] == '--sim') {
      enableSim = true;
    }
  }

  // Load stored connections or create configured connection
  final connections = await WorkspaceStorage.loadConnections();
  ConnectionConfig config;
  if (connections.isNotEmpty) {
    config = connections.first;
    config.port = port;
    config.ip = ip;
    config.mode = mode;
    if (serialPort != null) config.serialPortName = serialPort;
    config.baudRate = baudRate;
  } else {
    config = ConnectionConfig(
      name: 'CLI Modbus 从站服务',
      mode: mode,
      ip: ip,
      port: port,
      serialPortName: serialPort,
      baudRate: baudRate,
      slaves: [ConnectionConfig.createDefaultSlave(1, '配电站从站 (ID 1)')],
    );
  }

  print('模式: ${config.mode.label}');
  if (config.mode == ModbusTransportMode.serialRtu) {
    print('串口设备: ${config.serialPortName ?? "/dev/ttyUSB0"} | 波特率: ${config.baudRate}');
  } else {
    print('网络监听: ${config.ip}:${config.port}');
  }
  print('包含从站:');
  for (final s in config.slaves) {
    print('  - [从站 ID: ${s.slaveId}] ${s.name} (组数: ${s.groups.length})');
    for (final g in s.groups) {
      print('      * ${g.groupName} [${g.registerType.label}]: 起始 ${g.startAddress}, 点数 ${g.quantity}');
    }
  }

  // Subscribe to traffic log
  TrafficLogger.instance.onNewEntry.listen((e) {
    final dir = e.direction == TrafficDirection.rx ? '\x1B[32m[RX]\x1B[0m' : '\x1B[34m[TX]\x1B[0m';
    print('${e.timeStr} $dir [ID:${e.unitId}] FC:0x${e.functionCode.toRadixString(16).padLeft(2, "0").toUpperCase()} -> ${e.hexString} (${e.description})');
  });

  // Start Server
  try {
    await ModbusServerManager.instance.startServer(config);
    print('\n Modbus 从站服务端已成功启动，正在等待外部主站连接...');
  } catch (e) {
    print('\n 启动失败: $e');
    exit(1);
  }

  // Start Simulation if enabled
  if (enableSim) {
    SimulationService.instance.setConnections([config]);
    SimulationService.instance.start();
    print(' 数据波形模拟已开启 (正弦/三角/随机数据实时动态波动中)');
  }

  print(' 按 Ctrl+C 停止服务端\n');

  // Handle process shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n正在优雅停止 Modbus 从站服务...');
    SimulationService.instance.stop();
    await ModbusServerManager.instance.stopServer(config);
    print('服务端已关闭，退出程序。');
    exit(0);
  });

  // Keep alive
  await Completer().future;
}
