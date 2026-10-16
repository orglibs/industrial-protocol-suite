import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:iec61850_server/src/models/scl_models.dart';
import 'package:iec61850_server/src/models/scl_parser.dart';
import 'package:iec61850_server/src/models/server_config.dart';
import 'package:iec61850_server/src/models/server_variable_model.dart';
import 'package:iec61850_server/src/models/simulation_config.dart';
import 'package:iec61850_server/src/protocol/goose_publisher.dart';
import 'package:iec61850_server/src/protocol/iec61850_server_engine.dart';
import 'package:iec61850_server/src/protocol/iso_acse_mms.dart';
import 'package:iec61850_server/src/protocol/tpkt_cotp.dart';

void main() {
  group('SCL Parser Tests', () {
    test('Parse all example ICD files', () {
      final examplesDir = Directory('assets/examples');
      expect(examplesDir.existsSync(), isTrue);

      final icdFiles = examplesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.icd')).toList();
      expect(icdFiles.isNotEmpty, isTrue);

      for (final file in icdFiles) {
        final xml = file.readAsStringSync();
        final res = SclParser.parse(xml);
        expect(res.iedName.isNotEmpty, isTrue, reason: 'IED name in ${file.path}');
        expect(res.variables.isNotEmpty, isTrue, reason: 'Variables in ${file.path}');
      }
    });

    test('Parse Control ICD and verify CSWI / XCBR', () {
      final file = File('assets/examples/server_example_control.icd');
      expect(file.existsSync(), isTrue);

      final res = SclParser.parse(file.readAsStringSync());
      expect(res.variables.any((v) => v.doName.contains('SPCSO') || v.lnName.contains('GGIO')), isTrue);
    });

    test('Parse GOOSE ICD and verify GSEControls', () {
      final file = File('assets/examples/server_example_goose.icd');
      expect(file.existsSync(), isTrue);

      final res = SclParser.parse(file.readAsStringSync());
      expect(res.gseControls.isNotEmpty, isTrue);
      expect(res.gseControls.first.name.isNotEmpty, isTrue);
    });
  });

  group('TPKT & COTP Protocol Framing', () {
    test('TPKT wrap and extract', () {
      final payload = Uint8List.fromList([0x11, 0x22, 0x33, 0x44]);
      final wrapped = TpktFrame.wrap(payload);

      expect(wrapped.length, equals(4 + payload.length));
      expect(wrapped[0], equals(3)); // Version 3
      expect(wrapped[1], equals(0)); // Reserved

      final extracted = TpktFrame.extract(wrapped);
      expect(extracted, isNotNull);
      expect(extracted!.payload, equals(payload));
      expect(extracted.consumed, equals(wrapped.length));
    });

    test('COTP Connection Request & Confirm', () {
      final cr = Uint8List.fromList([0x06, CotpFrame.typeCr, 0x00, 0x00, 0x00, 0x01, 0x00]);
      expect(CotpFrame.isConnectionRequest(cr), isTrue);

      final cc = CotpFrame.buildConnectionConfirm(dstRef: 0x0002, srcRef: 0x0001);
      expect(cc[1], equals(CotpFrame.typeCc));
      expect(CotpFrame.isConnectionRequest(cc), isFalse);

      final dt = CotpFrame.wrapDataTransfer(Uint8List.fromList([0xAA, 0xBB]));
      expect(dt[1], equals(CotpFrame.typeDt));
      final payload = CotpFrame.extractDataPayload(dt);
      expect(payload, equals(Uint8List.fromList([0xAA, 0xBB])));
    });
  });

  group('ASN.1 BER & MMS Codec', () {
    test('MMS Value Encoder for float32', () {
      final v = ServerVariableModel(
        reference: 'IED/LD/LN.DO.DA',
        iedName: 'IED',
        ldInst: 'LD',
        lnName: 'LN',
        doName: 'DO',
        daName: 'DA',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.float32,
        initialValue: 50.5,
      );

      final encoded = MmsValueEncoder.encodeVariable(v);
      expect(encoded[0], equals(0x87)); // Float tag
      expect(encoded.length, equals(7)); // Tag + Len + Format(1) + 4-byte float
    });

    test('MMS Value Encoder for boolean & integer', () {
      final vBool = ServerVariableModel(
        reference: 'IED/LD/LN.DO.DA',
        iedName: 'IED',
        ldInst: 'LD',
        lnName: 'LN',
        doName: 'DO',
        daName: 'DA',
        fc: FunctionalConstraint.st,
        type: IecBasicType.boolean,
        initialValue: true,
      );
      final encBool = MmsValueEncoder.encodeVariable(vBool);
      expect(encBool[0], equals(0x83)); // Boolean tag
      expect(encBool[2], equals(0xFF));

      final vInt = ServerVariableModel(
        reference: 'IED/LD/LN.DO.DA',
        iedName: 'IED',
        ldInst: 'LD',
        lnName: 'LN',
        doName: 'DO',
        daName: 'DA',
        fc: FunctionalConstraint.st,
        type: IecBasicType.int32,
        initialValue: 1234,
      );
      final encInt = MmsValueEncoder.encodeVariable(vInt);
      expect(encInt[0], equals(0x85)); // Integer tag
    });
  });

  group('Simulation Waveforms', () {
    test('Sine wave generation', () {
      final cfg = SimulationConfig(
        enabled: true,
        waveType: EaseWaveType.sine,
        min: 0,
        max: 100,
        durationMs: 1000,
      );

      final v0 = cfg.compute(0.0);
      final v50 = cfg.compute(0.5);
      final v100 = cfg.compute(1.0);

      expect(v0, closeTo(0.0, 1.0));
      expect(v50, closeTo(100.0, 1.0));
      expect(v100, closeTo(0.0, 1.0));
    });

    test('Linear counter increment', () {
      final cfg = SimulationConfig(
        enabled: true,
        waveType: EaseWaveType.increment,
        min: 10,
        max: 20,
        step: 2,
      );

      final next1 = cfg.compute(0.1, 10.0);
      expect(next1, equals(12.0));

      final wrap = cfg.compute(0.9, 20.0);
      expect(wrap, equals(10.0));
    });
  });

  group('Server Engine Operations', () {
    test('Read and write variable via engine', () {
      final config = ServerConfig();
      final engine = Iec61850ServerEngine(config: config);

      final file = File('assets/examples/server_example_basic_io.icd');
      final res = SclParser.parse(file.readAsStringSync());
      engine.loadScl(res);

      expect(engine.allVariables.isNotEmpty, isTrue);
      final testVar = engine.allVariables.first;

      // Find variable
      final found = engine.findVariable(testVar.shortRef);
      expect(found, isNotNull);
      expect(found!.reference, equals(testVar.reference));
    });
  });
}
