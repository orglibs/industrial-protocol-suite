import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_client/main.dart';
import 'package:iec104_client/src/i18n/app_i18n.dart';
import 'package:iec104_client/src/models/connection_config.dart';

void main() {
  testWidgets('CommandsTab renders responsively without any overflow at various resolutions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    AppI18n.instance.setLanguage(AppLanguage.zhCN);
    final connections = Iec104ClientConnectionConfig.createDefaultConnections();
    await tester.pumpWidget(Iec104ClientApp(
      connections: connections,
    ));

    // Tap '命令下发'
    await tester.tap(find.text('命令下发'));
    await tester.pumpAndSettle();

    expect(find.textContaining('总召唤'), findsOneWidget);
    expect(find.textContaining('单命令遥控'), findsOneWidget);
    expect(find.textContaining('双命令遥控'), findsOneWidget);
    expect(find.textContaining('步调节'), findsNWidgets(2));

    // 1. Medium desktop resolution: 1024x768
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 2. Transition width: 960x650
    tester.view.physicalSize = const Size(960, 650);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3. Compact / Tiled window resolution: 800x600
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 4. Narrow resolution: 720x540
    tester.view.physicalSize = const Size(720, 540);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 5. Test under English language (where string labels are typically longer)
    AppI18n.instance.setLanguage(AppLanguage.enUS);
    await tester.pumpWidget(Iec104ClientApp(connections: connections));
    await tester.pumpAndSettle();
    expect(find.textContaining('General Interrogation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reset back to Chinese
    AppI18n.instance.setLanguage(AppLanguage.zhCN);
    await tester.pumpWidget(Iec104ClientApp(connections: connections));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
