// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:modbus_master/src/models/connection_config.dart';
import 'package:modbus_master/src/protocol/modbus_client.dart';
import 'package:modbus_master/src/protocol/modbus_crc.dart';
import 'package:modbus_master/src/protocol/modbus_data_types.dart';
import 'package:modbus_master/src/protocol/serial_port_adapter.dart';

void main(List<String> args) async {
  print('====================================================');
  print('    Modbus Master CLI 交互式控制台 (MME CLI)         ');
  print('    输入 "help" 查看所有支持的命令，输入 "exit" 退出   ');
  print('====================================================\n');

  final client = ModbusClient();
  // By default, enable virtual mode for instant testing
  client.isVirtualMode = true;
  await client.connect();
  print('✓ 已默认接入内置本地虚拟从站 (Virtual Slave)');

  stdout.write('\nmodbus> ');
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      stdout.write('modbus> ');
      continue;
    }

    final tokens = trimmed.split(RegExp(r'\s+'));
    final cmd = tokens[0].toLowerCase();

    if (cmd == 'exit' || cmd == 'quit') {
      client.disconnect();
      print('已退出 Modbus Master CLI.');
      break;
    }

    try {
      switch (cmd) {
        case 'help':
          print('可用命令列表:');
          print('  connect <ip> <port>      - 连接远程 Modbus TCP 设备 (如 connect 127.0.0.1 502)');
          print('  serial <port> [baudRate] - 连接物理串口/COM 端口 (如 serial /dev/ttyUSB0 9600)');
          print('  ports                    - 列出系统中检测到的所有可用串口');
          print('  virtual                  - 切换为本地虚拟从站模式 (无外部设备即可测试)');
          print('  r3 <slaveId> <addr> <n>  - FC03 读保持寄存器 (如 r3 1 0 10)');
          print('  r1 <slaveId> <addr> <n>  - FC01 读线圈 (如 r1 1 0 8)');
          print('  r2 <slaveId> <addr> <n>  - FC02 读离散输入 (如 r2 1 0 8)');
          print('  r4 <slaveId> <addr> <n>  - FC04 读输入寄存器 (如 r4 1 0 10)');
          print('  w5 <slaveId> <addr> <0|1>- FC05 写单个线圈 (如 w5 1 2 1)');
          print('  w6 <slaveId> <addr> <val>- FC06 写单个保持寄存器 (如 w6 1 0 1234)');
          print('  w16 <slaveId> <addr> <v1> <v2>... - FC16 批量写多个保持寄存器 (如 w16 1 10 100 200 300)');
          print('  crc <hex>                - 计算十六进制数据的 Modbus RTU CRC16 与 LRC');
          print('  convert <float>          - 打印浮点数的 4 种字节序 (ABCD, CDAB, BADC, DCBA)');
          print('  exit / quit              - 退出程序');
          break;

        case 'ports':
          final detected = SerialPortAdapter.getAvailablePorts();
          print('系统检测到的可用串口列表:');
          if (detected.isEmpty) {
            print('  (暂未检测到标准串口设备，可使用虚拟串口节点或手动指定)');
          } else {
            for (final p in detected) {
              print('  - $p');
            }
          }
          break;

        case 'serial':
          if (tokens.length < 2) {
            print('用法: serial <port> [baudRate]');
            break;
          }
          final portName = tokens[1];
          final baud = tokens.length > 2 ? (int.tryParse(tokens[2]) ?? 9600) : 9600;
          await client.disconnect();
          client.isVirtualMode = false;
          client.transportMode = ModbusTransportMode.serialRtu;
          client.serialPortName = portName;
          client.baudRate = baud;
          print('正在打开串口 $portName (波特率 $baud) ...');
          await client.connect();
          print('✓ 串口打开成功: $portName @ $baud bps (RTU 模式)');
          break;

        case 'virtual':
          await client.disconnect();
          client.isVirtualMode = true;
          client.transportMode = ModbusTransportMode.virtual;
          await client.connect();
          print('已切换为本地虚拟从站模式');
          break;

        case 'connect':
          if (tokens.length < 3) {
            print('用法: connect <ip> <port>');
            break;
          }
          final ip = tokens[1];
          final port = int.tryParse(tokens[2]) ?? 502;
          await client.disconnect();
          client.isVirtualMode = false;
          client.transportMode = ModbusTransportMode.tcp;
          client.host = ip;
          client.port = port;
          print('正在连接 $ip:$port ...');
          await client.connect();
          print('✓ 连接成功: $ip:$port');
          break;

        case 'r3':
          final slaveId = int.parse(tokens[1]);
          final addr = int.parse(tokens[2]);
          final count = int.parse(tokens[3]);
          final words = await client.readHoldingRegisters(unitId: slaveId, startAddress: addr, quantity: count);
          print('保持寄存器读取结果 (Slave $slaveId, Addr $addr, Qty $count):');
          for (int i = 0; i < words.length; i++) {
            final w = words[i];
            print('  [${addr + i}] : $w (0x${w.toRadixString(16).padLeft(4, "0").toUpperCase()})');
          }
          break;

        case 'r1':
          final slaveId = int.parse(tokens[1]);
          final addr = int.parse(tokens[2]);
          final count = int.parse(tokens[3]);
          final bits = await client.readCoils(unitId: slaveId, startAddress: addr, quantity: count);
          print('线圈状态读取结果 (Slave $slaveId, Addr $addr, Qty $count):');
          for (int i = 0; i < bits.length; i++) {
            print('  [${addr + i}] : ${bits[i] ? "ON (1)" : "OFF (0)"}');
          }
          break;

        case 'r2':
          final slaveId = int.parse(tokens[1]);
          final addr = int.parse(tokens[2]);
          final count = int.parse(tokens[3]);
          final bits = await client.readDiscreteInputs(unitId: slaveId, startAddress: addr, quantity: count);
          print('离散输入读取结果 (Slave $slaveId, Addr $addr, Qty $count):');
          for (int i = 0; i < bits.length; i++) {
            print('  [${addr + i}] : ${bits[i] ? "1" : "0"}');
          }
          break;

        case 'r4':
          final slaveId = int.parse(tokens[1]);
          final addr = int.parse(tokens[2]);
          final count = int.parse(tokens[3]);
          final words = await client.readInputRegisters(unitId: slaveId, startAddress: addr, quantity: count);
          print('输入寄存器读取结果 (Slave $slaveId, Addr $addr, Qty $count):');
          for (int i = 0; i < words.length; i++) {
            final w = words[i];
            print('  [${addr + i}] : $w (0x${w.toRadixString(16).padLeft(4, "0").toUpperCase()})');
          }
          break;

        case 'w5':
          final slaveId = int.parse(tokens[1]);
          final addr = int.parse(tokens[2]);
          final val = tokens[3] == '1' || tokens[3].toLowerCase() == 'true' || tokens[3].toLowerCase() == 'on';
          await client.writeSingleCoil(unitId: slaveId, address: addr, value: val);
          print('✓ FC05 写入线圈成功: Slave $slaveId, Addr $addr = ${val ? "ON" : "OFF"}');
          break;

        case 'w6':
          final slaveId = int.parse(tokens[1]);
          final addr = int.parse(tokens[2]);
          final val = tokens[3].startsWith('0x') ? int.parse(tokens[3].substring(2), radix: 16) : int.parse(tokens[3]);
          await client.writeSingleRegister(unitId: slaveId, address: addr, value: val & 0xFFFF);
          print('✓ FC06 写入保持寄存器成功: Slave $slaveId, Addr $addr = $val');
          break;

        case 'w16':
          final slaveId = int.parse(tokens[1]);
          final addr = int.parse(tokens[2]);
          final vals = tokens.sublist(3).map((s) => s.startsWith('0x') ? int.parse(s.substring(2), radix: 16) : int.parse(s)).toList();
          await client.writeMultipleRegisters(unitId: slaveId, startAddress: addr, values: vals);
          print('✓ FC16 批量写入寄存器成功: Slave $slaveId, Addr $addr, 数值: $vals');
          break;

        case 'crc':
          final hexStr = tokens.sublist(1).join('').replaceAll(' ', '');
          final bytes = <int>[];
          for (int i = 0; i < hexStr.length; i += 2) {
            bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
          }
          final crc16 = ModbusCrc.calculateCrc16(bytes);
          final lrc = ModbusCrc.calculateLrc(bytes);
          print('CRC16: 0x${crc16.toRadixString(16).padLeft(4, "0").toUpperCase()} (Low: 0x${(crc16 & 0xFF).toRadixString(16).padLeft(2, "0").toUpperCase()}, High: 0x${((crc16 >> 8) & 0xFF).toRadixString(16).padLeft(2, "0").toUpperCase()})');
          print('LRC:   0x${lrc.toRadixString(16).padLeft(2, "0").toUpperCase()}');
          break;

        case 'convert':
          final fVal = double.parse(tokens[1]);
          final r = ModbusDataConverter.float32ToRegisters(fVal);
          final bytes = ModbusDataConverter.registersToBytes([r.$1, r.$2]);
          print('浮点数 $fVal 转换为 4 种字节序:');
          for (final order in ModbusByteOrder.values) {
            final reordered = ModbusDataConverter.reorder32Bytes(bytes, order);
            final dump = reordered.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
            print('  ${order.name.toUpperCase().padRight(5)} (${order.label}): $dump');
          }
          break;

        default:
          print('未知命令: $cmd (输入 "help" 查看所有命令)');
      }
    } catch (e) {
      print('执行错误: $e');
    }

    stdout.write('modbus> ');
  }
}
