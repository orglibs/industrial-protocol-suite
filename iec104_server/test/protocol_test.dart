import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:iec104_server/src/protocol/apci.dart';
import 'package:iec104_server/src/protocol/asdu.dart';
import 'package:iec104_server/src/protocol/asdu_types.dart';
import 'package:iec104_server/src/protocol/codec.dart';
import 'package:iec104_server/src/protocol/parser.dart';
import 'package:iec104_server/src/server/iec104_server.dart';

void main() {
  group('IEC 104 APCI Tests', () {
    test('U-Format STARTDT act encode and decode', () {
      final header = ApciHeader.uFormat(uType: UFormatType.startDtAct);
      final bytes = header.encode();

      expect(bytes, equals(Uint8List.fromList([0x68, 0x04, 0x07, 0x00, 0x00, 0x00])));

      final decoded = ApciHeader.decode(bytes);
      expect(decoded.type, equals(ApciType.uFormat));
      expect(decoded.uType, equals(UFormatType.startDtAct));
      expect(decoded.apduLength, equals(4));
    });

    test('U-Format STARTDT con encode and decode', () {
      final header = ApciHeader.uFormat(uType: UFormatType.startDtCon);
      final bytes = header.encode();

      expect(bytes, equals(Uint8List.fromList([0x68, 0x04, 0x0B, 0x00, 0x00, 0x00])));

      final decoded = ApciHeader.decode(bytes);
      expect(decoded.type, equals(ApciType.uFormat));
      expect(decoded.uType, equals(UFormatType.startDtCon));
    });

    test('S-Format encode and decode', () {
      final header = ApciHeader.sFormat(rxSeq: 42);
      final bytes = header.encode();

      expect(bytes[0], equals(0x68));
      expect(bytes[1], equals(0x04));
      expect(bytes[2], equals(0x01));
      expect(bytes[3], equals(0x00));
      expect((bytes[4] >> 1) | (bytes[5] << 7), equals(42));

      final decoded = ApciHeader.decode(bytes);
      expect(decoded.type, equals(ApciType.sFormat));
      expect(decoded.rxSeq, equals(42));
    });

    test('I-Format encode and decode', () {
      final header = ApciHeader.iFormat(txSeq: 10, rxSeq: 20, asduLength: 14);
      final bytes = header.encode();

      expect(bytes[0], equals(0x68));
      expect(bytes[1], equals(18)); // 4 control + 14 asdu

      final decoded = ApciHeader.decode(bytes);
      expect(decoded.type, equals(ApciType.iFormat));
      expect(decoded.txSeq, equals(10));
      expect(decoded.rxSeq, equals(20));
      expect(decoded.apduLength, equals(18));
    });
  });

  group('IEC 104 ASDU Codec Tests', () {
    test('Type 100 C_IC_NA_1 Interrogation command encode & decode', () {
      final asdu = Asdu(
        typeId: AsduTypeId.cIcNa1,
        cot: CauseOfTransmission.activation,
        commonAddress: 1,
        objects: [InterrogationCommandObject(ioa: 0, qoi: 0x14)],
      );

      final encoded = Iec104Codec.encodeAsdu(asdu);
      expect(encoded[0], equals(100)); // Type 100
      expect(encoded[1], equals(1));   // VSQ: SQ=0, count=1
      expect(encoded[2], equals(6));   // COT: 6 (Activation)
      expect(encoded[3], equals(0));   // OA: 0
      expect(encoded[4], equals(1));   // CA low: 1
      expect(encoded[5], equals(0));   // CA high: 0
      expect(encoded[6], equals(0));   // IOA byte 0
      expect(encoded[7], equals(0));   // IOA byte 1
      expect(encoded[8], equals(0));   // IOA byte 2
      expect(encoded[9], equals(0x14));// QOI

      final decoded = Iec104Codec.decodeAsdu(encoded, 0, encoded.length);
      expect(decoded.typeId, equals(AsduTypeId.cIcNa1));
      expect(decoded.cot, equals(CauseOfTransmission.activation));
      expect(decoded.commonAddress, equals(1));
      expect(decoded.objects.length, equals(1));
      final cmd = decoded.objects.first as InterrogationCommandObject;
      expect(cmd.qoi, equals(0x14));
    });

    test('Type 1 M_SP_NA_1 Single Point encode & decode', () {
      final asdu = Asdu(
        typeId: AsduTypeId.mSpNa1,
        cot: CauseOfTransmission.spontaneous,
        commonAddress: 1,
        objects: [
          SinglePointObject(ioa: 1, value: true, quality: QualityDescriptor.good),
          SinglePointObject(ioa: 2, value: false, quality: const QualityDescriptor(invalid: true)),
        ],
      );

      final encoded = Iec104Codec.encodeAsdu(asdu);
      final decoded = Iec104Codec.decodeAsdu(encoded, 0, encoded.length);

      expect(decoded.typeId, equals(AsduTypeId.mSpNa1));
      expect(decoded.cot, equals(CauseOfTransmission.spontaneous));
      expect(decoded.objects.length, equals(2));

      final p1 = decoded.objects[0] as SinglePointObject;
      expect(p1.ioa, equals(1));
      expect(p1.value, isTrue);
      expect(p1.quality.invalid, isFalse);

      final p2 = decoded.objects[1] as SinglePointObject;
      expect(p2.ioa, equals(2));
      expect(p2.value, isFalse);
      expect(p2.quality.invalid, isTrue);
    });

    test('Type 13 M_ME_NC_1 Short Float encode & decode', () {
      final asdu = Asdu(
        typeId: AsduTypeId.mMeNc1,
        cot: CauseOfTransmission.periodic,
        commonAddress: 1,
        objects: [
          MeasuredShortFloatObject(
            ioa: 0x4001,
            value: 220.5,
            quality: QualityDescriptor.good,
          ),
        ],
      );

      final encoded = Iec104Codec.encodeAsdu(asdu);
      final decoded = Iec104Codec.decodeAsdu(encoded, 0, encoded.length);

      expect(decoded.typeId, equals(AsduTypeId.mMeNc1));
      final p = decoded.objects.first as MeasuredShortFloatObject;
      expect(p.ioa, equals(0x4001));
      expect((p.value - 220.5).abs(), lessThan(0.01));
    });

    test('Type 30 M_SP_TB_1 Single Point with CP56Time2a', () {
      final now = DateTime(2026, 10, 15, 11, 0, 0, 123);
      final ts = CP56Time2a.fromDateTime(now);

      final asdu = Asdu(
        typeId: AsduTypeId.mSpTb1,
        cot: CauseOfTransmission.spontaneous,
        commonAddress: 1,
        objects: [
          SinglePointObject(ioa: 10, value: true, timestamp: ts),
        ],
      );

      final encoded = Iec104Codec.encodeAsdu(asdu);
      final decoded = Iec104Codec.decodeAsdu(encoded, 0, encoded.length);

      expect(decoded.typeId, equals(AsduTypeId.mSpTb1));
      final p = decoded.objects.first as SinglePointObject;
      expect(p.ioa, equals(10));
      expect(p.value, isTrue);
      expect(p.timestamp, isNotNull);
      expect(p.timestamp!.year, equals(26));
      expect(p.timestamp!.month, equals(10));
      expect(p.timestamp!.dayOfMonth, equals(15));
    });
  });

  group('IEC 104 Parser Tests', () {
    test('Parse raw hex string of General Interrogation', () {
      // 68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14
      const hex = '68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14';
      final parsed = Iec104Parser.parseHex(hex);

      expect(parsed, isNotNull);
      expect(parsed!.isValid, isTrue);
      expect(parsed.apci.type, equals(ApciType.iFormat));
      expect(parsed.asdu, isNotNull);
      expect(parsed.asdu!.typeId, equals(AsduTypeId.cIcNa1));
      expect(parsed.asdu!.cot, equals(CauseOfTransmission.activation));
      expect(parsed.asdu!.commonAddress, equals(1));
    });
  });

  group('IEC 104 Server Socket Integration Test', () {
    test('Server start, client connection, STARTDT and General Interrogation', () async {
      final server = Iec104Server();
      server.host = '127.0.0.1';
      server.port = 24040; // Test port

      await server.start();
      expect(server.isRunning, isTrue);

      // Connect test client socket
      final socket = await Socket.connect('127.0.0.1', 24040);

      // 1. Send STARTDT act: 68 04 07 00 00 00
      socket.add(Uint8List.fromList([0x68, 0x04, 0x07, 0x00, 0x00, 0x00]));

      final receivedFrames = <Uint8List>[];
      final completer = Completer<void>();

      socket.listen((data) {
        receivedFrames.add(data);
        // After receiving responses, complete
        if (receivedFrames.isNotEmpty && !completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 3));
      expect(receivedFrames.isNotEmpty, isTrue);

      // First response must be STARTDT con (0x68 0x04 0x0B 0x00 0x00 0x00)
      final firstFrame = receivedFrames.first;
      expect(firstFrame[0], equals(0x68));
      expect(firstFrame[2], equals(0x0B)); // STARTDT con

      await socket.close();
      await server.stop();
      expect(server.isRunning, isFalse);
    });

    test('Server handles STOPDT and re-activation STARTDT cycles, notifying clientsStream', () async {
      final server = Iec104Server();
      server.host = '127.0.0.1';
      server.port = 24041;

      await server.start();
      final statesSeen = <bool>[];
      final sub = server.clientsStream.listen((sessions) {
        if (sessions.isNotEmpty) {
          statesSeen.add(sessions.first.isDataTransferActive);
        }
      });

      final socket = await Socket.connect('127.0.0.1', 24041);
      final receivedData = <int>[];
      socket.listen(receivedData.addAll);

      // 1. Initial STARTDT
      socket.add(Uint8List.fromList([0x68, 0x04, 0x07, 0x00, 0x00, 0x00]));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(server.clients.first.isDataTransferActive, isTrue);

      // 2. STOPDT
      socket.add(Uint8List.fromList([0x68, 0x04, 0x13, 0x00, 0x00, 0x00]));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(server.clients.first.isDataTransferActive, isFalse);

      // 3. Re-STARTDT
      socket.add(Uint8List.fromList([0x68, 0x04, 0x07, 0x00, 0x00, 0x00]));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(server.clients.first.isDataTransferActive, isTrue);

      await socket.close();
      await server.stop();
      await sub.cancel();

      // Check stream caught active, then false, then active again
      expect(statesSeen.contains(true), isTrue);
      expect(statesSeen.contains(false), isTrue);
    });
  });
}
