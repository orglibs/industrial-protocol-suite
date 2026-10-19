import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:iec61850_client/src/models/client_variable_model.dart';
import 'package:iec61850_client/src/models/connection_config.dart';
import 'package:iec61850_client/src/models/dictionary_service.dart';
import 'package:iec61850_client/src/models/scl_models.dart';
import 'package:iec61850_client/src/models/scl_parser.dart';
import 'package:iec61850_client/src/protocol/goose_receiver.dart';
import 'package:iec61850_client/src/protocol/iso_acse_mms.dart';
import 'package:iec61850_client/src/i18n/app_i18n.dart';
import 'package:iec61850_client/src/protocol/tpkt_cotp.dart';

void main() {
  group('TPKT & COTP Protocol Tests', () {
    test('TPKT Wrap and Extract', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final tpkt = TpktFrame.wrap(payload);

      expect(tpkt.length, 5 + 4);
      expect(tpkt[0], 0x03); // TPKT Version
      expect(tpkt[1], 0x00); // Reserved

      final extracted = TpktFrame.extract(tpkt);
      expect(extracted, isNotNull);
      expect(extracted!.payload, equals(payload));
      expect(extracted.consumed, 9);
    });

    test('COTP CR and CC Framing', () {
      final cr = CotpFrame.buildConnectionRequest(
        dstRef: 0x0000,
        srcRef: 0x0001,
        localTsap: 0x0001,
        remoteTsap: 0x0001,
      );

      expect(CotpFrame.isConnectionRequest(cr), isTrue);

      final cc = CotpFrame.buildConnectionConfirm(
        dstRef: 0x0001,
        srcRef: 0x0002,
      );

      expect(CotpFrame.isConnectionConfirm(cc), isTrue);
    });

    test('COTP DT Framing', () {
      final data = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final dt = CotpFrame.wrapDataTransfer(data);
      expect(dt[0], 0x02); // LI
      expect(dt[1], 0xF0); // DT Code
      expect(dt[2], 0x80); // EOT
      expect(dt.sublist(3), equals(data));

      final extracted = CotpFrame.extractDataPayload(dt);
      expect(extracted, equals(data));
    });
  });

  group('ASN.1 BER & MMS Value Codec Tests', () {
    test('BerTlv Encode & Decode', () {
      final tlv = BerTlv(0x83, Uint8List.fromList([0x01]));
      final encoded = tlv.encode();

      final decoded = BerTlv.decode(encoded, 0);
      expect(decoded, isNotNull);
      expect(decoded!.tag, 0x83);
      expect(decoded.length, 1);
      expect(decoded.value, equals(Uint8List.fromList([0x01])));
    });

    test('MmsValueCodec Boolean', () {
      final encodedTrue = MmsValueCodec.encodeValue(true, IecBasicType.boolean);
      expect(encodedTrue[0], 0x83);
      expect(encodedTrue[2], 0xFF);

      final decoded = MmsValueCodec.decodeValue(encodedTrue, 0);
      expect(decoded.value, isTrue);
    });

    test('MmsValueCodec Integer & Unsigned', () {
      final encInt = MmsValueCodec.encodeValue(12345, IecBasicType.int32);
      expect(encInt[0], 0x85);

      final decInt = MmsValueCodec.decodeValue(encInt, 0);
      expect(decInt.value, 12345);

      final encUint = MmsValueCodec.encodeValue(54321, IecBasicType.uint32);
      expect(encUint[0], 0x86);

      final decUint = MmsValueCodec.decodeValue(encUint, 0);
      expect(decUint.value, 54321);
    });

    test('MmsValueCodec Float', () {
      final encFloat = MmsValueCodec.encodeValue(220.5, IecBasicType.float32);
      expect(encFloat[0], 0x87);

      final decFloat = MmsValueCodec.decodeValue(encFloat, 0);
      expect((decFloat.value as double), closeTo(220.5, 0.001));
    });

    test('MmsValueCodec VisibleString', () {
      final encStr = MmsValueCodec.encodeValue('IEC61850', IecBasicType.visibleString);
      expect(encStr[0], 0x8A);

      final decStr = MmsValueCodec.decodeValue(encStr, 0);
      expect(decStr.value, 'IEC61850');
    });

    test('ACSE AARQ with MMS Initiate Construction', () {
      final aarq = IsoAcseMms.buildAarqWithMmsInitiate();
      expect(aarq.isNotEmpty, isTrue);
      expect(aarq.contains(0x60), isTrue); // Contains ACSE AARQ tag
    });
  });

  group('SCL Parser Tests', () {
    test('Parse server_example_basic_io.icd', () {
      final file = File('assets/examples/server_example_basic_io.icd');
      expect(file.existsSync(), isTrue);

      final result = SclParser.parse(file.readAsStringSync());
      expect(result.iedName, isNotEmpty);
      expect(result.variables.length, greaterThan(10));
      expect(result.dataSets.length, greaterThanOrEqualTo(2));
      expect(result.reportControls.length, greaterThanOrEqualTo(2));

      // Check BRCB and URCB
      final brcb = result.reportControls.firstWhere((r) => r.buffered);
      final urcb = result.reportControls.firstWhere((r) => !r.buffered);
      expect(brcb.name, isNotEmpty);
      expect(urcb.name, isNotEmpty);
    });

    test('Parse server_example_control.icd', () {
      final file = File('assets/examples/server_example_control.icd');
      expect(file.existsSync(), isTrue);

      final result = SclParser.parse(file.readAsStringSync());
      expect(result.iedName, isNotEmpty);

      // Check controllable points (CO)
      final coVars = result.variables.where((v) => v.fc == FunctionalConstraint.co).toList();
      expect(coVars.length, greaterThan(0));
    });

    test('Parse server_example_goose.icd', () {
      final file = File('assets/examples/server_example_goose.icd');
      expect(file.existsSync(), isTrue);

      final result = SclParser.parse(file.readAsStringSync());
      expect(result.iedName, equals('IED_GOOSE'));
      expect(result.gseControls.length, greaterThanOrEqualTo(1));
    });
  });

  group('GOOSE Receiver Tests', () {
    test('Decode GOOSE PDU packet', () {
      final gocbRef = utf8.encode('Device1/LLN0\$GO\$gcb01');
      final datSet = utf8.encode('Device1/LLN0\$dsGoose');
      final goId = utf8.encode('GOOSE_TRIP');

      final inner = <int>[
        0x80, gocbRef.length, ...gocbRef,
        0x81, 0x02, 0x07, 0xD0, // TAL 2000ms
        0x82, datSet.length, ...datSet,
        0x83, goId.length, ...goId,
        0x84, 0x08, 0x67, 0x0E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x85, 0x01, 0x03, // stNum 3
        0x86, 0x01, 0x07, // sqNum 7
        0x87, 0x01, 0x00, // test false
        0x88, 0x01, 0x01, // confRev 1
        0x89, 0x01, 0x00, // ndsCom false
        0x8A, 0x01, 0x02, // numEntries 2
        0xAB, 0x06,
        0x83, 0x01, 0xFF, // boolean true
        0x84, 0x01, 0x00, // quality Good
      ];

      final goosePdu = BerTlv(0x61, Uint8List.fromList(inner)).encode();
      final packet = Uint8List.fromList([
        0x00, 0x01, // APPID
        0x00, goosePdu.length + 8, // Length
        0x00, 0x00,
        0x00, 0x00,
        ...goosePdu,
      ]);

      final msg = GooseReceiverService.instance.processPacket(packet);
      expect(msg, isNotNull);
      expect(msg!.appId, 1);
      expect(msg.gocbRef, 'Device1/LLN0\$GO\$gcb01');
      expect(msg.stNum, 3);
      expect(msg.sqNum, 7);
      expect(msg.allData.length, 2);
      expect(msg.allData[0], isTrue);
    });
  });

  group('ClientVariableModel Quality & Serialization Tests', () {
    test('Quality flags formatting', () {
      final v = ClientVariableModel(
        reference: 'IED1LD0/GGIO1.AnIn1.mag',
        iedName: 'IED1',
        ldInst: 'LD0',
        lnName: 'GGIO1',
        fc: FunctionalConstraint.mx,
        doName: 'AnIn1',
        daName: 'mag',
        type: IecBasicType.float32,
        initialValue: 12.34,
      );

      expect(v.qualityString, contains('Good'));
      expect(v.shortRef, 'LD0/GGIO1.AnIn1.mag[MX]');
      expect(v.mmsRef, 'LD0/GGIO1\$MX\$AnIn1\$mag');

      v.quality = 0x0001; // Invalid flag
      expect(v.qualityString, contains('Invalid'));
    });

    test('Json Serialization roundtrip', () {
      final cfg = ConnectionConfig(
        id: 'conn_101',
        name: '测试站 1',
        ip: '192.168.1.100',
        port: 102,
        localTsap: 0x0001,
        remoteTsap: 0x0002,
        autoConnect: true,
      );

      final json = cfg.toJson();
      final restored = ConnectionConfig.fromJson(json);

      expect(restored.id, cfg.id);
      expect(restored.name, cfg.name);
      expect(restored.ip, cfg.ip);
      expect(restored.port, cfg.port);
      expect(restored.localTsap, cfg.localTsap);
      expect(restored.remoteTsap, cfg.remoteTsap);
      expect(restored.autoConnect, isTrue);
    });

    test('ConnectionConfig demo data reactively updates displayName via nameKey', () {
      final cfg = ConnectionConfig(
        id: 'conn_default',
        name: 'Local Test Server (127.0.0.1:102)',
        nameKey: 'preset_iec61850_client_conn',
      );

      // Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(cfg.displayName, contains('本地测试连接'));

      // English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(cfg.displayName, contains('Local Test Connection'));

      // German
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(cfg.displayName, contains('Lokale Testverbindung'));

      // Deserialization with fallback inference
      final legacy = ConnectionConfig.fromJson({
        'Id': 'conn_default',
        'Name': 'Local Test Server (127.0.0.1:102)',
        'Ip': '127.0.0.1',
      });
      expect(legacy.nameKey, equals('preset_iec61850_client_conn'));
      expect(legacy.displayName, contains('Lokale Testverbindung'));
    });

    test('ConnectionConfig.createDefaultConnections returns 3 presets with multilingual support', () {
      final defaults = ConnectionConfig.createDefaultConnections();
      expect(defaults.length, 3);

      final bay = defaults[0];
      final xfmr = defaults[1];
      final goose = defaults[2];

      expect(bay.id, 'conn_bay_controller');
      expect(bay.port, 102);
      expect(xfmr.id, 'conn_transformer_ied');
      expect(xfmr.port, 10102);
      expect(goose.id, 'conn_goose_ied');
      expect(goose.port, 20102);

      // Chinese verification
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(bay.displayName, contains('变电站间隔控制器'));
      expect(xfmr.displayName, contains('主变测控保护终端'));
      expect(goose.displayName, contains('智能配网GOOSE终端'));

      // English verification
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(bay.displayName, contains('Substation Bay Controller'));
      expect(xfmr.displayName, contains('Main Transformer Protection IED'));
      expect(goose.displayName, contains('Distribution Automation GOOSE IED'));

      // Japanese verification
      AppI18n.instance.setLanguage(AppLanguage.jaJP);
      expect(bay.displayName, contains('変電所ベイコントローラ'));
      expect(xfmr.displayName, contains('主変圧器保護制御IED'));
      expect(goose.displayName, contains('スマート配電GOOSE端末'));

      // copyWith verification
      final copied = bay.copyWith(name: 'Copied Bay', port: 10105);
      expect(copied.name, 'Copied Bay');
      expect(copied.port, 10105);
      expect(copied.id, bay.id);
      expect(copied.localTsap, bay.localTsap);
    });
  });

  group('ClientVariableModel nameKey & Multilingual Tests', () {
    test('ClientVariableModel displayName updates dynamically with language switch', () {
      final v = ClientVariableModel(
        reference: 'simpleIO/GenericIO/GGIO1.AnIn1.mag.f',
        iedName: 'simpleIO',
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'AnIn1',
        daName: 'mag.f',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.float32,
        nameKey: 'point_volt_a',
      );

      // Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(v.displayName, contains('A相电压'));

      // English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(v.displayName, contains('Phase A Voltage'));

      // German
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(v.displayName, contains('Phase A Spannung'));

      // Japanese
      AppI18n.instance.setLanguage(AppLanguage.jaJP);
      expect(v.displayName, contains('A相電圧'));

      // Russian
      AppI18n.instance.setLanguage(AppLanguage.ruRU);
      expect(v.displayName, contains('Напряжение фазы A'));
    });

    test('ClientVariableModel JSON serialization preserves Name and NameKey', () {
      final v = ClientVariableModel(
        reference: 'simpleIO/GenericIO/GGIO1.SPCSO1.stVal',
        iedName: 'simpleIO',
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'SPCSO1',
        daName: 'stVal',
        fc: FunctionalConstraint.st,
        type: IecBasicType.boolean,
        name: 'Custom Switch 1',
        nameKey: 'point_feeder_switch_1',
      );

      final json = v.toJson();
      expect(json['Name'], equals('Custom Switch 1'));
      expect(json['NameKey'], equals('point_feeder_switch_1'));

      final restored = ClientVariableModel.fromJson(json);
      expect(restored.name, equals('Custom Switch 1'));
      expect(restored.nameKey, equals('point_feeder_switch_1'));

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(restored.displayName, contains('1#进线开关'));
    });

    test('ClientVariableModel.fromJson automatically infers nameKey when omitted', () {
      final jsonLegacy = {
        'Reference': 'IED1PROT/PTRC1.Tr.general',
        'IedName': 'IED1',
        'LdInst': 'PROT',
        'LnName': 'PTRC1',
        'DoName': 'Tr',
        'DaName': 'general',
        'FC': 'ST',
        'Type': 'boolean',
      };

      final restored = ClientVariableModel.fromJson(jsonLegacy);
      expect(restored.nameKey, equals('point_protection_trip'));

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(restored.displayName, contains('保护总动作跳闸'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(restored.displayName, contains('Protection Trip Action'));
    });

    test('SclParser parses sample ICDs with nameKey populated on sample variables', () {
      final basicIoFile = File('assets/examples/server_example_basic_io.icd');
      expect(basicIoFile.existsSync(), isTrue);

      final result = SclParser.parse(basicIoFile.readAsStringSync());
      expect(result.variables.isNotEmpty, isTrue);

      // Check SPCSO1 has point_feeder_switch_1
      final spcso1 = result.variables.firstWhere(
        (v) => v.lnName == 'GGIO1' && v.doName == 'SPCSO1' && v.daName == 'stVal',
      );
      expect(spcso1.nameKey, equals('point_feeder_switch_1'));

      // Check AnIn1 has point_volt_a
      final anIn1 = result.variables.firstWhere(
        (v) => v.lnName == 'GGIO1' && v.doName == 'AnIn1' && v.daName == 'mag.f',
      );
      expect(anIn1.nameKey, equals('point_volt_a'));

      // Check AnIn4 has point_active_power
      final anIn4 = result.variables.firstWhere(
        (v) => v.lnName == 'GGIO1' && v.doName == 'AnIn4' && v.daName == 'mag.f',
      );
      expect(anIn4.nameKey, equals('point_active_power'));

      // Verify dynamic multilingual translations
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(spcso1.displayName, contains('1#进线开关'));
      expect(anIn1.displayName, contains('A相电压'));
      expect(anIn4.displayName, contains('有功功率'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(spcso1.displayName, contains('Feeder #1 Switch'));
      expect(anIn1.displayName, contains('Phase A Voltage'));
      expect(anIn4.displayName, contains('Active Power'));
    });

    test('SclParser parses GOOSE sample ICD with protection trip nameKey', () {
      final gooseFile = File('assets/examples/server_example_goose.icd');
      expect(gooseFile.existsSync(), isTrue);

      final result = SclParser.parse(gooseFile.readAsStringSync());
      final tripVar = result.variables.firstWhere(
        (v) => v.lnName == 'PTRC1' && v.doName == 'Tr' && v.daName == 'general',
      );
      expect(tripVar.nameKey, equals('point_protection_trip'));

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(tripVar.displayName, contains('保护总动作跳闸'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(tripVar.displayName, contains('Protection Trip Action'));
    });
  });

  group('IEC 61850 Model Internationalization Tests', () {
    test('DictionaryService and IecDesc switch description language with AppI18n', () {
      final dict = DictionaryService.instance;
      dict.loadSync();

      // 1. Logical Node lookup (supports CSWI and indexed CSWI1)
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      final lnZh = dict.lookupLn('CSWI1');
      expect(lnZh, isNotNull);
      expect(lnZh, contains('开关控制'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      final lnEn = dict.lookupLn('CSWI1');
      expect(lnEn, isNotNull);
      expect(lnEn, contains('Switch controller'));

      // 2. Data Object lookup (supports SPCSO1 and indexed SPCSO2 normalization)
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      final doZh = dict.lookupDo('SPCSO2');
      expect(doZh, isNotNull);
      expect(doZh, contains('单点可控状态输出'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      final doEn = dict.lookupDo('SPCSO2');
      expect(doEn, isNotNull);
      expect(doEn, contains('Single point'));
      expect(doEn, contains('status output'));

      // 3. CDC lookup
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      final cdcZh = dict.lookupCdc('MV');
      expect(cdcZh, isNotNull);
      expect(cdcZh, contains('测量值'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      final cdcEn = dict.lookupCdc('MV');
      expect(cdcEn, isNotNull);
      expect(cdcEn?.toLowerCase(), contains('measured value'));
    });

    test('ClientVariableModel translates legacy Chinese name and desc dynamically across locales', () {
      // Variable with Chinese name and NO explicit nameKey
      final vSwitch = ClientVariableModel(
        reference: 'IED1/CTRL/GGIO1.SPCSO1.stVal',
        iedName: 'IED1',
        ldInst: 'CTRL',
        lnName: 'GGIO1',
        doName: 'SPCSO1',
        daName: 'stVal',
        fc: FunctionalConstraint.st,
        type: IecBasicType.boolean,
        name: '1#进线开关',
      );

      // In Chinese, shows Chinese name
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(vSwitch.displayName, contains('1#进线开关'));

      // In English, translates Chinese name to English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(vSwitch.displayName, contains('Feeder #1 Switch'));

      // In Japanese, translates Chinese name to Japanese
      AppI18n.instance.setLanguage(AppLanguage.jaJP);
      expect(vSwitch.displayName, contains('1#フィーダ開閉器'));

      // Variable with Chinese desc and NO name/nameKey
      final vPower = ClientVariableModel(
        reference: 'IED1/MEAS/MMXU1.TotW.mag.f',
        iedName: 'IED1',
        ldInst: 'MEAS',
        lnName: 'MMXU1',
        doName: 'TotW',
        daName: 'mag.f',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.float32,
        desc: '有功功率',
      );

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(vPower.displayName, contains('有功功率'));
      expect(vPower.displayDesc, contains('有功功率'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(vPower.displayName, contains('Active Power'));
      expect(vPower.displayDesc, contains('Active Power'));
    });

    test('ConnectionConfig with legacy Chinese name translates across locales', () {
      final conn = ConnectionConfig(
        id: 'conn_custom_substation',
        name: '变电站间隔控制器',
      );

      // In Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(conn.displayName, contains('变电站间隔控制器'));

      // In English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(conn.displayName, contains('Substation Bay Controller'));

      // In Japanese
      AppI18n.instance.setLanguage(AppLanguage.jaJP);
      expect(conn.displayName, contains('変電所ベイコントローラ'));

      // In German
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(conn.displayName, contains('Umspannwerk-Feldleitgerät'));
    });

    test('SclLN and SclDOType displayDesc provide localized descriptions from DictionaryService', () {
      final ln = SclLN(lnClass: 'MMXU', lnType: 'MMXU_Type');
      final doElem = SclDOTypeElement(
        name: 'TotW',
        type: 'MV',
        fc: FunctionalConstraint.mx,
        bType: IecBasicType.structure,
      );

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(ln.displayDesc, contains('测量'));
      expect(doElem.displayDesc, contains('总有功功率'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(ln.displayDesc, contains('Measurement'));
      expect(doElem.displayDesc, contains('Total active power'));
    });
  });
}
