import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_client/src/client/iec104_client.dart';
import 'package:iec104_client/src/client/station_data.dart';
import 'package:iec104_client/src/client/workspace_storage.dart';
import 'package:iec104_client/src/protocol/asdu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workspace Persistence Tests', () {
    test('Workspace export and import retains all configuration and stations', () {
      final client = Iec104Client();
      client.host = '192.168.1.100';
      client.port = 24040;
      client.k = 15;
      client.w = 10;
      client.t0 = 25;

      // Add station #2
      client.addStation(2, name: '220kV 变电站 #2');
      final st2 = client.getStation(2);
      st2.addPoint(ClientPointModel(
        commonAddress: 2,
        ioa: 101,
        typeId: AsduTypeId.mSpNa1,
        name: '201开关分合状态',
        value: true,
      ));
      st2.addPoint(ClientPointModel(
        commonAddress: 2,
        ioa: 16385,
        typeId: AsduTypeId.mMeNc1,
        name: '母线A相电压',
        value: 220.5,
      ));

      // Export workspace
      final json = client.exportWorkspace();
      expect(json['connection']['host'], equals('192.168.1.100'));
      expect(json['connection']['port'], equals(24040));
      expect(json['connection']['k'], equals(15));

      final stationList = json['stations'] as List;
      expect(stationList.length, equals(2));

      // Create brand new client and import
      final newClient = Iec104Client();
      newClient.importWorkspace(json);

      expect(newClient.host, equals('192.168.1.100'));
      expect(newClient.port, equals(24040));
      expect(newClient.stations.containsKey(2), isTrue);

      final restoredSt2 = newClient.getStation(2);
      expect(restoredSt2.name, equals('220kV 变电站 #2'));
      expect(restoredSt2.points.length, equals(2));
      expect(restoredSt2.getPoint(101)?.name, equals('201开关分合状态'));
      expect(restoredSt2.getPoint(101)?.value, equals(true));
      expect(restoredSt2.getPoint(16385)?.value, equals(220.5));
    });

    test('WorkspaceStorage save and load from disk works correctly', () async {
      final client = Iec104Client();
      client.host = '10.0.0.88';
      client.port = 2404;
      client.addStation(99, name: '测试专用变电站');
      final st = client.getStation(99);
      st.addPoint(ClientPointModel(
        commonAddress: 99,
        ioa: 50,
        typeId: AsduTypeId.mDpNa1,
        name: '双点遥信测试',
        value: 2,
      ));

      // Save to disk
      final saveOk = await client.saveWorkspace();
      expect(saveOk, isTrue);

      final filePath = WorkspaceStorage.getWorkspaceFilePath();
      expect(File(filePath).existsSync(), isTrue);

      // Load into a new client instance
      final loadedClient = Iec104Client();
      final loadOk = await loadedClient.loadWorkspace();
      expect(loadOk, isTrue);

      expect(loadedClient.host, equals('10.0.0.88'));
      expect(loadedClient.stations.containsKey(99), isTrue);
      expect(loadedClient.getStation(99).name, equals('测试专用变电站'));
      expect(loadedClient.getStation(99).getPoint(50)?.value, equals(2));
    });

    test('Point mutation triggers onDataChanged and autoSave callback', () async {
      final client = Iec104Client();
      final st = client.getStation(1);

      bool autoSaved = false;
      st.onDataChanged = () {
        autoSaved = true;
      };

      st.addPoint(ClientPointModel(
        commonAddress: 1,
        ioa: 9999,
        typeId: AsduTypeId.mMeNc1,
        name: '自动化变动点',
        value: 12.3,
      ));

      expect(autoSaved, isTrue);
    });
  });
}
