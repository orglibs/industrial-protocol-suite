import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_client/src/client/iec104_client.dart';
import 'package:iec104_client/src/client/station_data.dart';
import 'package:iec104_client/src/protocol/asdu.dart';

void main() {
  group('IEC 104 Client Core Tests', () {
    test('Client default state and params', () {
      final client = Iec104Client();
      expect(client.state, equals(ClientConnectionState.disconnected));
      expect(client.port, equals(2404));
      expect(client.k, equals(12));
      expect(client.w, equals(8));
      expect(client.t0, equals(30));
    });

    test('Client Point Model update and history recording', () {
      final client = Iec104Client();
      final st = client.getStation(1);

      final p = st.points.putIfAbsent(
        100,
        () => ClientPointModel(
          commonAddress: 1,
          ioa: 100,
          typeId: AsduTypeId.mMeNc1,
          name: '测试遥测',
          value: 10.5,
        ),
      );

      expect(p.displayValue, equals('10.50'));
      expect(p.history.length, equals(1));

      p.update(12.34, null);
      expect(p.displayValue, equals('12.34'));
      expect(p.updateCount, equals(2));
      expect(p.history.length, equals(2));
    });

    test('Client Automated Verification suite passes all 10 tests', () async {
      final client = Iec104Client();
      final results = await client.runAutomatedVerification();

      expect(results.length, equals(10));
      for (final r in results) {
        expect(r.contains('失败'), isFalse, reason: 'Failed test step: $r');
      }
    });

    test('Client STOPDT and STARTDT cycling updates state and stateStream properly', () async {
      final client = Iec104Client();
      final states = <ClientConnectionState>[];
      final sub = client.stateStream.listen(states.add);

      await client.connect();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(client.state, equals(ClientConnectionState.active));

      // Test multiple STOPDT -> STARTDT cycles
      for (int i = 0; i < 3; i++) {
        client.sendStopDt();
        await Future.delayed(const Duration(milliseconds: 50));
        expect(client.state, equals(ClientConnectionState.connected));

        client.sendStartDt();
        await Future.delayed(const Duration(milliseconds: 50));
        expect(client.state, equals(ClientConnectionState.active));
      }

      await client.disconnect();
      await sub.cancel();
      expect(states.contains(ClientConnectionState.connected), isTrue);
      expect(states.contains(ClientConnectionState.active), isTrue);
    });

    test('Station and Point management tests (Add Station, Add Point, Batch, Export/Import)', () {
      final client = Iec104Client();
      expect(client.stations.containsKey(1), isTrue);

      // 1. Add Station
      client.addStation(2, name: '110kV 西郊站', template: 'distribution');
      expect(client.stations.containsKey(2), isTrue);
      final st2 = client.stations[2]!;
      expect(st2.name, equals('110kV 西郊站'));
      expect(st2.points.length, equals(30)); // 16 YX + 4 DP + 8 YC + 2 YM

      // 2. Add single point
      st2.addPoint(ClientPointModel(
        commonAddress: 2,
        ioa: 9999,
        typeId: AsduTypeId.mSpNa1,
        name: '自定义母联开关',
        value: true,
      ));
      expect(st2.getPoint(9999), isNotNull);
      expect(st2.getPoint(9999)!.name, equals('自定义母联开关'));
      expect(st2.getPoint(9999)!.value, isTrue);

      // 3. Batch generate points
      st2.batchGeneratePoints(
        typeId: AsduTypeId.mMeNc1,
        startIoa: 17001,
        count: 5,
        prefix: '新建线路有功功率',
      );
      expect(st2.getPoint(17001), isNotNull);
      expect(st2.getPoint(17005), isNotNull);
      expect(st2.getPoint(17001)!.name, equals('新建线路有功功率 #1'));

      // 4. Update station COA and Name
      client.updateStation(2, 3, '220kV 北郊站');
      expect(client.stations.containsKey(2), isFalse);
      expect(client.stations.containsKey(3), isTrue);
      final st3 = client.stations[3]!;
      expect(st3.name, equals('220kV 北郊站'));
      expect(st3.getPoint(9999)!.commonAddress, equals(3));

      // 5. JSON Export & Import
      final json = st3.toJson();
      expect(json['commonAddress'], equals(3));
      expect(json['name'], equals('220kV 北郊站'));
      expect(json['points'], isNotEmpty);

      final newSt = ClientStationModel(commonAddress: 4);
      newSt.loadFromJson(json);
      expect(newSt.name, equals('220kV 北郊站'));
      expect(newSt.getPoint(9999), isNotNull);
      expect(newSt.getPoint(9999)!.name, equals('自定义母联开关'));

      // 6. Delete Station
      final removed = client.removeStation(3);
      expect(removed, isTrue);
      expect(client.stations.containsKey(3), isFalse);
      expect(client.stations.containsKey(1), isTrue);
    });
  });
}
