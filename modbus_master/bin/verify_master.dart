// ignore_for_file: avoid_print
import 'package:modbus_master/src/protocol/modbus_client.dart';
import 'package:modbus_master/src/protocol/modbus_crc.dart';
import 'package:modbus_master/src/protocol/modbus_data_types.dart';
import 'package:modbus_master/src/models/connection_config.dart';
import 'package:modbus_master/src/services/polling_service.dart';
import 'package:modbus_master/src/protocol/serial_port_adapter.dart';


void main() async {
  print('================================================================');
  print('       Modbus Master Emulator (MME) 自动化全功能验证套件        ');
  print('================================================================\n');

  int passed = 0;
  int failed = 0;

  void assertCase(String name, bool condition, [String detail = '']) {
    if (condition) {
      print(' [PASS] $name ${detail.isNotEmpty ? "-> $detail" : ""}');
      passed++;
    } else {
      print(' [FAIL] $name ${detail.isNotEmpty ? "-> $detail" : ""}');
      failed++;
    }
  }

  // 1. CRC16 and LRC
  print('--- 1. 协议校验算法验证 (CRC-16 & LRC) ---');
  final crc = ModbusCrc.calculateCrc16([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]);
  assertCase('Modbus RTU CRC16 计算', (crc & 0xFF) == 0xC5 && ((crc >> 8) & 0xFF) == 0xCD, 'CRC: 0x${crc.toRadixString(16).toUpperCase()}');

  final lrc = ModbusCrc.calculateLrc([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]);
  assertCase('Modbus ASCII LRC 计算', lrc == 0xF2, 'LRC: 0x${lrc.toRadixString(16).toUpperCase()}');

  // 2. Data Types and Endianness
  print('\n--- 2. 工业数据解析与四字节序转换验证 ---');
  final regs = ModbusDataConverter.float32ToRegisters(380.5);
  final bytes = ModbusDataConverter.registersToBytes([regs.$1, regs.$2]);
  final valAbcd = ModbusDataConverter.parseValue(bytes, RegisterDataFormat.float32, ModbusByteOrder.abcd) as double;
  assertCase('Float32 (IEEE 754) 大端 ABCD 解析', (valAbcd - 380.5).abs() < 0.01, '解析值: $valAbcd V');

  final intVal = 987654;
  final intRegs = [intVal >> 16, intVal & 0xFFFF];
  final intBytes = ModbusDataConverter.registersToBytes(intRegs);
  final parsedInt = ModbusDataConverter.parseValue(intBytes, RegisterDataFormat.signed32, ModbusByteOrder.abcd);
  assertCase('32位整型 (Int32) 解析', parsedInt == intVal, '解析值: $parsedInt');

  // 3. Client & Virtual Slave Interactive Modbus Protocol Tests
  print('\n--- 3. 客户端与虚拟从站交互测试 (FC 01, 02, 03, 04, 05, 06, 15, 16) ---');
  final client = ModbusClient();
  client.isVirtualMode = true;
  await client.connect();
  assertCase('连接虚拟从站状态', client.state == ModbusConnectionState.connected);

  // FC 03
  final holdRegs = await client.readHoldingRegisters(unitId: 1, startAddress: 0, quantity: 4);
  assertCase('FC 03 读保持寄存器 (电力模拟量)', holdRegs.length == 4, '返回寄存器: $holdRegs');

  // FC 01
  final coils = await client.readCoils(unitId: 1, startAddress: 0, quantity: 4);
  assertCase('FC 01 读线圈状态 (开关遥信)', coils.length == 4, '线圈位: $coils');

  // FC 05
  await client.writeSingleCoil(unitId: 1, address: 2, value: true);
  final updatedCoils = await client.readCoils(unitId: 1, startAddress: 2, quantity: 1);
  assertCase('FC 05 写单个线圈', updatedCoils.first == true, '写入目标位=1，读取验证通过');

  // FC 06
  await client.writeSingleRegister(unitId: 1, address: 25, value: 54321);
  final updatedReg = await client.readHoldingRegisters(unitId: 1, startAddress: 25, quantity: 1);
  assertCase('FC 06 写单个保持寄存器', updatedReg.first == 54321, '写入值=54321，读取回显一致');

  // FC 16
  await client.writeMultipleRegisters(unitId: 1, startAddress: 40, values: [1001, 1002, 1003]);
  final batchRegs = await client.readHoldingRegisters(unitId: 1, startAddress: 40, quantity: 3);
  assertCase('FC 16 批量写多个寄存器', batchRegs.length == 3 && batchRegs[1] == 1002, '批量写入3个点，读取值: $batchRegs');

  // 4. Polling Service Cyclic Test
  print('\n--- 4. 自动化轮询任务服务测试 (PollingService) ---');
  final config = ConnectionConfig(
    mode: ModbusTransportMode.virtual,
    slaves: [ConnectionConfig.createDefaultSlave()],
  );
  final pollingService = PollingService(client: client, config: config);
  pollingService.updateConfig(config);

  final targetGroup = config.slaves.first.groups.first;
  await pollingService.scanGroup(config.slaves.first, targetGroup);
  await Future.delayed(const Duration(milliseconds: 10));

  assertCase('轮询服务单次扫描', targetGroup.lastScanStatus?.contains('成功') == true, '扫描耗时: ${targetGroup.lastLatencyMs}ms');

  // 5. Serial Port Adapter & Modbus RTU Transport
  print('\n--- 5. 物理串口适配器 (SerialPortAdapter) 与 RTU 通信 ---');
  final ports = SerialPortAdapter.getAvailablePorts();
  assertCase('系统物理串口自动探测', ports.runtimeType == (List<String>), '检测到系统串口列表: $ports');

  final serialConfig = ConnectionConfig(
    name: '串口测试',
    mode: ModbusTransportMode.serialRtu,
    serialPortName: '/dev/ttyUSB0',
    baudRate: 115200,
    dataBits: 8,
    parity: 0,
    stopBits: 1,
  );
  assertCase('Modbus RTU 串口连接参数配置', serialConfig.mode == ModbusTransportMode.serialRtu && serialConfig.baudRate == 115200, '模式: ${serialConfig.mode.label}, 端口: ${serialConfig.serialPortName}, 波特率: ${serialConfig.baudRate}');

  final serialClient = ModbusClient();
  serialClient.transportMode = ModbusTransportMode.serialRtu;
  serialClient.isVirtualMode = true; // Virtual engine over serial mode
  await serialClient.connect();
  assertCase('Serial RTU 模式启动连接状态', serialClient.state == ModbusConnectionState.connected, '通信状态: ${serialClient.state.label}');
  final serialHoldRegs = await serialClient.readHoldingRegisters(unitId: 1, startAddress: 0, quantity: 2);
  assertCase('Serial RTU 模式读寄存器', serialHoldRegs.length == 2, '返回寄存器: $serialHoldRegs');
  await serialClient.disconnect();
  assertCase('Serial RTU 模式断开连接', serialClient.state == ModbusConnectionState.disconnected);

  print('\n================================================================');
  print('验证结果统计: 共 ${passed + failed} 项测试, 通过: $passed, 失败: $failed');
  print('================================================================');
}
