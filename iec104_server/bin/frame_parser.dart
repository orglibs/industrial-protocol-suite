import 'dart:io';
import 'package:iec104_server/src/protocol/parser.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('IEC 60870-5-104 报文解析工具 (CLI)');
    print('用法: dart run bin/frame_parser.dart "<hex string>"');
    print('示例: dart run bin/frame_parser.dart "68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14"');
    exit(0);
  }

  final hex = args.join(' ');
  final parsed = Iec104Parser.parseHex(hex);

  if (parsed == null || !parsed.isValid) {
    print('解析失败: ${parsed?.errorMessage ?? "无效十六进制数据"}');
    exit(1);
  }

  print('====================================================');
  print('  IEC 104 报文解析结果');
  print('====================================================');
  print('原始报文: ${parsed.rawHex}');
  print('报文概要: ${parsed.summary}');
  print('----------------------------------------------------');
  for (final f in parsed.fields) {
    final hexPart = f.hex.isNotEmpty ? '[0x${f.hex}] ' : '';
    final descPart = f.description.isNotEmpty ? ' (${f.description})' : '';
    print('${f.name.padRight(26)}: $hexPart${f.value}$descPart');
  }
  print('====================================================');
}
