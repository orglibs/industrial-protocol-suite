import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_client/src/client/workspace_storage.dart';
import 'package:iec104_client/src/models/connection_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IEC104 Client Multi-Connection Configuration Tests', () {
    test('Default connections contain default, backup, and ring connections', () {
      final defaultList = Iec104ClientConnectionConfig.createDefaultConnections();
      expect(defaultList.length, equals(3));

      expect(defaultList[0].nameKey, equals('preset_conn_iec104_default'));
      expect(defaultList[0].port, equals(2404));
      expect(defaultList[0].stations.length, greaterThanOrEqualTo(1));

      expect(defaultList[1].nameKey, equals('preset_conn_iec104_backup'));
      expect(defaultList[1].port, equals(2405));

      expect(defaultList[2].nameKey, equals('preset_conn_iec104_ring'));
      expect(defaultList[2].port, equals(2406));
    });

    test('Connection config json serialization and deserialization retains all fields', () {
      final config = Iec104ClientConnectionConfig(
        id: 'conn_test_01',
        name: 'SCADA Master Line A',
        host: '10.20.30.40',
        port: 24040,
        defaultCa: 5,
        t0: 35,
        t1: 20,
        t2: 12,
        t3: 25,
        k: 16,
        w: 10,
        cotSize: 2,
        caSize: 2,
        ioaSize: 3,
        autoStartDt: false,
        autoGeneralInterrogation: true,
      );

      final json = config.toJson();
      final restored = Iec104ClientConnectionConfig.fromJson(json);

      expect(restored.id, equals('conn_test_01'));
      expect(restored.name, equals('SCADA Master Line A'));
      expect(restored.host, equals('10.20.30.40'));
      expect(restored.port, equals(24040));
      expect(restored.defaultCa, equals(5));
      expect(restored.t0, equals(35));
      expect(restored.t1, equals(20));
      expect(restored.t2, equals(12));
      expect(restored.t3, equals(25));
      expect(restored.k, equals(16));
      expect(restored.w, equals(10));
      expect(restored.cotSize, equals(2));
      expect(restored.caSize, equals(2));
      expect(restored.ioaSize, equals(3));
      expect(restored.autoStartDt, isFalse);
      expect(restored.autoGeneralInterrogation, isTrue);
    });

    test('WorkspaceStorage save and load multiple connections preserves configs and stations', () async {
      final conn1 = Iec104ClientConnectionConfig(
        id: 'conn_alpha',
        name: 'Primary Line',
        host: '192.168.10.1',
        port: 2404,
      );
      final conn2 = Iec104ClientConnectionConfig(
        id: 'conn_beta',
        name: 'Secondary Line',
        host: '192.168.10.2',
        port: 2405,
      );

      final connections = [conn1, conn2];

      final saveOk = await WorkspaceStorage.saveConnections(connections);
      expect(saveOk, isTrue);

      final loadedConnections = await WorkspaceStorage.loadConnections();
      expect(loadedConnections.length, equals(2));
      expect(loadedConnections[0].id, equals('conn_alpha'));
      expect(loadedConnections[0].host, equals('192.168.10.1'));
      expect(loadedConnections[1].id, equals('conn_beta'));
      expect(loadedConnections[1].host, equals('192.168.10.2'));
    });

    test('WorkspaceStorage backward compatibility parses single-connection workspace', () async {
      final legacyJson = {
        'version': '1.0.0',
        'savedAt': DateTime.now().toIso8601String(),
        'connection': {
          'host': '172.16.0.10',
          'port': 2404,
          'defaultCommonAddress': 1,
          't0': 30,
          't1': 15,
          't2': 10,
          't3': 20,
          'k': 12,
          'w': 8,
          'cotSize': 2,
          'caSize': 2,
          'ioaSize': 3,
          'autoStartDt': true,
          'autoGI': true,
        },
        'stations': [
          {
            'commonAddress': 1,
            'name': 'Legacy Station 1',
            'points': [],
          }
        ]
      };

      // Write legacy json directly
      final filePath = WorkspaceStorage.getWorkspaceFilePath();
      final file = File(filePath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(legacyJson));

      // Load via loadConnections
      final loadedConnections = await WorkspaceStorage.loadConnections();
      expect(loadedConnections.isNotEmpty, isTrue);
      expect(loadedConnections.first.host, equals('172.16.0.10'));
      expect(loadedConnections.first.findStation(1)?.name, equals('Legacy Station 1'));
    });
  });
}
