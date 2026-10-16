import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_server/src/protocol/asdu.dart';
import 'package:iec104_server/src/server/iec104_server.dart';
import 'package:iec104_server/src/server/station.dart';
import 'package:iec104_server/src/server/workspace_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Server Multi-Station & Workspace Persistence Tests', () {
    test('Server can add multiple stations with different templates', () {
      final server = Iec104Server();
      expect(server.stations.length, equals(1));
      expect(server.stations.containsKey(1), isTrue);

      // Add station #2 with distribution template
      server.addStation(2, name: '10kV 配电网开闭所 #2', template: 'distribution');
      expect(server.stations.length, equals(2));
      expect(server.stations.containsKey(2), isTrue);
      final st2 = server.stations[2]!;
      expect(st2.name, equals('10kV 配电网开闭所 #2'));
      expect(st2.points.length, equals(30)); // 16 YX + 8 YC + 4 DP + 2 YM

      // Add station #3 with substation template
      server.addStation(3, name: '220kV 枢纽变电站 #3', template: 'substation');
      expect(server.stations.length, equals(3));
      expect(server.stations.containsKey(3), isTrue);
      final st3 = server.stations[3]!;
      expect(st3.points.length, equals(60)); // 32 YX + 16 YC + 8 DP + 4 YM
    });

    test('Server update and delete station works as expected', () {
      final server = Iec104Server();
      server.addStation(10, name: '旧变电站', template: 'distribution');
      expect(server.stations.containsKey(10), isTrue);

      // Update station
      server.updateStation(10, 20, '新变电站');
      expect(server.stations.containsKey(10), isFalse);
      expect(server.stations.containsKey(20), isTrue);
      expect(server.stations[20]?.name, equals('新变电站'));

      // Delete station
      final deleted = server.removeStation(20);
      expect(deleted, isTrue);
      expect(server.stations.containsKey(20), isFalse);
    });

    test('Server export, save to disk, and loadWorkspace restores all stations', () async {
      final server = Iec104Server();
      server.port = 24041;
      server.addStation(5, name: '5#风电场箱变');
      final st5 = server.getStation(5);
      st5.addPoint(StationPoint(
        ioa: 101,
        typeId: AsduTypeId.mSpNa1,
        name: '风机主断路器合位',
        value: true,
      ));
      st5.addPoint(StationPoint(
        ioa: 16385,
        typeId: AsduTypeId.mMeNc1,
        name: '风机实时发电功率',
        value: 1500.5,
      ));

      final saveOk = await server.saveWorkspace();
      expect(saveOk, isTrue);

      final filePath = WorkspaceStorage.getWorkspaceFilePath();
      expect(File(filePath).existsSync(), isTrue);

      // Create new server instance and load
      final newServer = Iec104Server();
      final loadOk = await newServer.loadWorkspace();
      expect(loadOk, isTrue);

      expect(newServer.port, equals(24041));
      expect(newServer.stations.containsKey(5), isTrue);
      final restoredSt5 = newServer.getStation(5);
      expect(restoredSt5.name, equals('5#风电场箱变'));
      expect(restoredSt5.getPoint(101)?.value, equals(true));
      expect(restoredSt5.getPoint(16385)?.value, equals(1500.5));
    });
  });
}
