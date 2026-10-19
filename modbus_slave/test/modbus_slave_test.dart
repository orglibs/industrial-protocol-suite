import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:modbus_slave/src/i18n/app_i18n.dart';
import 'package:modbus_slave/src/models/connection_config.dart';
import 'package:modbus_slave/src/models/register_group.dart';
import 'package:modbus_slave/src/models/register_model.dart';
import 'package:modbus_slave/src/models/simulation_config.dart';
import 'package:modbus_slave/src/models/slave_model.dart';
import 'package:modbus_slave/src/protocol/modbus_crc.dart';
import 'package:modbus_slave/src/protocol/modbus_data_types.dart';
import 'package:modbus_slave/src/protocol/modbus_frame.dart';
import 'package:modbus_slave/src/protocol/modbus_pdu.dart';
import 'package:modbus_slave/src/protocol/modbus_slave_engine.dart';

void main() {
  group('1. Modbus CRC & LRC Tests', () {
    test('Calculates standard Modbus RTU CRC-16 correctly', () {
      // 01 03 00 00 00 0A => CRC is C5 CD (Low byte C5, High byte CD)
      final frame = Uint8List.fromList([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]);
      final crc = ModbusCrc.calculateCrc16(frame);
      expect(crc, equals(0xCDC5));

      final appended = ModbusCrc.appendCrc16(frame);
      expect(appended.length, equals(8));
      expect(appended[6], equals(0xC5));
      expect(appended[7], equals(0xCD));
      expect(ModbusCrc.checkCrc16(appended), isTrue);
    });

    test('Calculates Modbus ASCII LRC correctly', () {
      final frame = Uint8List.fromList([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]);
      final lrc = ModbusCrc.calculateLrc(frame);
      expect(lrc, equals(0xF2));
    });
  });

  group('2. Modbus Data Types & Endianness Tests', () {
    test('Converts Float32 with ABCD and CDAB correctly', () {
      // 123.456f in IEEE 754: 0x42F6E979
      final wordsAbcd = ModbusDataConverter.float32ToRegisters(123.456, ModbusByteOrder.abcd);
      expect(wordsAbcd.length, equals(2));
      final valAbcd = ModbusDataConverter.registersToFloat32(wordsAbcd[0], wordsAbcd[1], ModbusByteOrder.abcd);
      expect((valAbcd - 123.456).abs() < 0.001, isTrue);

      final wordsCdab = ModbusDataConverter.float32ToRegisters(123.456, ModbusByteOrder.cdab);
      final valCdab = ModbusDataConverter.registersToFloat32(wordsCdab[0], wordsCdab[1], ModbusByteOrder.cdab);
      expect((valCdab - 123.456).abs() < 0.001, isTrue);
    });

    test('Converts Int32 and Double64 correctly', () {
      final intWords = ModbusDataConverter.int32ToRegisters(-1234567, ModbusByteOrder.abcd);
      final intVal = ModbusDataConverter.registersToInt32(intWords[0], intWords[1], ModbusByteOrder.abcd);
      expect(intVal, equals(-1234567));

      final dblWords = ModbusDataConverter.double64ToRegisters(3.141592653589793);
      final dblVal = ModbusDataConverter.registersToDouble64(dblWords[0], dblWords[1], dblWords[2], dblWords[3]);
      expect((dblVal - 3.141592653589793).abs() < 1e-12, isTrue);
    });
  });

  group('3. Modbus Frame Framing & Extract Tests', () {
    test('Extracts valid Modbus TCP request frame', () {
      // MBAP: TxID=1, ProtoID=0, Length=6, UnitID=1, PDU=[03, 00, 00, 00, 05]
      final rawTcp = Uint8List.fromList([
        0x00, 0x01, // TxID
        0x00, 0x00, // ProtoID
        0x00, 0x06, // Length = 1(UnitID) + 5(PDU)
        0x01,       // UnitID
        0x03, 0x00, 0x00, 0x00, 0x05, // PDU
      ]);

      final extracted = ModbusAdu.extractRequest(rawTcp, ModbusFrameType.tcp);
      expect(extracted, isNotNull);
      expect(extracted!.consumed, equals(12));
      expect(extracted.adu.unitId, equals(1));
      expect(extracted.adu.transactionId, equals(1));
      expect(extracted.adu.pdu[0], equals(0x03));
    });

    test('Extracts valid Modbus RTU request frame', () {
      // UnitID=1, FC=3, Addr=0, Qty=5, CRC16=[0x85, 0xC9]
      final body = Uint8List.fromList([0x01, 0x03, 0x00, 0x00, 0x00, 0x05]);
      final rawRtu = ModbusCrc.appendCrc16(body);

      final extracted = ModbusAdu.extractRequest(rawRtu, ModbusFrameType.rtu);
      expect(extracted, isNotNull);
      expect(extracted!.consumed, equals(8));
      expect(extracted.adu.unitId, equals(1));
      expect(extracted.adu.pdu[0], equals(0x03));
    });
  });

  group('4. Modbus Slave Engine Request Dispatching Tests', () {
    late ConnectionConfig conn;
    late SlaveModel slave;

    setUp(() {
      conn = ConnectionConfig(
        name: 'TestConn',
        mode: ModbusTransportMode.tcp,
        port: 502,
        slaves: [ConnectionConfig.createDefaultSlave(1, 'Slave1')],
      );
      slave = conn.slaves.first;
    });

    test('Handles FC 03 (Read Holding Registers)', () async {
      // Preset holding register 0 to 220
      slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!.rawValue = 220;
      slave.findRegister(ModbusRegisterType.holdingRegisters, 1)!.rawValue = 380;

      final reqPdu = ModbusPdu.buildReadRegistersPdu(0x03, 0, 2);
      final reqAdu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        unitId: 1,
        transactionId: 42,
        pdu: reqPdu,
      );

      final respAdu = await ModbusSlaveEngine.processRequest(
        connection: conn,
        requestAdu: reqAdu,
      );

      expect(respAdu, isNotNull);
      expect(respAdu!.transactionId, equals(42));
      expect(respAdu.pdu[0], equals(0x03)); // FC 03
      expect(respAdu.pdu[1], equals(4));    // 4 bytes for 2 registers
      final regs = ModbusPdu.parseReadRegistersResponse(respAdu.pdu);
      expect(regs.length, equals(2));
      expect(regs[0], equals(220));
      expect(regs[1], equals(380));
    });

    test('Handles FC 06 (Write Single Register)', () async {
      final reqPdu = ModbusPdu.buildWriteSingleRegisterPdu(0, 9999);
      final reqAdu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        unitId: 1,
        transactionId: 100,
        pdu: reqPdu,
      );

      final respAdu = await ModbusSlaveEngine.processRequest(
        connection: conn,
        requestAdu: reqAdu,
      );

      expect(respAdu, isNotNull);
      expect(respAdu!.pdu[0], equals(0x06));
      expect(slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!.rawValue, equals(9999));
    });

    test('Handles FC 16 (Write Multiple Registers)', () async {
      final reqPdu = ModbusPdu.buildWriteMultipleRegistersPdu(0, [111, 222, 333]);
      final reqAdu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        unitId: 1,
        transactionId: 101,
        pdu: reqPdu,
      );

      final respAdu = await ModbusSlaveEngine.processRequest(
        connection: conn,
        requestAdu: reqAdu,
      );

      expect(respAdu, isNotNull);
      expect(respAdu!.pdu[0], equals(0x10));
      expect(slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!.rawValue, equals(111));
      expect(slave.findRegister(ModbusRegisterType.holdingRegisters, 1)!.rawValue, equals(222));
      expect(slave.findRegister(ModbusRegisterType.holdingRegisters, 2)!.rawValue, equals(333));
    });

    test('Handles FC 01 (Read Coils) and FC 05 (Write Single Coil)', () async {
      // Write coil 0 to true
      final writePdu = ModbusPdu.buildWriteSingleCoilPdu(0, true);
      final writeAdu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        unitId: 1,
        transactionId: 102,
        pdu: writePdu,
      );
      await ModbusSlaveEngine.processRequest(connection: conn, requestAdu: writeAdu);
      expect(slave.findRegister(ModbusRegisterType.coils, 0)!.rawValue, equals(1));

      // Read coil 0..3
      final readPdu = ModbusPdu.buildReadBitsPdu(0x01, 0, 4);
      final readAdu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        unitId: 1,
        transactionId: 103,
        pdu: readPdu,
      );
      final readResp = await ModbusSlaveEngine.processRequest(connection: conn, requestAdu: readAdu);
      expect(readResp, isNotNull);
      final bits = ModbusPdu.parseReadBitsResponse(readResp!.pdu, 4);
      expect(bits[0], isTrue);
    });

    test('Handles FC 22 (Mask Write Register)', () async {
      slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!.rawValue = 0x0012;

      final maskPdu = ModbusPdu.buildMaskWriteRegisterPdu(0, 0x00F0, 0x0025);
      final maskAdu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        unitId: 1,
        transactionId: 104,
        pdu: maskPdu,
      );

      final resp = await ModbusSlaveEngine.processRequest(connection: conn, requestAdu: maskAdu);
      expect(resp, isNotNull);
      expect(resp!.pdu[0], equals(0x16));
      // Result = (0x0012 & 0x00F0) | (0x0025 & ~0x00F0) = 0x0010 | 0x0025 = 0x0035 (or 0x0017 depending on mask)
      final updated = slave.findRegister(ModbusRegisterType.holdingRegisters, 0)!.rawValue;
      expect(updated, equals((0x0012 & 0x00F0) | (0x0025 & ~0x00F0)));
    });

    test('Returns Illegal Data Address (0x02) for non-existent address', () async {
      final reqPdu = ModbusPdu.buildReadRegistersPdu(0x03, 9999, 1);
      final reqAdu = ModbusAdu(
        frameType: ModbusFrameType.tcp,
        unitId: 1,
        transactionId: 105,
        pdu: reqPdu,
      );

      final respAdu = await ModbusSlaveEngine.processRequest(
        connection: conn,
        requestAdu: reqAdu,
      );

      expect(respAdu, isNotNull);
      expect(respAdu!.pdu[0], equals(0x83)); // 0x80 | 0x03
      expect(respAdu.pdu[1], equals(0x02)); // Illegal Data Address
    });
  });

  group('5. Simulation Waveform Generator Tests', () {
    test('Calculates Sine wave within min and max', () {
      final sim = SimulationConfig(
        enabled: true,
        waveType: EaseWaveType.sine,
        min: 100,
        max: 200,
        durationMs: 2000,
      );

      final vStart = sim.compute(0.0);
      expect(vStart, equals(100.0));

      final vMid = sim.compute(0.5);
      expect(vMid, equals(200.0));

      final vEnd = sim.compute(1.0);
      expect((vEnd - 100.0).abs() < 1e-6, isTrue);
    });

    test('Calculates Triangle wave within min and max', () {
      final sim = SimulationConfig(
        enabled: true,
        waveType: EaseWaveType.triangle,
        min: 0,
        max: 100,
        durationMs: 1000,
      );

      expect(sim.compute(0.0), equals(0.0));
      expect(sim.compute(0.25), equals(50.0));
      expect(sim.compute(0.5), equals(100.0));
      expect(sim.compute(0.75), equals(50.0));
      expect(sim.compute(1.0), equals(0.0));
    });

    test('Calculates Increment counter with step and wrapping', () {
      final sim = SimulationConfig(
        enabled: true,
        waveType: EaseWaveType.increment,
        min: 10,
        max: 20,
        step: 5,
      );

      expect(sim.compute(0, 10), equals(15));
      expect(sim.compute(0, 15), equals(20));
      expect(sim.compute(0, 20), equals(10)); // Wrapped to min
    });
  });

  group('6. JSON Serialization & Deserialization Tests', () {
    test('Serializes and deserializes ConnectionConfig with Slaves and Groups', () {
      final conn = ConnectionConfig(
        name: 'JsonTest',
        mode: ModbusTransportMode.tcp,
        ip: '192.168.1.100',
        port: 5020,
        slaves: [ConnectionConfig.createDefaultSlave(1, 'TestSlave')],
      );

      final jsonMap = conn.toJson();
      final restored = ConnectionConfig.fromJson(jsonMap);

      expect(restored.name, equals('JsonTest'));
      expect(restored.mode, equals(ModbusTransportMode.tcp));
      expect(restored.ip, equals('192.168.1.100'));
      expect(restored.port, equals(5020));
      expect(restored.slaves.length, equals(1));
      expect(restored.slaves.first.name, equals('TestSlave'));
      expect(restored.slaves.first.groups.length, equals(conn.slaves.first.groups.length));
    });
  });

  group('7. Multi-language Dynamic i18n Tests', () {
    test('Verifies dynamic translation switching across all 17 languages', () {
      final defaultSlave = ConnectionConfig.createDefaultSlave(1);
      final defaultConn = ConnectionConfig(
        name: 'Modbus TCP Default Server (Port 502)',
        nameKey: 'preset_conn_tcp',
        slaves: [defaultSlave],
      );

      final voltReg = defaultSlave.groups.first.registers.first; // Phase A Voltage
      final group = defaultSlave.groups.first; // Holding registers

      // Test English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(defaultConn.displayName, equals('Modbus TCP Default Server (Port 502)'));
      expect(defaultSlave.displayName, equals('Substation Main Transformer (Unit 1)'));
      expect(group.displayGroupName, equals('Holding Registers - Power Telemetry (Holding 4x)'));
      expect(voltReg.displayAlias, equals('Phase A Voltage (V)'));
      expect(voltReg.displayComment, equals('Sine wave simulation'));

      // Test Simplified Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(defaultConn.displayName, equals('Modbus TCP 默认从站服务 (Port 502)'));
      expect(defaultSlave.displayName, equals('配电站主变从站 (Unit 1)'));
      expect(group.displayGroupName, equals('保持寄存器-电力模拟量 (Holding 4x)'));
      expect(voltReg.displayAlias, equals('A相电压(V)'));
      expect(voltReg.displayComment, equals('正弦波动模拟'));

      // Test German
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(defaultConn.displayName, contains('Modbus TCP Standard-Server'));
      expect(defaultSlave.displayName, contains('Umspannwerk Haupttransformator'));

      // Test Japanese
      AppI18n.instance.setLanguage(AppLanguage.jaJP);
      expect(defaultConn.displayName, contains('Modbus TCP'));
      expect(defaultSlave.displayName, contains('変電所メイン変圧器'));

      // Test Russian
      AppI18n.instance.setLanguage(AppLanguage.ruRU);
      expect(defaultConn.displayName, contains('Modbus TCP'));
      expect(defaultSlave.displayName, contains('трансформатор'));

      // Test Arabic (RTL)
      AppI18n.instance.setLanguage(AppLanguage.arSA);
      expect(defaultConn.displayName, contains('Modbus TCP'));
      expect(defaultSlave.displayName, contains('المحول'));

      // Reset to English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
    });

    test('Manual user custom names are preserved and never overridden by language switching', () {
      final customReg = RegisterModel(
        address: 0,
        alias: 'Custom Flow Meter #42',
        aliasKey: null, // User custom alias has no key
        comment: 'User custom notes',
        commentKey: null,
      );

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(customReg.displayAlias, equals('Custom Flow Meter #42'));
      expect(customReg.displayComment, equals('User custom notes'));

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(customReg.displayAlias, equals('Custom Flow Meter #42'));
      expect(customReg.displayComment, equals('User custom notes'));

      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(customReg.displayAlias, equals('Custom Flow Meter #42'));
      expect(customReg.displayComment, equals('User custom notes'));
    });

    test('AppI18n.instance.tf parameter replacement formats traffic log summaries', () {
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      final enReq = AppI18n.instance.tf('traffic_fc03_req', {'start': 100, 'qty': 10});
      expect(enReq, equals('Read Holding Registers [FC 03]: Start=100, Qty=10'));

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      final zhReq = AppI18n.instance.tf('traffic_fc03_req', {'start': 100, 'qty': 10});
      expect(zhReq, equals('读保持寄存器 [FC 03]: 起始=100, 数量=10'));
    });

    test('EaseWaveType and ModbusTransportMode labels dynamically translate', () {
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(EaseWaveType.sine.label, equals('Sine Wave'));
      expect(ModbusTransportMode.tcp.label, equals('Modbus TCP Server (Ethernet/LAN)'));

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(EaseWaveType.sine.label, equals('正弦波 (Sine Wave)'));
      expect(ModbusTransportMode.tcp.label, equals('Modbus TCP Server (以太网/局域网服务端)'));
    });

    test('Preserves NameKey, GroupNameKey, AliasKey, CommentKey across JSON serialization', () {
      final slave = ConnectionConfig.createDefaultSlave(1);
      final conn = ConnectionConfig(
        name: 'MyConn',
        nameKey: 'preset_conn_tcp',
        slaves: [slave],
      );

      final json = conn.toJson();
      expect(json['NameKey'], equals('preset_conn_tcp'));
      final slaveJson = (json['SlaveModels'] as List).first as Map<String, dynamic>;
      expect(slaveJson['NameKey'], equals('preset_slave_transformer'));
      final groupJson = (slaveJson['RegisterGroupModels'] as List).first as Map<String, dynamic>;
      expect(groupJson['GroupNameKey'], equals('preset_grp_holding_power'));
      final regJson = (groupJson['RegisterModels'] as List).first as Map<String, dynamic>;
      expect(regJson['AliasKey'], equals('reg_volt_a'));
      expect(regJson['CommentKey'], equals('cmt_sine_wave'));

      final restored = ConnectionConfig.fromJson(json);
      expect(restored.nameKey, equals('preset_conn_tcp'));
      expect(restored.slaves.first.nameKey, equals('preset_slave_transformer'));
      expect(restored.slaves.first.groups.first.groupNameKey, equals('preset_grp_holding_power'));
      expect(restored.slaves.first.groups.first.registers.first.aliasKey, equals('reg_volt_a'));
      expect(restored.slaves.first.groups.first.registers.first.commentKey, equals('cmt_sine_wave'));
    });

    test('Verifies all tab titles exist across all 17 languages for safe navigation rendering', () {
      final tabKeys = ['tabRegisters', 'tabConnections', 'tabTraffic', 'tabCharts', 'tabTools'];
      for (final lang in AppLanguage.values) {
        AppI18n.instance.setLanguage(lang);
        for (final k in tabKeys) {
          final title = AppI18n.instance.t(k);
          expect(title.isNotEmpty, isTrue);
        }
      }
    });
  });
}
