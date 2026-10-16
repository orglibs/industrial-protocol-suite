import 'dart:async';
import 'dart:io';

import 'package:iec61850_server/src/models/scl_parser.dart';
import 'package:iec61850_server/src/models/server_config.dart';
import 'package:iec61850_server/src/protocol/iec61850_server_manager.dart';

void main(List<String> args) async {
  print('================================================================');
  print('       IEC 61850 Server Simulator - Standalone CLI Engine       ');
  print('          (MMS / TPKT / COTP / ACSE / GOOSE / SCL ICD)          ');
  print('================================================================\n');

  if (args.contains('--help') || args.contains('-h')) {
    print('Usage: dart run bin/server.dart [options]');
    print('Options:');
    print('  --ip <address>        IP address to bind (default: 0.0.0.0)');
    print('  --port <port>         TCP port to listen (default: 102, or 10102 for non-root)');
    print('  --scl <path>          Path to SCL / ICD file (default: assets/examples/server_example_basic_io.icd)');
    print('  --dir <path>          MMS file transfer directory');
    print('  --help, -h            Show this help message\n');
    exit(0);
  }

  String ip = '0.0.0.0';
  int port = 102;
  String sclPath = 'assets/examples/server_example_basic_io.icd';
  String? fileDir;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--ip' && i + 1 < args.length) ip = args[++i];
    if (args[i] == '--port' && i + 1 < args.length) port = int.tryParse(args[++i]) ?? 102;
    if (args[i] == '--scl' && i + 1 < args.length) sclPath = args[++i];
    if (args[i] == '--dir' && i + 1 < args.length) fileDir = args[++i];
  }

  final sclFile = File(sclPath);
  if (!sclFile.existsSync()) {
    print('⚠️ SCL file "$sclPath" not found. Falling back to built-in basic I/O ICD.');
    sclPath = 'assets/examples/server_example_basic_io.icd';
  }

  print('Loading SCL model from: $sclPath ...');
  final xmlContent = File(sclPath).readAsStringSync();
  final parseResult = SclParser.parse(xmlContent);

  print('IED: ${parseResult.iedName}');
  print('Logical Devices: ${parseResult.ied.lDevices.map((ld) => ld.inst).join(', ')}');
  print('Variables Loaded: ${parseResult.variables.length}');
  print('DataSets: ${parseResult.dataSets.length}');
  print('Report Controls: ${parseResult.reportControls.length}');
  print('GOOSE Controls: ${parseResult.gseControls.length}');

  final config = ServerConfig(
    name: 'IEC 61850 Server [${parseResult.iedName}]',
    ip: ip,
    port: port,
    sclFilePath: sclPath,
    fileTransferDirectory: fileDir,
  );

  final manager = Iec61850ServerManager(config: config);
  manager.loadScl(parseResult);

  print('\nStarting server on $ip:$port ...');
  final started = await manager.startServer();
  if (!started) {
    if (port == 102) {
      print('\n⚠️ Port 102 requires root permissions on Linux.');
      print('Retrying automatically on non-privileged port 10102 ...');
      config.port = 10102;
      final retry = await manager.startServer();
      if (!retry) {
        print('❌ Failed to start on port 10102: ${config.statusMessage}');
        exit(1);
      }
    } else {
      print('❌ Start failed: ${config.statusMessage}');
      exit(1);
    }
  }

  print('✅ IEC 61850 Server running on ${config.ip}:${config.port}!');
  print('Press Ctrl+C to terminate server.\n');

  Timer.periodic(const Duration(seconds: 3), (t) {
    stdout.write('\r[Status] Clients: ${manager.clientCount} | RX: ${config.rxCount} | TX: ${config.txCount} | GOOSE Items: ${manager.gooseService.items.length}   ');
  });

  ProcessSignal.sigint.watch().listen((signal) {
    print('\nStopping server...');
    manager.stopServer();
    print('Server stopped. Goodbye!');
    exit(0);
  });
}
