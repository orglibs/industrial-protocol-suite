import 'dart:io';
import 'package:iec104_client/src/client/iec104_client.dart';
import 'package:iec104_client/src/client/traffic_logger.dart';

void main(List<String> args) async {
  String host = '127.0.0.1';
  int port = 2404;
  int ca = 1;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--host' && i + 1 < args.length) {
      host = args[++i];
    } else if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[++i]) ?? 2404;
    } else if (args[i] == '--ca' && i + 1 < args.length) {
      ca = int.tryParse(args[++i]) ?? 1;
    } else if (args[i] == '--help' || args[i] == '-h') {
      print('IEC 60870-5-104 Client Simulator (CLI Mode)');
      print('Usage: dart run bin/client.dart [options]');
      print('Options:');
      print('  --host <ip>    Server IP address (default: 127.0.0.1)');
      print('  --port <port>  Server port (default: 2404)');
      print('  --ca <addr>    Default Common Address COA (default: 1)');
      print('  --help, -h     Show this help message');
      exit(0);
    }
  }

  print('====================================================');
  print('  IEC 60870-5-104 Client Simulator (Dart / Flutter)');
  print('====================================================');
  print('目标服务端: $host:$port (默认从站公共地址 COA: $ca)');

  final client = Iec104Client();
  client.host = host;
  client.port = port;
  client.defaultCa = ca;

  // Listen to traffic log
  TrafficLogger.instance.stream.listen((entry) {
    final dir = entry.direction == TrafficDirection.rx ? '\x1B[34m[RX]\x1B[0m' : '\x1B[32m[TX]\x1B[0m';
    final timeStr = entry.timestamp.toIso8601String().substring(11, 23);
    print('$timeStr $dir ${entry.summary}');
    print('         HEX: ${entry.rawHex}');
  });

  // Listen to state changes
  client.stateStream.listen((state) {
    print('\x1B[33m[STATE]\x1B[0m 连接状态变更为: ${state.label}');
  });

  // Listen to point updates
  client.pointUpdateStream.listen((point) {
    print('\x1B[36m[DATA]\x1B[0m 点位更新 [CA=${point.commonAddress}, IOA=${point.ioa}] '
        '${point.name}: ${point.displayValue}');
  });

  // Listen to command results
  client.commandResultStream.listen((event) {
    print('\x1B[35m[CMD-RESP]\x1B[0m ${event.message}');
  });

  print('正在连接服务端...');
  try {
    await client.connect();
    print('已发送连接请求。输入 "help" 查看命令，输入 "q" 退出。');
  } catch (e) {
    print('\x1B[31m连接失败: $e\x1B[0m (您可以输入 "connect" 稍后重试)');
  }
  print('----------------------------------------------------');

  stdin.listen((data) async {
    final line = String.fromCharCodes(data).trim();
    if (line.isEmpty) return;

    final parts = line.split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase();

    if (cmd == 'q' || cmd == 'quit' || cmd == 'exit') {
      print('正在断开连接并退出...');
      await client.disconnect();
      exit(0);
    } else if (cmd == 'help' || cmd == '?') {
      print('支持的指令:');
      print('  connect         - 重新连接服务器');
      print('  disconnect      - 断开连接');
      print('  startdt         - 发送 STARTDT act (启动数据传输)');
      print('  stopdt          - 发送 STOPDT act (停止数据传输)');
      print('  testfr          - 发送 TESTFR act (链路测试)');
      print('  s               - 发送 S 格式确认帧');
      print('  gi [ca]         - 发送 C_IC_NA_1 全站总召唤');
      print('  ci [ca]         - 发送 C_CI_NA_1 电能量总召唤');
      print('  clock [ca]      - 发送 C_CS_NA_1 时钟同步');
      print('  sc <ioa> <0|1>  - 发送单命令直接执行 (0=分, 1=合)');
      print('  sc-sel <ioa> <0|1> - 发送单命令预置选择');
      print('  dc <ioa> <0|1>  - 发送双命令直接执行 (0=分, 1=合)');
      print('  read <ioa>      - 发送 C_RD_NA_1 读单点当前值');
      print('  list            - 查看当前已收录的所有点位值');
      print('  q / quit        - 退出程序');
    } else if (cmd == 'connect') {
      await client.connect();
    } else if (cmd == 'disconnect') {
      await client.disconnect();
    } else if (cmd == 'startdt') {
      client.sendStartDt();
    } else if (cmd == 'stopdt') {
      client.sendStopDt();
    } else if (cmd == 'testfr') {
      client.sendTestFr();
    } else if (cmd == 's') {
      client.sendSFrame();
    } else if (cmd == 'gi') {
      final targetCa = parts.length > 1 ? int.tryParse(parts[1]) ?? ca : ca;
      client.sendGeneralInterrogation(ca: targetCa);
    } else if (cmd == 'ci') {
      final targetCa = parts.length > 1 ? int.tryParse(parts[1]) ?? ca : ca;
      client.sendCounterInterrogation(ca: targetCa);
    } else if (cmd == 'clock') {
      final targetCa = parts.length > 1 ? int.tryParse(parts[1]) ?? ca : ca;
      client.sendClockSynchronization(ca: targetCa);
    } else if (cmd == 'sc' || cmd == 'sc-sel') {
      if (parts.length >= 3) {
        final ioa = int.tryParse(parts[1]) ?? 1;
        final val = parts[2] == '1' || parts[2].toLowerCase() == 'true';
        final isSelect = cmd == 'sc-sel';
        client.sendSingleCommand(ca: ca, ioa: ioa, value: val, select: isSelect);
        print('已下发单命令: IOA=$ioa, 值=$val, 预置=$isSelect');
      } else {
        print('用法: $cmd <ioa> <0|1>');
      }
    } else if (cmd == 'dc') {
      if (parts.length >= 3) {
        final ioa = int.tryParse(parts[1]) ?? 1;
        final val = parts[2] == '1' ? 2 : 1;
        client.sendDoubleCommand(ca: ca, ioa: ioa, value: val, select: false);
        print('已下发双命令执行: IOA=$ioa, 值=${val == 2 ? "合(ON)" : "分(OFF)"}');
      } else {
        print('用法: dc <ioa> <0|1>');
      }
    } else if (cmd == 'read') {
      if (parts.length >= 2) {
        final ioa = int.tryParse(parts[1]) ?? 1;
        client.sendReadCommand(ca: ca, ioa: ioa);
        print('已下发读单点命令: IOA=$ioa');
      } else {
        print('用法: read <ioa>');
      }
    } else if (cmd == 'list') {
      for (final st in client.stations.values) {
        print('--- 从站 CA=${st.commonAddress} 点位列表 (共 ${st.points.length} 个) ---');
        for (final p in st.pointList) {
          print('IOA: ${p.ioa.toString().padLeft(6)} | ${p.typeCategory.padRight(14)} | ${p.name.padRight(28)} | 值: ${p.displayValue}');
        }
      }
    } else {
      print('未知指令: "$cmd"，输入 "help" 查看帮助。');
    }
  });
}
