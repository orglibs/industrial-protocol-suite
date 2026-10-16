import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec61850_client/main.dart';
import 'package:iec61850_client/src/models/connection_config.dart';
import 'package:iec61850_client/src/ui/dialogs/create_connection_dialog.dart';

void main() {
  testWidgets('IEC 61850 Client Simulator Smoke Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const Iec61850ClientApp());
    expect(find.text('IEC 61850 Client Simulator'), findsOneWidget);
  });

  testWidgets('CreateConnectionDialog with simpleIO boundSclPath renders without error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final cfg = ConnectionConfig(
      id: 'test_conn',
      name: 'Test Server',
      ip: '127.0.0.1',
      boundSclPath: 'simpleIO',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateConnectionDialog(
            initialConfig: cfg,
            onSaved: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('编辑 IEC 61850 连接'), findsOneWidget);
    expect(find.text('Test Server'), findsOneWidget);
  });

  testWidgets('CreateConnectionDialog with custom unknown path renders without error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final cfg = ConnectionConfig(
      id: 'test_conn_2',
      name: 'Custom Server',
      ip: '192.168.1.50',
      boundSclPath: '/opt/custom_station.cid',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateConnectionDialog(
            initialConfig: cfg,
            onSaved: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('编辑 IEC 61850 连接'), findsOneWidget);
    expect(find.text('Custom Server'), findsOneWidget);
  });
}
