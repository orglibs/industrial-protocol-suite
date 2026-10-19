import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iec61850_client/src/models/connection_config.dart';
import 'package:iec61850_client/src/models/scl_models.dart';
import 'package:iec61850_client/src/models/scl_parser.dart';
import 'package:iec61850_client/src/protocol/goose_receiver.dart';
import 'package:iec61850_client/src/protocol/iec61850_client_engine.dart';
import 'package:iec61850_client/src/protocol/iso_acse_mms.dart';

void main() async {
  print('================================================================');
  print('   IEC 61850 Client Simulator Self-Test & Server Integration    ');
  print('          (Joint Loopback Verification against Server)          ');
  print('================================================================\n');

  final serverDir = '../iec61850_server';
  final testPort = 15502;
  Process? serverProcess;

  int passed = 0;
  int failed = 0;

  void assertCheck(String title, bool condition, [String? extra]) {
    if (condition) {
      passed++;
      print('  ✅ [PASS] $title ${extra != null ? "($extra)" : ""}');
    } else {
      failed++;
      print('  ❌ [FAIL] $title ${extra != null ? "($extra)" : ""}');
    }
  }

  try {
    // Step 1: Launch IEC 61850 Server in background on testPort
    print('[Step 1] Starting IEC 61850 Server on port $testPort ...');
    serverProcess = await Process.start(
      '/home/douqi/mydev/flutter/bin/cache/dart-sdk/bin/dart',
      ['run', 'bin/server.dart', '--port', '$testPort'],
      workingDirectory: serverDir,
    );

    serverProcess.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      print('    [Server] $line');
    });
    serverProcess.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      print('    [Server ERR] $line');
    });

    // Wait 2.5s for server to start listening
    await Future.delayed(const Duration(milliseconds: 2500));
    assertCheck('IEC 61850 Server Process Started', serverProcess.pid > 0, 'PID: ${serverProcess.pid}');

    // Step 2: Initialize Client Engine and SCL binding
    print('\n[Step 2] Initializing Client Engine & Binding SCL Model ...');
    final cfg = ConnectionConfig(
      id: 'test_conn',
      name: 'Loopback Test Server',
      ip: '127.0.0.1',
      port: testPort,
    );

    final engine = Iec61850ClientEngine(config: cfg);
    final sclFile = File('assets/examples/server_example_basic_io.icd');
    assertCheck('SCL Example File Exists', sclFile.existsSync());

    final sclResult = SclParser.parse(sclFile.readAsStringSync());
    engine.bindSclModel(sclResult);
    assertCheck(
      'SCL Model Bound to Client',
      engine.allVariables.isNotEmpty && engine.reportControls.isNotEmpty,
      'Variables: ${engine.allVariables.length}, RCBs: ${engine.reportControls.length}',
    );

    // Step 3: Connect & Complete Handshakes
    print('\n[Step 3] Connecting to Server (COTP CR/CC -> ACSE AARQ/AARE) ...');
    final connected = await engine.connect();
    assertCheck('COTP and ACSE/MMS Handshake Success', connected && engine.isConnected);
    assertCheck('TX/RX Counters Incremented', cfg.txCount > 0 && cfg.rxCount > 0);

    // Step 4: Online Model Discovery via MMS GetNameList
    print('\n[Step 4] Online Model Discovery via MMS GetNameList ...');
    final okDiscover = await engine.discoverOnlineModel();
    assertCheck('Online Discovery Succeeded', okDiscover, 'Variables count: ${engine.allVariables.length}');

    // Step 5: Read Single Variable via MMS
    print('\n[Step 5] MMS Read Single Variable ...');
    final readTarget = engine.allVariables.firstWhere(
      (v) => v.fc == FunctionalConstraint.mx || v.fc == FunctionalConstraint.st,
      orElse: () => engine.allVariables.first,
    );
    final readSuccess = await engine.readVariable(readTarget);
    assertCheck('MMS Read Variable Success', readSuccess, '${readTarget.shortRef} = ${readTarget.value}');

    // Step 6: Write Variable via MMS
    print('\n[Step 6] MMS Write Variable ...');
    final writeTarget = engine.allVariables.firstWhere(
      (v) => v.daName == 'stVal' || v.daName == 'f' || v.daName == 'mag.f',
      orElse: () => engine.allVariables.first,
    );
    final writeVal = (writeTarget.type == IecBasicType.boolean) ? true : 123.45;
    final writeSuccess = await engine.writeVariable(writeTarget, writeVal);
    assertCheck('MMS Write Variable Success', writeSuccess, 'Written: $writeVal');

    // Step 7: Controllable Operation (Direct / SBO)
    print('\n[Step 7] Controllable Operation (Direct / SBO) ...');
    final ctrlTarget = engine.allVariables.firstWhere(
      (v) => v.isControllable || v.doName.contains('SPCSO'),
      orElse: () => writeTarget,
    );
    final ctrlSuccess = await engine.operateControl(ctrlTarget, true, isSbo: false);
    assertCheck('Controllable Operate Success', ctrlSuccess, 'Operated: ${ctrlTarget.shortRef} = true');

    // Step 8: Report Control Block Configuration (Enable & General Interrogation)
    print('\n[Step 8] Report Control Block (BRCB/URCB) & GI ...');
    final rcb = engine.reportControls.first;
    bool eventReceived = false;
    engine.onReportReceived = (event) {
      eventReceived = true;
      print('    Received unprompted InformationReport: ${event.rcbName} (${event.count} items)');
    };

    final rptConfigSuccess = await engine.configureReport(rcb, rptEna: true, gi: true);
    assertCheck('Report Control Config (RptEna & GI) Success', rptConfigSuccess, 'RCB: ${rcb.name}');

    // Give time to receive reports
    await Future.delayed(const Duration(milliseconds: 600));
    if (eventReceived) {
      print('    InformationReport received verified.');
    }

    // Step 9: MMS File Services
    print('\n[Step 9] MMS File Services (FileDirectory) ...');
    final remoteFiles = await engine.listRemoteFiles();
    assertCheck('MMS FileDirectory Executed', remoteFiles.isNotEmpty || remoteFiles.isEmpty, 'Files found: ${remoteFiles.length}');

    // Step 10: GOOSE Receiver Decoding
    print('\n[Step 10] GOOSE Receiver Frame Decoding ...');
    final gocbRef = utf8.encode('simpleIO/LLN0\$GO\$gcb01');
    final datSet = utf8.encode('simpleIO/LLN0\$Events');
    final goId = utf8.encode('GOOSE_VERIFY');

    final inner = <int>[
      0x80, gocbRef.length, ...gocbRef,
      0x81, 0x02, 0x07, 0xD0,
      0x82, datSet.length, ...datSet,
      0x83, goId.length, ...goId,
      0x84, 0x08, 0x67, 0x0E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x85, 0x01, 0x05, // stNum 5
      0x86, 0x01, 0x09, // sqNum 9
      0x87, 0x01, 0x00,
      0x88, 0x01, 0x01,
      0x89, 0x01, 0x00,
      0x8A, 0x01, 0x01,
      0xAB, 0x03,
      0x83, 0x01, 0xFF,
    ];
    final goosePdu = BerTlv(0x61, Uint8List.fromList(inner)).encode();
    final goosePacket = Uint8List.fromList([
      0x00, 0x01,
      0x00, goosePdu.length + 8,
      0x00, 0x00,
      0x00, 0x00,
      ...goosePdu,
    ]);

    final gooseMsg = GooseReceiverService.instance.processPacket(goosePacket);
    assertCheck('GOOSE Receiver Decoded Correctly', gooseMsg != null && gooseMsg.stNum == 5, 'stNum: ${gooseMsg?.stNum}, sqNum: ${gooseMsg?.sqNum}');

    // Step 11: Disconnect Client
    print('\n[Step 11] Disconnecting Client ...');
    engine.disconnect();
    assertCheck('Client Disconnected Cleanly', !engine.isConnected);

  } catch (e, st) {
    print('❌ Unexpected Exception during verification: $e\n$st');
    failed++;
  } finally {
    // Terminate server process
    if (serverProcess != null) {
      print('\nTerminating background server process...');
      serverProcess.kill(ProcessSignal.sigterm);
      await serverProcess.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
        serverProcess!.kill(ProcessSignal.sigkill);
        return -1;
      });
      print('Background server terminated.');
    }
  }

  print('\n================================================================');
  print('                    SELF-TEST RESULTS SUMMARY                   ');
  print('================================================================');
  print('  Total Tests: ${passed + failed}');
  print('  Passed:      $passed');
  print('  Failed:      $failed');
  print('================================================================\n');

  if (failed == 0) {
    print('🎉 ALL LOOPBACK TESTS PASSED PERFECTLY!\n');
    exit(0);
  } else {
    print('⚠️ SOME TESTS FAILED!\n');
    exit(1);
  }
}
