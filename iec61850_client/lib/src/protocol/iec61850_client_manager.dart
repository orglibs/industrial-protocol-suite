import 'dart:async';
import '../models/connection_config.dart';
import '../models/scl_parser.dart';
import 'iec61850_client_engine.dart';

class Iec61850ClientManager {
  final List<ConnectionConfig> connections = [];
  final Map<String, Iec61850ClientEngine> _engines = {};
  String? selectedConnectionId;

  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyUpdated() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  ConnectionConfig? get selectedConnection {
    if (selectedConnectionId == null) {
      return connections.isNotEmpty ? connections.first : null;
    }
    return connections.firstWhere((c) => c.id == selectedConnectionId, orElse: () => connections.first);
  }

  Iec61850ClientEngine? get activeEngine {
    final conn = selectedConnection;
    if (conn == null) return null;
    return getEngineFor(conn);
  }

  Iec61850ClientEngine getEngineFor(ConnectionConfig config) {
    if (!_engines.containsKey(config.id)) {
      final engine = Iec61850ClientEngine(config: config);
      _engines[config.id] = engine;
    }
    return _engines[config.id]!;
  }

  void addConnection(ConnectionConfig config) {
    connections.add(config);
    config.addListener(notifyUpdated);
    selectedConnectionId ??= config.id;
    notifyUpdated();
  }

  void removeConnection(String connectionId) {
    final conn = connections.firstWhere((c) => c.id == connectionId, orElse: () => ConnectionConfig(id: ''));
    if (conn.id.isNotEmpty) {
      final eng = _engines.remove(connectionId);
      eng?.disconnect();
      connections.remove(conn);
      if (selectedConnectionId == connectionId) {
        selectedConnectionId = connections.isNotEmpty ? connections.first.id : null;
      }
      notifyUpdated();
    }
  }

  Future<bool> connect(ConnectionConfig config) async {
    final engine = getEngineFor(config);
    final ok = await engine.connect();
    notifyUpdated();
    return ok;
  }

  void disconnect(ConnectionConfig config) {
    final engine = getEngineFor(config);
    engine.disconnect();
    notifyUpdated();
  }

  void bindSclToConnection(ConnectionConfig config, SclParseResult parseRes, [String? filePath]) {
    final engine = getEngineFor(config);
    if (filePath != null && filePath.isNotEmpty) {
      config.boundSclPath = filePath;
    }
    engine.bindSclModel(parseRes);
    notifyUpdated();
  }

  void dispose() {
    for (final eng in _engines.values) {
      eng.disconnect();
    }
    _engines.clear();
  }
}
