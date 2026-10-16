import 'dart:async';
import 'dart:io';

import 'package:iec61850_client/src/models/connection_config.dart';
import 'package:iec61850_client/src/models/dictionary_service.dart';
import 'package:iec61850_client/src/models/scl_parser.dart';
import 'package:iec61850_client/src/protocol/iec61850_client_engine.dart';

void main(List<String> args) async {
  print('================================================================');
  print('       IEC 61850 Client Simulator - Standalone CLI Engine       ');
  print('          (MMS / TPKT / COTP / ACSE / GOOSE / SCL ICD)          ');
  print('================================================================\n');

  if (args.contains('--help') || args.contains('-h')) {
    print('Usage: dart run bin/client.dart [options]');
    print('Options:');
    print('  --ip <address>        Server IP address (default: 127.0.0.1)');
    print('  --port <port>         Server TCP port (default: 102, or 10102 / 15502)');
    print('  --scl <path>          Path to SCL / ICD file (default: assets/examples/server_example_basic_io.icd)');
    print('  --discover            Perform online model discovery upon connecting');
    print('  --help, -h            Show this help message\n');
    exit(0);
  }

  String ip = '127.0.0.1';
  int port = 102;
  String sclPath = 'assets/examples/server_example_basic_io.icd';
  bool doDiscover = false;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--ip' && i + 1 < args.length) ip = args[++i];
    if (args[i] == '--port' && i + 1 < args.length) port = int.tryParse(args[++i]) ?? 102;
    if (args[i] == '--scl' && i + 1 < args.length) sclPath = args[++i];
    if (args[i] == '--discover') doDiscover = true;
  }

  await DictionaryService.instance.load();

  final config = ConnectionConfig(
    id: 'cli_client',
    name: 'CLI Client -> $ip:$port',
    ip: ip,
    port: port,
    boundSclPath: sclPath,
  );

  final engine = Iec61850ClientEngine(config: config);

  final sclFile = File(sclPath);
  if (sclFile.existsSync()) {
    print('Loading offline SCL model: $sclPath ...');
    final res = SclParser.parse(sclFile.readAsStringSync());
    engine.bindSclModel(res);
    print('Loaded ${res.variables.length} variables, ${res.dataSets.length} datasets, ${res.reportControls.length} RCBs.\n');
  }

  print('Connecting to IEC 61850 Server at $ip:$port ...');
  final ok = await engine.connect();
  if (!ok) {
    print('❌ Connection failed: ${config.statusMessage}');
    exit(1);
  }

  print('✅ Connected successfully to $ip:$port (COTP & ACSE/MMS handshake OK)');

  if (doDiscover) {
    print('Performing online model discovery via MMS GetNameList ...');
    final ok = await engine.discoverOnlineModel();
    if (ok) {
      print('Discovered ${engine.allVariables.length} data variables dynamically!\n');
    } else {
      print('Online discovery failed or returned no domains.\n');
    }
  }

  // Periodic status display
  Timer.periodic(const Duration(seconds: 3), (_) {
    stdout.write('\r[Client Status] Connected: ${engine.isConnected} | TX: ${config.txCount} | RX: ${config.rxCount} | Monitored: ${engine.allVariables.length}   ');
  });

  ProcessSignal.sigint.watch().listen((_) {
    print('\nDisconnecting...');
    engine.disconnect();
    print('Goodbye!');
    exit(0);
  });
}
