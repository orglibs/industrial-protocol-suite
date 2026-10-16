import 'dart:async';
import 'package:intl/intl.dart';

enum TrafficDirection {
  rx('接收 (RX)', 0xFF4CAF50), // Green
  tx('发送 (TX)', 0xFF2196F3), // Blue
  err('错误 (ERR)', 0xFFF44336); // Red

  final String label;
  final int colorArgb;
  const TrafficDirection(this.label, this.colorArgb);
}

class TrafficEntry {
  final int index;
  final DateTime timestamp;
  final TrafficDirection direction;
  final String connectionName;
  final int unitId;
  final int functionCode;
  final List<int> rawBytes;
  final String description;

  TrafficEntry({
    required this.index,
    required this.timestamp,
    required this.direction,
    required this.connectionName,
    required this.unitId,
    required this.functionCode,
    required this.rawBytes,
    required this.description,
  });

  String get timeStr => DateFormat('HH:mm:ss.SSS').format(timestamp);

  String get hexString {
    return rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }
}

class TrafficLogger {
  static final TrafficLogger instance = TrafficLogger._();
  TrafficLogger._();

  static const int maxCapacity = 2000;
  final List<TrafficEntry> _entries = [];
  int _counter = 0;
  bool isPaused = false;

  final StreamController<TrafficEntry> _entryController = StreamController<TrafficEntry>.broadcast();
  Stream<TrafficEntry> get onNewEntry => _entryController.stream;

  List<TrafficEntry> get entries => List.unmodifiable(_entries);

  void log({
    required TrafficDirection direction,
    required String connectionName,
    required int unitId,
    required int functionCode,
    required List<int> rawBytes,
    required String description,
  }) {
    if (isPaused) return;

    _counter++;
    final entry = TrafficEntry(
      index: _counter,
      timestamp: DateTime.now(),
      direction: direction,
      connectionName: connectionName,
      unitId: unitId,
      functionCode: functionCode,
      rawBytes: rawBytes,
      description: description,
    );

    if (_entries.length >= maxCapacity) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
    _entryController.add(entry);
  }

  void clear() {
    _entries.clear();
  }

  String exportToText() {
    final buf = StringBuffer();
    buf.writeln('序号\t时间\t方向\t连接\t从站ID\t功能码\t报文十六进制\t说明');
    for (final e in _entries) {
      buf.writeln(
        '${e.index}\t${e.timeStr}\t${e.direction.name.toUpperCase()}\t${e.connectionName}\t${e.unitId}\t0x${e.functionCode.toRadixString(16).padLeft(2, "0")}\t${e.hexString}\t${e.description}',
      );
    }
    return buf.toString();
  }
}
