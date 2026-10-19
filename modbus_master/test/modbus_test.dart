import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:modbus_master/src/protocol/modbus_crc.dart';
import 'package:modbus_master/src/protocol/modbus_pdu.dart';
import 'package:modbus_master/src/protocol/modbus_frame.dart';
import 'package:modbus_master/src/protocol/modbus_data_types.dart';
import 'package:modbus_master/src/models/connection_config.dart';
import 'package:modbus_master/src/models/slave_model.dart';
import 'package:modbus_master/src/protocol/modbus_client.dart';
import 'package:modbus_master/src/i18n/app_i18n.dart';
import 'package:modbus_master/src/models/workspace_storage.dart';


void main() {
  group('Modbus CRC & LRC Tests', () {
    test('Calculates standard Modbus RTU CRC16 correctly', () {
      // Frame: [0x01, 0x03, 0x00, 0x00, 0x00, 0x0A] -> CRC Low: 0xC5, CRC High: 0xCD -> 0xCDC5
      final bytes = [0x01, 0x03, 0x00, 0x00, 0x00, 0x0A];
      final crc = ModbusCrc.calculateCrc16(bytes);
      expect(crc & 0xFF, equals(0xC5));
      expect((crc >> 8) & 0xFF, equals(0xCD));
    });

    test('Validates frame with CRC', () {
      final validFrame = [0x01, 0x03, 0x00, 0x00, 0x00, 0x0A, 0xC5, 0xCD];
      expect(ModbusCrc.checkCrc16(validFrame), isTrue);

      final invalidFrame = [0x01, 0x03, 0x00, 0x00, 0x00, 0x0A, 0xC5, 0xCE];
      expect(ModbusCrc.checkCrc16(invalidFrame), isFalse);
    });

    test('Calculates Modbus ASCII LRC correctly', () {
      // 0x01 + 0x03 + 0x00 + 0x00 + 0x00 + 0x0A = 0x0E -> LRC = (-0x0E) & 0xFF = 0xF2
      final bytes = [0x01, 0x03, 0x00, 0x00, 0x00, 0x0A];
      final lrc = ModbusCrc.calculateLrc(bytes);
      expect(lrc, equals(0xF2));
    });
  });

  group('Modbus PDU & ADU Framing Tests', () {
    test('Encodes and Decodes Modbus TCP MBAP ADU', () {
      final pdu = ModbusPdu.buildReadRegistersPdu(3, 0, 10);
      final adu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        transactionId: 100,
        unitId: 1,
        pdu: pdu,
      );


      final encoded = adu.encode();
      expect(encoded.length, equals(7 + pdu.length)); // MBAP is 7 bytes

      final decoded = ModbusAdu.decode(encoded, ModbusFrameType.tcp);
      expect(decoded, isNotNull);
      expect(decoded!.transactionId, equals(100));
      expect(decoded.unitId, equals(1));
      expect(decoded.pdu[0], equals(3));
    });

    test('Encodes and Decodes Modbus RTU ADU with CRC', () {
      final pdu = ModbusPdu.buildWriteSingleRegisterPdu(10, 1234);
      final adu = ModbusAdu(
        frameType: ModbusFrameType.rtu,
        unitId: 2,
        pdu: pdu,
      );

      final encoded = adu.encode();
      expect(encoded.length, equals(1 + pdu.length + 2)); // UnitId + PDU + 2 CRC bytes

      final decoded = ModbusAdu.decode(encoded, ModbusFrameType.rtu);
      expect(decoded, isNotNull);
      expect(decoded!.unitId, equals(2));
      expect(decoded.pdu[0], equals(6));
    });
  });

  group('Modbus Data Types & Endianness Tests', () {
    test('Converts Float32 across 4 Byte Orders (ABCD, CDAB, BADC, DCBA)', () {
      final floatVal = 123.456;
      final regs = ModbusDataConverter.float32ToRegisters(floatVal);
      final bytes = ModbusDataConverter.registersToBytes([regs.$1, regs.$2]);

      // Check ABCD
      final valAbcd = ModbusDataConverter.parseValue(bytes, RegisterDataFormat.float32, ModbusByteOrder.abcd) as double;
      expect((valAbcd - floatVal).abs() < 0.001, isTrue);
    });

    test('Converts 32-bit Integer correctly', () {
      final intVal = 12345678;
      final raw = Uint8List(4);
      ByteData.sublistView(raw).setInt32(0, intVal, Endian.big);

      final parsed = ModbusDataConverter.parseValue(raw, RegisterDataFormat.signed32, ModbusByteOrder.abcd);
      expect(parsed, equals(intVal));
    });
  });

  group('VirtualModbusSlave & Client Tests', () {
    test('Simulates FC 01, FC 03, FC 05, FC 06, FC 16 and Exception codes', () async {
      final client = ModbusClient();
      client.isVirtualMode = true;
      await client.connect();

      // 1. Read Holding Registers (FC 03)
      final regs = await client.readHoldingRegisters(unitId: 1, startAddress: 0, quantity: 5);
      expect(regs.length, equals(5));

      // 2. Write Single Register (FC 06)
      await client.writeSingleRegister(unitId: 1, address: 20, value: 8888);
      final readBack = await client.readHoldingRegisters(unitId: 1, startAddress: 20, quantity: 1);
      expect(readBack.first, equals(8888));

      // 3. Write Single Coil (FC 05)
      await client.writeSingleCoil(unitId: 1, address: 5, value: true);
      final coils = await client.readCoils(unitId: 1, startAddress: 5, quantity: 1);
      expect(coils.first, isTrue);

      // 4. Batch Write Registers (FC 16)
      await client.writeMultipleRegisters(unitId: 1, startAddress: 30, values: [111, 222, 333]);
      final batchRead = await client.readHoldingRegisters(unitId: 1, startAddress: 30, quantity: 3);
      expect(batchRead, equals([111, 222, 333]));

      // 5. Exception test: Illegal Data Address (address > 10000)
      expect(
        () => client.readHoldingRegisters(unitId: 1, startAddress: 15000, quantity: 1),
        throwsA(isA<ModbusResponseException>()),
      );


      client.disconnect();
    });
  });

  group('Model Serialization Tests', () {
    test('Serializes and Deserializes ConnectionConfig and SlaveModel', () {
      final config = ConnectionConfig(
        name: '测试站',
        mode: ModbusTransportMode.tcp,
        ip: '192.168.1.100',
        port: 502,
        slaves: [ConnectionConfig.createDefaultSlave()],
      );

      final json = config.toJson();
      final restored = ConnectionConfig.fromJson(json);

      expect(restored.name, equals('测试站'));
      expect(restored.ip, equals('192.168.1.100'));
      expect(restored.slaves.length, equals(1));
      expect(restored.slaves.first.groups.length, equals(2));
    });

    test('Serializes and Deserializes Serial RTU ConnectionConfig', () {
      final serialConfig = ConnectionConfig(
        name: '串口电表从站',
        mode: ModbusTransportMode.serialRtu,
        serialPortName: '/dev/ttyUSB0',
        baudRate: 115200,
        dataBits: 8,
        parity: 2, // Even
        stopBits: 1,
        messageFrameFormat: 1,
        slaves: [ConnectionConfig.createDefaultSlave()],
      );

      final json = serialConfig.toJson();
      expect(json['ConnectionMode'], equals(0));
      expect(json['SerialPortName'], equals('/dev/ttyUSB0'));
      expect(json['BaudRate'], equals(115200));
      expect(json['Parity'], equals(2));

      final restored = ConnectionConfig.fromJson(json);
      expect(restored.mode, equals(ModbusTransportMode.serialRtu));
      expect(restored.serialPortName, equals('/dev/ttyUSB0'));
      expect(restored.baudRate, equals(115200));
      expect(restored.parity, equals(2));
    });
  });

  group('Modbus RTU Streaming Decoding Tests', () {
    test('Handles partial frames without crashing or premature CRC failure', () {
      // Complete frame: Slave 1, FC 3, ByteCount 2, Val 0x0102, CRC
      // CRC of [0x01, 0x03, 0x02, 0x01, 0x02]:
      final body = [0x01, 0x03, 0x02, 0x01, 0x02];
      final fullFrame = ModbusCrc.appendCrc16(Uint8List.fromList(body));

      // Partial 2 bytes:
      expect(ModbusAdu.decode(fullFrame.sublist(0, 2), ModbusFrameType.rtu), isNull);

      // Partial 4 bytes (expected 7):
      expect(ModbusAdu.decode(fullFrame.sublist(0, 4), ModbusFrameType.rtu), isNull);

      // Full frame:
      final adu = ModbusAdu.decode(fullFrame, ModbusFrameType.rtu);
      expect(adu, isNotNull);
      expect(adu!.unitId, equals(1));
      expect(adu.pdu.length, equals(4)); // FC(1) + ByteCount(1) + Data(2)
    });
  });

  group('Multiple Connections & Hierarchical Slaves Tests', () {
    test('Slaves are scoped strictly under their respective Connection', () {
      final conn1 = ConnectionConfig(
        name: '变电站1号机TCP',
        mode: ModbusTransportMode.tcp,
        ip: '192.168.1.10',
        port: 502,
        slaves: [
          SlaveModel(name: '1#高压进线从站', slaveId: 1),
          SlaveModel(name: '2#高压进线从站', slaveId: 2),
        ],
      );

      final conn2 = ConnectionConfig(
        name: '变压器温控串口RTU',
        mode: ModbusTransportMode.serialRtu,
        serialPortName: '/dev/ttyUSB0',
        baudRate: 9600,
        slaves: [
          SlaveModel(name: '温控仪表从站', slaveId: 10),
        ],
      );

      // Verify connection 1 has 2 slaves and connection 2 has 1 slave
      expect(conn1.slaves.length, equals(2));
      expect(conn1.slaves.map((s) => s.slaveId), containsAll([1, 2]));
      expect(conn2.slaves.length, equals(1));
      expect(conn2.slaves.first.slaveId, equals(10));

      // Adding a slave to conn2 does not alter conn1
      conn2.slaves.add(SlaveModel(name: '新增避雷器从站', slaveId: 11));
      expect(conn1.slaves.length, equals(2));
      expect(conn2.slaves.length, equals(2));

      // Workspace JSON round-trip preserves both connections and hierarchical slaves
      final workspaceList = [conn1, conn2];
      final jsonList = workspaceList.map((c) => c.toJson()).toList();
      final restoredList = jsonList.map((j) => ConnectionConfig.fromJson(Map<String, dynamic>.from(j))).toList();

      expect(restoredList.length, equals(2));
      expect(restoredList[0].name, equals('变电站1号机TCP'));
      expect(restoredList[0].slaves.length, equals(2));
      expect(restoredList[1].name, equals('变压器温控串口RTU'));
      expect(restoredList[1].slaves.length, equals(2));
    });
  });

  group('Preset Example Multi-Language i18n Tests', () {
    test('Preset connection and default slave translate dynamically across languages', () {
      final i18n = AppI18n.instance;
      final conn = ConnectionConfig.createDefault();
      final slave = conn.slaves.first;
      final grp = slave.groups.first;
      final reg = grp.registers.first;

      // In Chinese (zh)
      i18n.setLanguage(AppLanguage.zhCN);
      expect(conn.displayName, equals('虚拟从站 (内置仿真)'));
      expect(slave.displayName, contains('主变'));
      expect(grp.displayGroupName, contains('电力模拟量'));
      expect(reg.displayAlias, contains('A相电压'));

      // Switch to English (en)
      i18n.setLanguage(AppLanguage.enUS);
      expect(conn.displayName, equals('Virtual Slave (Built-in Simulation)'));
      expect(slave.displayName, contains('Main Transformer'));
      expect(grp.displayGroupName, contains('Power Telemetry'));
      expect(reg.displayAlias, contains('Phase A Voltage'));

      // Switch to Russian (ru)
      i18n.setLanguage(AppLanguage.ruRU);
      expect(conn.displayName, equals('Виртуальный Slave (Встроенная симуляция)'));
      expect(slave.displayName, contains('трансформатор'));

      // Switch to Japanese (ja)
      i18n.setLanguage(AppLanguage.jaJP);
      expect(slave.displayName, contains('変圧器'));

      // Switch to German (de)
      i18n.setLanguage(AppLanguage.deDE);
      expect(slave.displayName, contains('Haupttransformator'));

      // Reset to zh
      i18n.setLanguage(AppLanguage.zhCN);
    });

    test('WorkspaceStorage presets support multi-language translation and inference', () {
      final i18n = AppI18n.instance;
      final presets = WorkspaceStorage.createDefaultConnections();
      expect(presets.length, equals(3));

      i18n.setLanguage(AppLanguage.zhCN);
      expect(presets[0].displayName, equals('虚拟从站 (内置仿真)'));
      expect(presets[1].displayName, equals('Modbus RTU 串口从站服务 (/dev/ttyUSB0)'));
      expect(presets[2].displayName, equals('Modbus TCP 默认从站服务 (Port 502)'));

      i18n.setLanguage(AppLanguage.enUS);
      expect(presets[0].displayName, equals('Virtual Slave (Built-in Simulation)'));
      expect(presets[1].displayName, equals('Modbus RTU Serial Server (/dev/ttyUSB0)'));
      expect(presets[2].displayName, equals('Modbus TCP Default Server (Port 502)'));

      // Legacy JSON without keys auto-detects preset keys
      final legacyJson = {
        'name': '虚拟仿真回路 (Virtual Simulation)',
        'mode': 'virtual',
        'slaves': [
          {
            'name': '1# 主变压器测控终端',
            'slaveId': 1,
            'groups': [
              {
                'groupName': '三相电力遥测参数',
                'type': 'holdingRegisters',
                'registers': [
                  {
                    'address': 0,
                    'alias': 'A相电压 Ua',
                    'comment': '仿真工频50Hz正弦波动',
                  }
                ]
              }
            ]
          }
        ]
      };

      final restored = ConnectionConfig.fromJson(legacyJson);
      expect(restored.nameKey, equals('transportVirtual'));
      expect(restored.slaves.first.nameKey, equals('preset_slave_transformer'));
      expect(restored.slaves.first.groups.first.groupNameKey, equals('preset_grp_holding_power'));
      expect(restored.slaves.first.groups.first.registers.first.aliasKey, equals('reg_volt_a'));
      expect(restored.slaves.first.groups.first.registers.first.commentKey, equals('cmt_sine_wave'));

      // Now verify that restored legacy preset also translates to English
      expect(restored.displayName, equals('Virtual Slave (Built-in Simulation)'));
      expect(restored.slaves.first.displayName, contains('Main Transformer'));
      expect(restored.slaves.first.groups.first.displayGroupName, contains('Power Telemetry'));
      expect(restored.slaves.first.groups.first.registers.first.displayAlias, contains('Phase A Voltage'));

      i18n.setLanguage(AppLanguage.zhCN);
    });
  });
}
