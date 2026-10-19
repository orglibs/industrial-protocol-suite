import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec61850_server/main.dart';
import 'package:iec61850_server/src/models/server_config.dart';
import 'package:iec61850_server/src/i18n/app_i18n.dart';

void main() {
  testWidgets('Capture iec61850_server screenshot', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final connections = ServerConfig.createDefaultConnections();
    AppI18n.instance.setLanguage(AppLanguage.zhCN);

    final repaintKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: Iec61850App(initialConnections: connections),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final outDir = Directory('../docs/images');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('../docs/images/test_widget_screenshot.png').writeAsBytesSync(bytes);
    });
  });
}
