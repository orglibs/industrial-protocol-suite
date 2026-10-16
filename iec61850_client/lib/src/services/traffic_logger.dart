import 'dart:typed_data';

enum TrafficDirection { rx, tx }

class TrafficEntry {
  final int id;
  final DateTime timestamp;
  final TrafficDirection direction;
  final String endpoint;
  final String protocol;
  final String service;
  final Uint8List rawBytes;
  final String summary;
  final String details;

  TrafficEntry({
    required this.id,
    required this.timestamp,
    required this.direction,
    required this.endpoint,
    required this.protocol,
    required this.service,
    required this.rawBytes,
    required this.summary,
    this.details = '',
  });

  String get hexDump {
    final sb = StringBuffer();
    for (int i = 0; i < rawBytes.length; i += 16) {
      final chunkEnd = (i + 16 < rawBytes.length) ? i + 16 : rawBytes.length;
      final chunk = rawBytes.sublist(i, chunkEnd);
      final hexPart = chunk.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final asciiPart = chunk.map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.').join('');
      sb.writeln('${i.toRadixString(16).padLeft(4, '0')}:  ${hexPart.padRight(48)}  |$asciiPart|');
    }
    return sb.toString();
  }
}

class TrafficLogger {
  static final TrafficLogger instance = TrafficLogger._();
  TrafficLogger._();

  int _nextId = 1;
  final List<TrafficEntry> _entries = [];
  final List<void Function()> _listeners = [];
  int maxEntries = 2000;
  bool isLoggingEnabled = true;

  List<TrafficEntry> get entries => List.unmodifiable(_entries);

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void log({
    required TrafficDirection direction,
    required String endpoint,
    required String protocol,
    required String service,
    required Uint8List rawBytes,
    required String summary,
    String details = '',
  }) {
    if (!isLoggingEnabled) return;

    final entry = TrafficEntry(
      id: _nextId++,
      timestamp: DateTime.now(),
      direction: direction,
      endpoint: endpoint,
      protocol: protocol,
      service: service,
      rawBytes: rawBytes,
      summary: summary,
      details: details,
    );

    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    _notifyListeners();
  }

  void clear() {
    _entries.clear();
    _notifyListeners();
  }

  String exportToText() {
    final sb = StringBuffer();
    sb.writeln('=== IEC 61850 Client Traffic Log Export ===');
    sb.writeln('Export Time: ${DateTime.now().toIso8601String()}');
    sb.writeln('Total Entries: ${_entries.length}\n');
    for (final e in _entries) {
      final dir = e.direction == TrafficDirection.rx ? 'RX (<-)' : 'TX (->)';
      sb.writeln('[#${e.id}] ${e.timestamp.toIso8601String()} | $dir | ${e.endpoint} | ${e.protocol} | ${e.service}');
      sb.writeln('Summary: ${e.summary}');
      if (e.details.isNotEmpty) {
        sb.writeln('Details: ${e.details}');
      }
      sb.writeln('Hex (${e.rawBytes.length} bytes):');
      sb.writeln(e.hexDump);
      sb.writeln('-' * 60);
    }
    return sb.toString();
  }
}
