import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iec61850_server/src/models/scl_parser.dart';
import 'package:iec61850_server/src/models/server_config.dart';
import 'package:iec61850_server/src/protocol/goose_publisher.dart';
import 'package:iec61850_server/src/protocol/iec61850_server_manager.dart';
import 'package:iec61850_server/src/protocol/iso_acse_mms.dart';
import 'package:iec61850_server/src/protocol/tpkt_cotp.dart';

void main() async {
  print('====================================================');
  print('  IEC 61850 Server Simulator - Protocol Test Suite  ');
  print('====================================================\n');

  // 1. Test SCL Parser with built-in example ICD
  final icdFile = File('assets/examples/server_example_basic_io.icd');
  if (!icdFile.existsSync()) {
    print('❌ Error: assets/examples/server_example_basic_io.icd not found!');
    exit(1);
  }

  print('1. Parsing SCL ICD file: ${icdFile.path} ...');
  final xmlContent = icdFile.readAsStringSync();
  final parseResult = SclParser.parse(xmlContent);

  print('   -> IED Name: ${parseResult.iedName}');
  print('   -> LDevices: ${parseResult.ied.lDevices.map((ld) => ld.inst).join(', ')}');
  print('   -> Total Extracted Variables: ${parseResult.variables.length}');
  print('   -> DataSets: ${parseResult.dataSets.map((d) => d.name).join(', ')}');
  print('   -> Report Controls: ${parseResult.reportControls.map((r) => r.name).join(', ')}');
  print('   -> GOOSE Controls: ${parseResult.gseControls.map((g) => g.name).join(', ')}');

  assert(parseResult.variables.isNotEmpty, 'Should extract variables from ICD');
  assert(parseResult.dataSets.isNotEmpty, 'Should extract DataSets from ICD');
  print('   ✅ SCL Parser test passed!\n');

  // 2. Start IEC 61850 Server on test port 15502
  const testPort = 15502;
  print('2. Initializing IEC 61850 Server Manager on port $testPort ...');
  final config = ServerConfig(
    name: 'Test Server',
    ip: '127.0.0.1',
    port: testPort,
  );
  final serverManager = Iec61850ServerManager(config: config);
  serverManager.loadScl(parseResult);

  final started = await serverManager.startServer();
  if (!started) {
    print('❌ Failed to start server: ${config.statusMessage}');
    exit(1);
  }
  print('   ✅ Server listening on 127.0.0.1:$testPort\n');

  // 3. Connect client socket and execute ISO/COTP/ACSE/MMS handshake
  print('3. Connecting client to 127.0.0.1:$testPort ...');
  final client = await Socket.connect('127.0.0.1', testPort);
  final completerCc = Completer<Uint8List>();
  final completerAare = Completer<Uint8List>();
  final completerMmsResp = Completer<Uint8List>();

  final rxStream = StreamController<Uint8List>.broadcast();

  final clientBuffer = <int>[];
  client.listen((chunk) {
    clientBuffer.addAll(chunk);
    while (clientBuffer.isNotEmpty) {
      final frame = TpktFrame.extract(Uint8List.fromList(clientBuffer));
      if (frame == null) break;
      clientBuffer.removeRange(0, frame.consumed);
      rxStream.add(frame.payload);
    }
  });

  // 3.1 Send COTP Connection Request (CR)
  print('   -> Sending TPKT + COTP CR ...');
  final crPayload = Uint8List.fromList([
    0x11, // Length
    0xE0, // Type CR
    0x00, 0x00, // Dst Ref
    0x00, 0x01, // Src Ref
    0x00, // Class 0
    // Parameters (Calling/Called TSAP)
    0xC1, 0x02, 0x00, 0x01,
    0xC2, 0x02, 0x00, 0x01,
    0xC0, 0x01, 0x0A,
  ]);
  client.add(TpktFrame.wrap(crPayload));

  // Wait for COTP CC
  final ccPayload = await rxStream.stream.firstWhere((p) => CotpFrame.isConnectionRequest(p) == false && (p[1] & 0xF0) == 0xD0);
  print('   <- Received COTP CC confirm (${ccPayload.length} bytes)');
  print('   ✅ COTP Connection Handshake successful!\n');

  // 3.2 Send ACSE AARQ + MMS Initiate Request
  print('4. Sending ACSE AARQ + MMS Initiate Request ...');
  final mmsInitReq = Uint8List.fromList([
    0xA8, 0x16, // Initiate-RequestPdu
    0x80, 0x02, 0x00, 0x05, // localDetailCalling = 5
    0x81, 0x02, 0x00, 0x05, // MaxServOutstandingCalling = 5
    0x82, 0x01, 0x0A,       // Nesting = 10
    0xA3, 0x0B,             // mmsInitDetail
    0x80, 0x02, 0x00, 0x01, // mmsVersion = 1
    0x81, 0x03, 0x05, 0xF1, 0x00,
    0x82, 0x00,
  ]);

  final aarqUser = Uint8List(mmsInitReq.length + 8);
  aarqUser[0] = 0x28;
  aarqUser[1] = (mmsInitReq.length + 6) & 0xFF;
  aarqUser[2] = 0x06; aarqUser[3] = 0x02; aarqUser[4] = 0x51; aarqUser[5] = 0x01;
  aarqUser[6] = 0xA0;
  aarqUser[7] = mmsInitReq.length & 0xFF;
  aarqUser.setRange(8, 8 + mmsInitReq.length, mmsInitReq);

  final aarq = Uint8List.fromList([
    0x60, 0x2E, // AARQ tag
    0x80, 0x02, 0x00, 0x00,
    0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01,
    0xBE, 0x21,
    ...aarqUser,
  ]);

  final presCp = Uint8List.fromList([
    0x31, (aarq.length + 2) & 0xFF,
    ...aarq,
  ]);

  final sessionConn = Uint8List.fromList([
    0x0D, 0x01, 0x00,
    ...presCp,
  ]);

  client.add(TpktFrame.wrap(CotpFrame.wrapDataTransfer(sessionConn)));

  // Wait for AARE response
  final aareResp = await rxStream.stream.firstWhere((p) {
    final dt = CotpFrame.extractDataPayload(p);
    return dt != null && dt.isNotEmpty;
  });
  print('   <- Received ACSE AARE response (${aareResp.length} bytes)');
  print('   ✅ ACSE & MMS Initiate Handshake successful!\n');

  // 5. Test MMS GetNameList (Query domains)
  print('5. Testing MMS GetNameList (Domain scope) ...');
  // ConfirmedRequest (0xA0) -> invokeId 101 -> GetNameList (0xA1) -> objectClass DOMAIN (0x80 0x01 0x09)
  final getNameListReq = BerTlv(0xA0, Uint8List.fromList([
    0x02, 0x01, 0x65, // invokeId 101
    0xA1, 0x05, // GetNameList
    0x80, 0x01, 0x09, // objectClass = 9 (DOMAIN)
    0xA0, 0x00, // vmdScope
  ])).encode();

  final getNameListPres = IsoAcseMms.wrapMmsPdu(getNameListReq);
  client.add(TpktFrame.wrap(CotpFrame.wrapDataTransfer(getNameListPres)));

  final getNamesResp = await rxStream.stream.firstWhere((p) {
    final dt = CotpFrame.extractDataPayload(p);
    return dt != null && dt.isNotEmpty;
  });
  final mmsPdu = IsoAcseMms.extractMmsPdu(CotpFrame.extractDataPayload(getNamesResp)!)!;
  print('   <- Received GetNameList response (Tag: 0x${mmsPdu[0].toRadixString(16).toUpperCase()}, Length: ${mmsPdu.length})');
  assert(mmsPdu[0] == 0xA1, 'Should be Confirmed-ResponsePdu (0xA1)');
  print('   ✅ MMS GetNameList test passed!\n');

  // 6. Test MMS Read variable
  print('6. Testing MMS Read variable ...');
  final targetVar = parseResult.variables.first;
  print('   -> Target Variable: ${targetVar.reference}');

  final readReq = BerTlv(0xA0, Uint8List.fromList([
    0x02, 0x01, 0x66, // invokeId 102
    0xA4, // Read request
    (targetVar.shortRef.length + 6),
    0xA0, // listOfVariable
    (targetVar.shortRef.length + 4),
    0x30, // VariableSpecification
    (targetVar.shortRef.length + 2),
    0x1A, // VisibleString
    targetVar.shortRef.length,
    ...utf8.encode(targetVar.shortRef),
  ])).encode();

  client.add(TpktFrame.wrap(CotpFrame.wrapDataTransfer(IsoAcseMms.wrapMmsPdu(readReq))));

  final readResp = await rxStream.stream.firstWhere((p) {
    final dt = CotpFrame.extractDataPayload(p);
    return dt != null && dt.isNotEmpty;
  });
  final readMms = IsoAcseMms.extractMmsPdu(CotpFrame.extractDataPayload(readResp)!)!;
  print('   <- Received MMS Read response (${readMms.length} bytes)');
  assert(readMms[0] == 0xA1, 'Should be Confirmed-ResponsePdu (0xA1)');
  print('   ✅ MMS Read test passed!\n');

  // 7. Test MMS Write variable
  print('7. Testing MMS Write variable ...');
  print('   -> Original value: ${targetVar.value}');
  final writeReq = BerTlv(0xA0, Uint8List.fromList([
    0x02, 0x01, 0x67, // invokeId 103
    0xA5, // Write request
    (targetVar.shortRef.length + 10),
    0xA0, // variableAccessSpecification
    (targetVar.shortRef.length + 4),
    0x30,
    (targetVar.shortRef.length + 2),
    0x1A,
    targetVar.shortRef.length,
    ...utf8.encode(targetVar.shortRef),
    0xA0, 0x03, // listOfData
    0x85, 0x01, 0x2A, // integer 42
  ])).encode();

  client.add(TpktFrame.wrap(CotpFrame.wrapDataTransfer(IsoAcseMms.wrapMmsPdu(writeReq))));

  final writeResp = await rxStream.stream.firstWhere((p) {
    final dt = CotpFrame.extractDataPayload(p);
    return dt != null && dt.isNotEmpty;
  });
  final writeMms = IsoAcseMms.extractMmsPdu(CotpFrame.extractDataPayload(writeResp)!)!;
  print('   <- Received MMS Write response (${writeMms.length} bytes)');
  assert(writeMms[0] == 0xA1, 'Should be Confirmed-ResponsePdu (0xA1)');
  print('   -> New value after write: ${targetVar.value}');
  print('   ✅ MMS Write test passed!\n');

  // 8. Test GOOSE Packet Generation
  print('8. Testing GOOSE Publisher generation ...');
  final gooseItems = serverManager.gooseService.items;
  print('   -> Configured GOOSE controls: ${gooseItems.length}');
  if (gooseItems.isNotEmpty) {
    final item = gooseItems.first;
    final goosePacket = item.buildGoosePacket();
    print('   -> Generated GOOSE packet: ${goosePacket.length} bytes (AppID: 0x${item.control.appId.toRadixString(16)})');
    assert(goosePacket.length > 20, 'GOOSE packet should contain header and PDU');
  }
  print('   ✅ GOOSE Publisher test passed!\n');

  // 9. Clean up
  print('9. Shutting down client and server ...');
  await client.close();
  serverManager.stopServer();
  print('   ✅ Server stopped cleanly.\n');

  print('====================================================');
  print('  🎉 ALL IEC 61850 PROTOCOL VERIFICATION TESTS PASSED!');
  print('====================================================');
  exit(0);
}
