// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:modbus_slave/src/models/connection_config.dart';
import 'package:modbus_slave/src/models/register_group.dart';
import 'package:modbus_slave/src/models/simulation_config.dart';
import 'package:modbus_slave/src/protocol/modbus_crc.dart';
import 'package:modbus_slave/src/protocol/modbus_data_types.dart';
import 'package:modbus_slave/src/protocol/modbus_frame.dart';
import 'package:modbus_slave/src/protocol/modbus_pdu.dart';
import 'package:modbus_slave/src/protocol/modbus_server.dart';
import 'package:modbus_slave/src/services/simulation_service.dart';

void main() async {
  print('================================================================');
  print('       Modbus Slave Emulator (MSE) 全功能自动化集成验证套件        ');
  print('================================================================\n');

  int passed = 0;
  int failed = 0;

  void assertCase(String name, bool condition, [String detail = '']) {
    if (condition) {
      print(' \x1B[32m[PASS]\x1B[0m $name ${detail.isNotEmpty ? "-> $detail" : ""}');
      passed++;
    } else {
      print(' \x1B[31m[FAIL]\x1B[0m $name ${detail.isNotEmpty ? "-> $detail" : ""}');
      failed++;
    }
  }

  // 1. CRC-16 & LRC
  print('--- 1. 协议校验算法验证 (CRC-16 & LRC) ---');
  final crc = ModbusCrc.calculateCrc16([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]);
  assertCase('Modbus RTU CRC16 计算', (crc & 0xFF) == 0xC5 && ((crc >> 8) & 0xFF) == 0xCD, 'CRC: 0x${crc.toRadixString(16).toUpperCase()}');

  final lrc = ModbusCrc.calculateLrc([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]);
  assertCase('Modbus ASCII LRC 计算', lrc == 0xF2, 'LRC: 0x${lrc.toRadixString(16).toUpperCase()}');

  // 2. Data Types and Endianness
  print('\n--- 2. 工业数据解析与四字节序转换验证 ---');
  final wordsAbcd = ModbusDataConverter.float32ToRegisters(220.5, ModbusByteOrder.abcd);
  final valAbcd = ModbusDataConverter.registersToFloat32(wordsAbcd[0], wordsAbcd[1], ModbusByteOrder.abcd);
  assertCase('Float32 大端 ABCD 转换', (valAbcd - 220.5).abs() < 0.01, '解析值: $valAbcd V');

  final wordsCdab = ModbusDataConverter.float32ToRegisters(380.0, ModbusByteOrder.cdab);
  final valCdab = ModbusDataConverter.registersToFloat32(wordsCdab[0], wordsCdab[1], ModbusByteOrder.cdab);
  assertCase('Float32 字交换 CDAB 转换', (valCdab - 380.0).abs() < 0.01, '解析值: $valCdab V');

  final intWords = ModbusDataConverter.int32ToRegisters(1234567, ModbusByteOrder.abcd);
  final intVal = ModbusDataConverter.registersToInt32(intWords[0], intWords[1], ModbusByteOrder.abcd);
  assertCase('32位整型 Int32 转换', intVal == 1234567, '解析值: $intVal');

  // 3. Start Actual Modbus TCP Server on Port 15502
  print('\n--- 3. 真实网络服务端与客户端端到端通信验证 (Port 15502) ---');
  final serverConn = ConnectionConfig(
    name: '集成测试连接',
    mode: ModbusTransportMode.tcp,
    ip: '127.0.0.1',
    port: 15502,
    slaves: [ConnectionConfig.createDefaultSlave(1, '配电站从站 1')],
  );

  await ModbusServerManager.instance.startServer(serverConn);
  assertCase('从站服务端启动绑定 127.0.0.1:15502', serverConn.isRunning, '状态: ${serverConn.statusMessage}');

  // Connect client socket
  final client = await Socket.connect('127.0.0.1', 15502);
  final completerMap = <int, Completer<Uint8List>>{};
  final rxBuffer = <int>[];

  client.listen((data) {
    rxBuffer.addAll(data);
    while (true) {
      if (rxBuffer.length < 7) break;
      final bd = ByteData.sublistView(Uint8List.fromList(rxBuffer));
      final len = bd.getUint16(4, Endian.big);
      final total = 6 + len;
      if (rxBuffer.length < total) break;

      final frame = Uint8List.fromList(rxBuffer.sublist(0, total));
      rxBuffer.removeRange(0, total);

      final txId = bd.getUint16(0, Endian.big);
      if (completerMap.containsKey(txId)) {
        completerMap.remove(txId)!.complete(frame);
      }
    }
  });

  Future<Uint8List> sendModbusTcp({
    required int txId,
    required int unitId,
    required Uint8List pdu,
  }) async {
    final adu = ModbusAdu(
      frameType: ModbusFrameType.tcp,
      unitId: unitId,
      transactionId: txId,
      pdu: pdu,
    );
    final c = Completer<Uint8List>();
    completerMap[txId] = c;
    client.add(adu.encode());
    await client.flush();
    return c.future.timeout(const Duration(seconds: 2));
  }

  // 3.1 FC 03: Read Holding Registers
  print('\n--- 4. Modbus 功能码请求应答全流程测试 ---');
  final slave = serverConn.slaves.first;
  slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!.rawValue = 220; // 220V
  slave.findRegister(ModbusRegisterType.holdingRegisters, 1)!.rawValue = 221; // 221V

  final fc03ReqPdu = ModbusPdu.buildReadRegistersPdu(0x03, 0, 2);
  final fc03RespRaw = await sendModbusTcp(txId: 1, unitId: 1, pdu: fc03ReqPdu);
  final fc03RespAdu = ModbusAdu.extractRequest(fc03RespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('FC 03 读保持寄存器应答码', fc03RespAdu.pdu[0] == 0x03);
  final regs03 = ModbusPdu.parseReadRegistersResponse(fc03RespAdu.pdu);
  assertCase('FC 03 数据点内容正确', regs03[0] == 220 && regs03[1] == 221, '返回: $regs03');

  // 3.2 FC 06: Write Single Register
  final fc06ReqPdu = ModbusPdu.buildWriteSingleRegisterPdu(0, 240);
  final fc06RespRaw = await sendModbusTcp(txId: 2, unitId: 1, pdu: fc06ReqPdu);
  final fc06RespAdu = ModbusAdu.extractRequest(fc06RespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('FC 06 写单个保持寄存器应答码', fc06RespAdu.pdu[0] == 0x06);
  assertCase('FC 06 从站内存数据已更新', slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!.rawValue == 240, '新值: 240');

  // 3.3 FC 16: Write Multiple Registers
  final fc16ReqPdu = ModbusPdu.buildWriteMultipleRegistersPdu(2, [1111, 2222, 3333]);
  final fc16RespRaw = await sendModbusTcp(txId: 3, unitId: 1, pdu: fc16ReqPdu);
  final fc16RespAdu = ModbusAdu.extractRequest(fc16RespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('FC 16 写多个保持寄存器应答码', fc16RespAdu.pdu[0] == 0x10);
  final r2 = slave.findRegister(ModbusRegisterType.holdingRegisters, 2)!.rawValue;
  final r3 = slave.findRegister(ModbusRegisterType.holdingRegisters, 3)!.rawValue;
  final r4 = slave.findRegister(ModbusRegisterType.holdingRegisters, 4)!.rawValue;
  assertCase('FC 16 多个寄存器数据已写入', r2 == 1111 && r3 == 2222 && r4 == 3333, '写入值: [$r2, $r3, $r4]');

  // 3.4 FC 01 & FC 05: Read and Write Single Coil
  final fc05ReqPdu = ModbusPdu.buildWriteSingleCoilPdu(1, true);
  final fc05RespRaw = await sendModbusTcp(txId: 4, unitId: 1, pdu: fc05ReqPdu);
  final fc05RespAdu = ModbusAdu.extractRequest(fc05RespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('FC 05 写单个线圈应答码', fc05RespAdu.pdu[0] == 0x05);
  assertCase('FC 05 从站线圈值置为 1', slave.findRegister(ModbusRegisterType.coils, 1)!.rawValue == 1);

  final fc01ReqPdu = ModbusPdu.buildReadBitsPdu(0x01, 0, 4);
  final fc01RespRaw = await sendModbusTcp(txId: 5, unitId: 1, pdu: fc01ReqPdu);
  final fc01RespAdu = ModbusAdu.extractRequest(fc01RespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('FC 01 读线圈状态应答码', fc01RespAdu.pdu[0] == 0x01);
  final coils = ModbusPdu.parseReadBitsResponse(fc01RespAdu.pdu, 4);
  assertCase('FC 01 线圈状态读取正确', coils[1] == true, '线圈位: $coils');

  // 3.5 FC 22: Mask Write Register
  slave.findRegister(ModbusRegisterType.holdingRegisters, 5)!.rawValue = 0x0012;
  final fc22ReqPdu = ModbusPdu.buildMaskWriteRegisterPdu(5, 0x00F0, 0x0025);
  final fc22RespRaw = await sendModbusTcp(txId: 6, unitId: 1, pdu: fc22ReqPdu);
  final fc22RespAdu = ModbusAdu.extractRequest(fc22RespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('FC 22 屏蔽写保持寄存器应答码', fc22RespAdu.pdu[0] == 0x16);
  final maskedVal = slave.findRegister(ModbusRegisterType.holdingRegisters, 5)!.rawValue;
  assertCase('FC 22 屏蔽与/或运算正确', maskedVal == ((0x0012 & 0x00F0) | (0x0025 & ~0x00F0)), '结果: 0x${maskedVal.toRadixString(16)}');

  // 3.6 FC 08: Diagnostics Echo
  final fc08ReqPdu = ModbusPdu.buildDiagnosticsResponse(0x0000, 0xA55A);
  final fc08RespRaw = await sendModbusTcp(txId: 7, unitId: 1, pdu: fc08ReqPdu);
  final fc08RespAdu = ModbusAdu.extractRequest(fc08RespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('FC 08 诊断回显功能码', fc08RespAdu.pdu[0] == 0x08);
  final diagDiag = ModbusPdu.parseDiagnosticsRequest(fc08RespAdu.pdu);
  assertCase('FC 08 诊断数据回显一致', diagDiag.dataValue == 0xA55A);

  // 3.7 Exception Handling: Illegal Data Address (0x02)
  final errReqPdu = ModbusPdu.buildReadRegistersPdu(0x03, 50000, 5);
  final errRespRaw = await sendModbusTcp(txId: 8, unitId: 1, pdu: errReqPdu);
  final errRespAdu = ModbusAdu.extractRequest(errRespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('非法地址返回异常响应 (0x83)', errRespAdu.pdu[0] == 0x83);
  assertCase('异常码为非法数据地址 (0x02)', errRespAdu.pdu[1] == 0x02);

  // 3.8 Exception Handling: Gateway Path Unavailable (0x0A) for unconfigured Slave ID
  final noSlaveRespRaw = await sendModbusTcp(txId: 9, unitId: 99, pdu: fc03ReqPdu);
  final noSlaveAdu = ModbusAdu.extractRequest(noSlaveRespRaw, ModbusFrameType.tcp)!.adu;
  assertCase('未配置从站返回异常响应', (noSlaveAdu.pdu[0] & 0x80) != 0);
  assertCase('异常码为网关路径不可用 (0x0A)', noSlaveAdu.pdu[1] == 0x0A);

  // 4. Data Simulation Waveform stepping
  print('\n--- 5. 数据波形仿真引擎步进验证 ---');
  final simReg = slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!;
  simReg.simulation = SimulationConfig(
    enabled: true,
    waveType: EaseWaveType.sine,
    min: 200,
    max: 250,
    durationMs: 1000,
  );

  SimulationService.instance.setConnections([serverConn]);
  SimulationService.instance.start();
  assertCase('波形模拟引擎启动', SimulationService.instance.isRunning);

  await Future.delayed(const Duration(milliseconds: 300));
  final waveVal = simReg.rawValue;
  assertCase('波形引擎自动更新寄存器数据', waveVal >= 200 && waveVal <= 250, '正弦波采样值: $waveVal');
  SimulationService.instance.stop();

  // Cleanup
  client.destroy();
  await ModbusServerManager.instance.stopServer(serverConn);
  assertCase('服务端优雅关闭', !serverConn.isRunning);

  // Summary
  print('\n================================================================');
  print('验证结果汇总: 总计 ${passed + failed} 项测试用例, \x1B[32m通过 $passed 项\x1B[0m, \x1B[31m失败 $failed 项\x1B[0m');
  print('================================================================');

  if (failed == 0) {
    print(' 全部用例验证通过！Modbus 从站模拟器引擎运行稳定可靠！\n');
    exit(0);
  } else {
    print(' 存在未通过用例，请检查修复！\n');
    exit(1);
  }
}
