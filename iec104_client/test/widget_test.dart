import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_client/main.dart';
import 'package:iec104_client/src/client/iec104_client.dart';
import 'package:iec104_client/src/i18n/app_i18n.dart';
import 'package:iec104_client/src/ui/dialogs/add_station_dialog.dart';
import 'package:iec104_client/src/ui/dialogs/edit_station_dialog.dart';
import 'package:iec104_client/src/ui/dialogs/add_point_dialog.dart';
import 'package:iec104_client/src/ui/dialogs/batch_add_points_dialog.dart';
import 'package:iec104_client/src/ui/dialogs/station_import_export_dialog.dart';

void main() {
  testWidgets('IEC 104 Client App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    AppI18n.instance.setLanguage(AppLanguage.zhCN);
    final client = Iec104Client();
    await tester.pumpWidget(Iec104ClientApp(client: client));

    expect(find.textContaining('IEC 60870-5-104 客户端仿真器'), findsOneWidget);
    expect(find.text('连接主控'), findsOneWidget);
    expect(find.text('点位监视'), findsOneWidget);
    expect(find.text('命令下发'), findsOneWidget);

    // Switch to PointsTab
    await tester.tap(find.text('点位监视'));
    await tester.pumpAndSettle();
    expect(find.text('增加从站'), findsOneWidget);
    expect(find.text('管理从站'), findsOneWidget);
    expect(find.text('增加点号'), findsOneWidget);
    expect(find.text('批量生成点号'), findsOneWidget);
    expect(find.text('导入/导出点表'), findsOneWidget);

    // Test 1: Open AddStationDialog
    await tester.tap(find.text('增加从站'));
    await tester.pumpAndSettle();
    expect(find.byType(AddStationDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // Test 2: Open EditStationDialog (formerly threw _OverflowBarParentData exception)
    await tester.tap(find.text('管理从站'));
    await tester.pumpAndSettle();
    expect(find.byType(EditStationDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // Test 3: Open AddPointDialog
    await tester.tap(find.text('增加点号'));
    await tester.pumpAndSettle();
    expect(find.byType(AddPointDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // Test 4: Open BatchAddPointsDialog
    await tester.tap(find.text('批量生成点号'));
    await tester.pumpAndSettle();
    expect(find.byType(BatchAddPointsDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // Test 5: Open StationImportExportDialog (formerly threw _OverflowBarParentData exception)
    await tester.tap(find.text('导入/导出点表'));
    await tester.pumpAndSettle();
    expect(find.byType(StationImportExportDialog), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
  });
}
