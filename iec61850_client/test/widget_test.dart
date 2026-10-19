import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec61850_client/main.dart';
import 'package:iec61850_client/src/i18n/app_i18n.dart';
import 'package:iec61850_client/src/models/connection_config.dart';
import 'package:iec61850_client/src/ui/dialogs/create_connection_dialog.dart';

void main() {
  setUp(() {
    AppI18n.instance.setLanguage(AppLanguage.zhCN);
  });

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

  testWidgets('HomeScreen renders Asset icon, constrained NavigationRail, and copy connection action', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const Iec61850ClientApp());
    await tester.pumpAndSettle();

    // Verify Asset Icon exists in AppBar
    final imageFinder = find.byWidgetPredicate((widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == 'assets/icons/iec61850_client_app_512.png');
    expect(imageFinder, findsOneWidget);

    // Verify NavigationRail has constrained width
    final railFinder = find.byType(NavigationRail);
    expect(railFinder, findsOneWidget);
    final railBox = find.ancestor(of: railFinder, matching: find.byType(ConstrainedBox)).first;
    final boxWidget = tester.widget<ConstrainedBox>(railBox);
    expect(boxWidget.constraints.minWidth, 72.0);
    expect(boxWidget.constraints.maxWidth, 88.0);

    // Verify Copy Connection button exists in AppBar
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);

    final i18n = AppI18n.instance;

    // Verify Connection Selector has hover Tooltip with waitDuration 200ms
    final connTooltipFinder = find.byWidgetPredicate((w) =>
        w is Tooltip &&
        (w.message == i18n.t('noConnHint') || (w.message?.contains('127.0.0.1') ?? false)) &&
        w.waitDuration == const Duration(milliseconds: 200));
    expect(connTooltipFinder, findsAtLeastNWidgets(1));

    // Verify header icon button spacing: 6px between action icons, 8px after selector, 10px before Connect button
    final sizedBox6Finder = find.byWidgetPredicate((w) => w is SizedBox && w.width == 6.0);
    expect(sizedBox6Finder, findsWidgets);

    final sizedBox8Finder = find.byWidgetPredicate((w) => w is SizedBox && w.width == 8.0);
    expect(sizedBox8Finder, findsWidgets);

    final sizedBox10Finder = find.byWidgetPredicate((w) => w is SizedBox && w.width == 10.0);
    expect(sizedBox10Finder, findsWidgets);
  });

  testWidgets('ModelExplorerTab displays header with colRef and colLiveAcqVal, fixed width and hover tooltips', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const Iec61850ClientApp());
    await tester.pumpAndSettle();

    final i18n = AppI18n.instance;

    // Verify Column Header Bar for Variables List in ModelExplorerTab
    expect(find.text('FC'), findsWidgets);
    expect(find.text(i18n.t('colRef')), findsWidgets);
    expect(find.text(i18n.t('colLiveAcqVal')), findsWidgets);
    expect(find.text(i18n.t('colAction')), findsWidgets);

    // Verify tooltips with waitDuration are rendered
    final liveValTooltipFinder = find.byWidgetPredicate((w) =>
        w is Tooltip &&
        w.message == i18n.t('colLiveAcqVal') &&
        w.waitDuration == const Duration(milliseconds: 200));
    expect(liveValTooltipFinder, findsWidgets);

    final refTooltipFinder = find.byWidgetPredicate((w) =>
        w is Tooltip &&
        w.message == i18n.t('colRef') &&
        w.waitDuration == const Duration(milliseconds: 200));
    expect(refTooltipFinder, findsWidgets);

    // Verify 8px spacing between Action buttons
    final sizedBox8Finder = find.byWidgetPredicate((w) =>
        w is SizedBox && w.width == 8.0);
    expect(sizedBox8Finder, findsWidgets);
  });
}

