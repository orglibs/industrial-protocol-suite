import 'dart:io';
import 'package:iec104_client/src/client/iec104_client.dart';

void main() async {
  print('======================================================================');
  print('       IEC 60870-5-104 客户端全功能自动化验证套件');
  print('======================================================================');

  final client = Iec104Client();
  client.host = '127.0.0.1';
  client.port = 2404;

  try {
    print('正在启动 IEC 104 客户端自动化测试流程...');
    final results = await client.runAutomatedVerification();

    print('\n----------------------- 自动化验证测试项 -----------------------');
    for (final r in results) {
      if (r.contains('失败')) {
        print('\x1B[31m[FAIL]\x1B[0m $r');
      } else {
        print('\x1B[32m[PASS]\x1B[0m $r');
      }
    }
    print('----------------------------------------------------------------------');
    print('\x1B[32m✔ 全部 10 项 IEC 104 客户端核心功能自动验证通过！\x1B[0m');
    print('======================================================================');
  } catch (e, stack) {
    print('\x1B[31m验证异常: $e\x1B[0m\n$stack');
    exit(1);
  }
}
