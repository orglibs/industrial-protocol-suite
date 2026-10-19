import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_server/main.dart';
import 'package:iec104_server/src/i18n/app_i18n.dart';
import 'package:iec104_server/src/models/connection_config.dart';
import 'package:iec104_server/src/protocol/asdu.dart';
import 'package:iec104_server/src/protocol/asdu_types.dart';
import 'package:iec104_server/src/server/ease_functions.dart';
import 'package:iec104_server/src/ui/tabs/station_tab.dart';

void main() {
  group('Requirement 1 & 6: Multi-Connection, Multi-Slave & i18n Tests', () {
    test('Default preset connections support multiple connections and slaves', () {
      final connections = Iec104ConnectionConfig.createDefaultConnections();
      expect(connections.length, greaterThanOrEqualTo(3));

      // Conn 1 has multiple stations
      final conn1 = connections[0];
      expect(conn1.port, 2404);
      expect(conn1.stations.length, greaterThanOrEqualTo(2));
      expect(conn1.findStation(1), isNotNull);
      expect(conn1.findStation(2), isNotNull);

      // Conn 2 has station 3
      final conn2 = connections[1];
      expect(conn2.port, 2405);
      expect(conn2.stations.isNotEmpty, true);
      expect(conn2.findStation(3), isNotNull);

      // Conn 3 has station 4
      final conn3 = connections[2];
      expect(conn3.port, 2406);
      expect(conn3.stations.isNotEmpty, true);
      expect(conn3.findStation(4), isNotNull);
    });

    test('Connections and stations reactively update displayName across languages', () {
      final connections = Iec104ConnectionConfig.createDefaultConnections();
      final conn1 = connections[0];
      final station1 = conn1.findStation(1)!;
      final point1 = station1.points[1]!;

      // 1. Chinese (zh-CN)
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(conn1.displayName, contains('默认'));
      expect(station1.displayName, contains('枢纽变电站'));
      expect(point1.displayName, contains('断路器'));

      // 2. English (en-US)
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(conn1.displayName, contains('Default'));
      expect(station1.displayName, contains('Substation'));
      expect(point1.displayName, contains('Breaker'));

      // 3. German (de-DE)
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(conn1.displayName, contains('Standard'));
      expect(station1.displayName, contains('Umspannwerk'));

      // 4. Japanese (ja-JP)
      AppI18n.instance.setLanguage(AppLanguage.jaJP);
      expect(conn1.displayName, contains('デフォルト'));
      expect(station1.displayName, contains('変電所'));

      // Reset to zh-CN
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
    });

    test('ASDU, Quality, DP/SP, and EaseType enums reactively update across languages', () {
      // 1. Chinese (zh-CN)
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(AsduTypeId.mSpNa1.description, contains('单点'));
      expect(AsduTypeId.mDpNa1.description, contains('双点'));
      expect(EaseType.sine.description, contains('正弦'));
      expect(QualityDescriptor.good.summary, contains('有效'));
      final qInvalid = const QualityDescriptor(invalid: true);
      expect(qInvalid.summary, contains('无效'));
      final dpObj = DoublePointObject(ioa: 1, value: 2);
      expect(dpObj.displayValue, contains('合闸'));

      // 2. English (en-US)
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(AsduTypeId.mSpNa1.description, contains('Single-point'));
      expect(AsduTypeId.mDpNa1.description, contains('Double-point'));
      expect(EaseType.sine.description, contains('Sine'));
      expect(QualityDescriptor.good.summary, contains('Good'));
      expect(qInvalid.summary, contains('Invalid'));
      expect(dpObj.displayValue, contains('ON'));

      // 3. German (de-DE)
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(QualityDescriptor.good.summary, contains('Gültig'));
      expect(dpObj.displayValue, contains('EIN'));

      // Reset to zh-CN
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
    });

    test('Workspace serialization and deserialization of multiple connections', () async {
      final original = Iec104ConnectionConfig.createDefaultConnections();
      final jsonList = original.map((c) => c.toJson()).toList();

      expect(jsonList.length, original.length);
      final restored = jsonList.map((j) => Iec104ConnectionConfig.fromJson(j)).toList();

      expect(restored.length, original.length);
      expect(restored[0].port, 2404);
      expect(restored[0].stations.length, original[0].stations.length);
      expect(restored[0].stations[0].points.length, original[0].stations[0].points.length);
    });
  });

  group('Requirements 2, 3, 4, 5: UI Structure & Layout Widget Tests', () {
    testWidgets('Header uses asset icon and left NavigationRail is constrained without leading icon',
        (WidgetTester tester) async {
      final connections = Iec104ConnectionConfig.createDefaultConnections();
      AppI18n.instance.setLanguage(AppLanguage.zhCN);

      await tester.pumpWidget(Iec104SimulatorApp(initialConnections: connections));
      await tester.pumpAndSettle();

      // Requirement 3: Header uses assets icon
      final imageFinder = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is AssetImage) {
          final asset = widget.image as AssetImage;
          return asset.assetName == 'assets/icons/iec104_slave_app_512.png';
        }
        return false;
      });
      expect(imageFinder, findsOneWidget);

      // Requirement 2: NavigationRail is constrained with maxWidth 88 and has no leading icon
      final navRailFinder = find.byType(NavigationRail);
      expect(navRailFinder, findsOneWidget);

      final navRail = tester.widget<NavigationRail>(navRailFinder);
      expect(navRail.leading, isNull);

      final constrainedBox = find.ancestor(
        of: navRailFinder,
        matching: find.byType(ConstrainedBox),
      );
      expect(constrainedBox, findsWidgets);
    });

    testWidgets('StationTab query bar is compact with tooltips and table has fixed column widths',
        (WidgetTester tester) async {
      final connections = Iec104ConnectionConfig.createDefaultConnections();
      AppI18n.instance.setLanguage(AppLanguage.zhCN);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StationTab(connections: connections),
        ),
      ));
      await tester.pumpAndSettle();

      // Requirement 4: Top query bar contains Tooltip widgets for hover visibility
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsWidgets);

      // Requirement 5: Data table columns have fixed widths
      final dataTableFinder = find.byType(DataTable);
      expect(dataTableFinder, findsOneWidget);

      final dataTable = tester.widget<DataTable>(dataTableFinder);
      expect(dataTable.columns.length, 7);

      // Verify each column header has a SizedBox with fixed width and Tooltip
      for (final col in dataTable.columns) {
        expect(col.label, isA<SizedBox>());
        final sizedBox = col.label as SizedBox;
        expect(sizedBox.width, isNotNull);
        expect(sizedBox.child, isA<Tooltip>());
      }
    });
  });
}
