import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_server/main.dart';
import 'package:iec104_server/src/server/iec104_server.dart';

void main() {
  testWidgets('IEC 104 Simulator App smoke test', (WidgetTester tester) async {
    final server = Iec104Server();
    await tester.pumpWidget(Iec104SimulatorApp(server: server));

    // Verify app bar title
    expect(find.text('IEC 60870-5-104 Server Simulator'), findsOneWidget);

    // Verify tabs exist
    expect(find.text('服务配置与主站'), findsOneWidget);
    expect(find.text('点位监视与控制'), findsOneWidget);
    expect(find.text('通信细节报文'), findsOneWidget);
    expect(find.text('报文解析工具'), findsOneWidget);
    expect(find.text('变化模拟配置'), findsOneWidget);
  });
}
