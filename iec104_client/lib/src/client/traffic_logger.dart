import 'dart:async';
import 'dart:typed_data';
import '../protocol/parser.dart';

enum TrafficDirection {
  rx('收 [RX]'),
  tx('发 [TX]');

  final String label;
  const TrafficDirection(this.label);
}

class TrafficEntry {
  final int id;
  final DateTime timestamp;
  final TrafficDirection direction;
  final String remoteAddress;
  final Uint8List rawBytes;
  final String rawHex;
  final ParsedFrame parsed;

  TrafficEntry({
    required this.id,
    required this.timestamp,
    required this.direction,
    required this.remoteAddress,
    required this.rawBytes,
    required this.rawHex,
    required this.parsed,
  });

  String get summary => parsed.summary;
}

class TrafficLogger {
  static final TrafficLogger instance = TrafficLogger._();
  TrafficLogger._();

  int _nextId = 1;
  final List<TrafficEntry> _entries = [];
  final StreamController<TrafficEntry> _streamController = StreamController<TrafficEntry>.broadcast();

  int maxEntries = 1000;

  Stream<TrafficEntry> get stream => _streamController.stream;
  List<TrafficEntry> get entries => List.unmodifiable(_entries);

  void log({
    required TrafficDirection direction,
    required String remoteAddress,
    required Uint8List rawBytes,
    int cotSize = 2,
    int caSize = 2,
    int ioaSize = 3,
  }) {
    final parsed = Iec104Parser.parseBytes(
      rawBytes,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
    );

    final entry = TrafficEntry(
      id: _nextId++,
      timestamp: DateTime.now(),
      direction: direction,
      remoteAddress: remoteAddress,
      rawBytes: rawBytes,
      rawHex: Iec104Parser.bytesToHex(rawBytes),
      parsed: parsed,
    );

    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }

    _streamController.add(entry);
  }

  void clear() {
    _entries.clear();
  }
}
