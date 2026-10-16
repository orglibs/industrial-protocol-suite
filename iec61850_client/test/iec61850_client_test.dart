import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:iec61850_client/src/models/client_variable_model.dart';
import 'package:iec61850_client/src/models/connection_config.dart';
import 'package:iec61850_client/src/models/scl_models.dart';
import 'package:iec61850_client/src/models/scl_parser.dart';
import 'package:iec61850_client/src/protocol/goose_receiver.dart';
import 'package:iec61850_client/src/protocol/iso_acse_mms.dart';
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
  });
}
