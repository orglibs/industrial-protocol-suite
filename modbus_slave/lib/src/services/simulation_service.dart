import 'dart:async';
import '../models/connection_config.dart';
import '../protocol/modbus_data_types.dart';

class SimulationService {
  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  static final SimulationService instance = SimulationService._();
  SimulationService._();

  Timer? _timer;
  int _elapsedMs = 0;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  List<ConnectionConfig> _activeConfigs = [];

  void setConnections(List<ConnectionConfig> configs) {
    _activeConfigs = configs;
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _elapsedMs = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), _tick);
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    notifyListeners();
  }

  void toggle() {
    if (_isRunning) {
      stop();
    } else {
      start();
    }
  }

  void _tick(Timer timer) {
    _elapsedMs += 100;
    bool anyChanged = false;

    for (final conn in _activeConfigs) {
      for (final slave in conn.slaves) {
        for (final group in slave.groups) {
          for (int i = 0; i < group.registers.length; i++) {
            final reg = group.registers[i];
            final sim = reg.simulation;
            if (!sim.enabled || sim.durationMs <= 0) continue;

            final cyclePos = (_elapsedMs % sim.durationMs) / sim.durationMs;
            final computedDouble = sim.compute(cyclePos, reg.rawValue.toDouble());

            if (group.isBitType) {
              reg.rawValue = (computedDouble >= ((sim.max + sim.min) / 2)) ? 1 : 0;
            } else if (reg.valueFormat == RegisterDataFormat.float32) {
              final words = ModbusDataConverter.float32ToRegisters(computedDouble, slave.byteOrder);
              reg.rawValue = words[0];
              if (i + 1 < group.registers.length && reg.compositeType == 1) {
                group.registers[i + 1].rawValue = words[1];
              }
            } else if (reg.valueFormat == RegisterDataFormat.signed32 || reg.valueFormat == RegisterDataFormat.unsigned32) {
              final words = ModbusDataConverter.int32ToRegisters(computedDouble.round(), slave.byteOrder);
              reg.rawValue = words[0];
              if (i + 1 < group.registers.length && reg.compositeType == 1) {
                group.registers[i + 1].rawValue = words[1];
              }
            } else {
              reg.rawValue = computedDouble.round() & 0xFFFF;
            }

            anyChanged = true;
          }
        }
      }
    }

    if (anyChanged) {
      notifyListeners();
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
