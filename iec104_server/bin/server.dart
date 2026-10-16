import 'dart:io';
import 'package:iec104_server/src/server/iec104_server.dart';
import 'package:iec104_server/src/server/traffic_logger.dart';

void main(List<String> args) async {
  String host = '0.0.0.0';
  int port = 2404;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--host' && i + 1 < args.length) {
      host = args[++i];
    } else if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[++i]) ?? 2404;
    } else if (args[i] == '--help' || args[i] == '-h') {
      print('IEC 60870-5-104 Server Simulator (CLI Mode)');
      print('Usage: dart run bin/server.dart [options]');
      print('Options:');
      print('  --host <ip>    Bind IP address (default: 0.0.0.0)');
      print('  --port <port>  Listen port (default: 2404)');
      print('  --help, -h     Show this help message');
      exit(0);
    }
  }

  print('====================================================');
  print('  IEC 60870-5-104 Server Simulator (Dart / Flutter)');
  print('====================================================');

  final server = Iec104Server();
  await server.loadWorkspace();
  server.host = host;
  server.port = port;

  // Listen to traffic log and print formatted output
  TrafficLogger.instance.stream.listen((entry) {
    final dir = entry.direction == TrafficDirection.rx ? '\x1B[34m[RX]\x1B[0m' : '\x1B[32m[TX]\x1B[0m';
    final timeStr = entry.timestamp.toIso8601String().substring(11, 23);
    print('$timeStr $dir [${entry.remoteAddress}] ${entry.summary}');
    print('         HEX: ${entry.rawHex}');
  });

  // Listen to client connection changes
  server.clientsStream.listen((clients) {
    print('\x1B[33m[CLIENTS]\x1B[0m 当前在线客户端: ${clients.length}');
  });

  // Listen to remote control commands
  server.commandStream.listen((event) {
    final asdu = event.$1;
    final point = event.$2;
    print('\x1B[35m[COMMAND]\x1B[0m 接收到控制命令: ${asdu.typeId.nameString}, '
        'IOA: ${point?.ioa ?? "?"}, 目标值: ${point?.displayValue ?? "?"}');
  });

  await server.start();
  print('IEC104 Server 已启动，监听于: $host:$port');
  print('默认加载从站: CA=1 (110kV 变电站 #1)');
  print('已配置点位: 单点遥信(4), 双点遥信(2), 短浮点遥测(6), 归一化遥测(2), 标度化遥测(2), 遥脉累计量(2)');
  print('输入 "q" 退出, "list" 查看点位, "set <ioa> <val>" 修改点位值');
  print('----------------------------------------------------');

  // Interactive console command loop
  stdin.listen((data) {
    final line = String.fromCharCodes(data).trim();
    if (line == 'q' || line == 'quit' || line == 'exit') {
      print('正在停止服务器...');
      server.stop().then((_) => exit(0));
    } else if (line == 'list') {
      final st = server.stations.values.firstOrNull;
      if (st != null) {
        print('--- 从站 CA=${st.commonAddress} 点位列表 ---');
        for (final p in st.pointList) {
          print('IOA: ${p.ioa.toString().padLeft(6)} | ${p.typeId.nameString.padRight(12)} | ${p.name.padRight(28)} | 值: ${p.displayValue}');
        }
      }
    } else if (line.startsWith('set ')) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final ioa = int.tryParse(parts[1]);
        final valStr = parts[2];
        if (ioa != null) {
          final st = server.stations.values.firstOrNull;
          final p = st?.getPoint(ioa);
          if (p != null) {
            dynamic parsedVal;
            if (valStr == 'true' || valStr == '1') {
              parsedVal = true;
            } else if (valStr == 'false' || valStr == '0') {
              parsedVal = false;
            } else if (int.tryParse(valStr) != null) {
              parsedVal = int.parse(valStr);
            } else if (double.tryParse(valStr) != null) {
              parsedVal = double.parse(valStr);
            } else {
              parsedVal = valStr;
            }

            server.updatePointValue(st!.commonAddress, ioa, parsedVal);
            print('已更新点位 $ioa 值为: $parsedVal，并向客户端突发推送(COT=3)');
          } else {
            print('未找到 IOA 为 $ioa 的点位');
          }
        }
      } else {
        print('用法: set <ioa> <val>');
      }
    }
  });
}
