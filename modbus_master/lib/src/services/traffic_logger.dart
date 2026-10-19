import 'dart:async';
import 'dart:typed_data';
import '../i18n/app_i18n.dart';

enum TrafficDirection { tx, rx }

class TrafficEntry {
  final int id;
  final DateTime timestamp;
  final TrafficDirection direction;
  final String sourceOrTarget;
  final Uint8List rawBytes;
  final String summary;
  final String protocolDetail;
  final bool isError;
  final int? elapsedMs;

  TrafficEntry({
    required this.id,
    DateTime? timestamp,
    required this.direction,
    required this.sourceOrTarget,
    required this.rawBytes,
    required this.summary,
    required this.protocolDetail,
    this.isError = false,
    this.elapsedMs,
  }) : timestamp = timestamp ?? DateTime.now();

  String get rawHex {
    return rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  String get timestampStr {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get directionLabel => direction == TrafficDirection.tx ? AppI18n.instance.t('dirTxDesc') : AppI18n.instance.t('dirRxDesc');
}

typedef TrafficLogEntry = TrafficEntry;


class TrafficLogger {
  static final TrafficLogger instance = TrafficLogger._();
  TrafficLogger._();

  final List<TrafficEntry> _entries = [];
  final StreamController<TrafficEntry> _streamController = StreamController<TrafficEntry>.broadcast();
  int _nextId = 1;

  List<TrafficEntry> get entries => List.unmodifiable(_entries);
  Stream<TrafficEntry> get stream => _streamController.stream;

  void log({
    required TrafficDirection direction,
    required String sourceOrTarget,
    required Uint8List rawBytes,
    required String summary,
    required String protocolDetail,
    bool isError = false,
    int? elapsedMs,
  }) {
    final entry = TrafficEntry(
      id: _nextId++,
      direction: direction,
      sourceOrTarget: sourceOrTarget,
      rawBytes: rawBytes,
      summary: summary,
      protocolDetail: protocolDetail,
      isError: isError,
      elapsedMs: elapsedMs,
    );

    _entries.add(entry);
    if (_entries.length > 500) {
      _entries.removeAt(0);
    }
    _streamController.add(entry);
  }

  void clear() {
    _entries.clear();
  }
}
