import 'dart:async';
import '../models/server_variable_model.dart';

class SimulationService {
  static final SimulationService instance = SimulationService._();
  SimulationService._();
  SimulationService();

  Timer? _timer;
  final List<ServerVariableModel> _variables = [];
  final Map<String, int> _elapsedMap = {}; // reference -> elapsed ms

  void Function(ServerVariableModel variable)? onVariableUpdated;

  bool get isRunning => _timer != null && _timer!.isActive;

  void setVariables(List<ServerVariableModel> vars) {
    _variables.clear();
    _variables.addAll(vars);
    _elapsedMap.clear();
  }

  void start({int intervalMs = 100}) {
    stop();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      _tick(intervalMs);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick(int deltaMs) {
    for (final v in _variables) {
      if (!v.simulation.enabled) continue;

      final currentElapsed = (_elapsedMap[v.reference] ?? 0) + deltaMs;
      _elapsedMap[v.reference] = currentElapsed;

      final dur = v.simulation.durationMs <= 0 ? 5000 : v.simulation.durationMs;
      final cycleElapsed = currentElapsed % dur;
      final progress = cycleElapsed / dur; // 0.0 to 1.0

      final lastNum = (v.value is num) ? (v.value as num).toDouble() : null;
      var raw = v.simulation.compute(progress, lastNum);

      dynamic nextVal;
      // Format appropriately according to basic type
      if (v.type.name.startsWith('int') || v.type.name.startsWith('uint')) {
        nextVal = raw.round();
      } else if (v.type.name == 'boolean') {
        final mid = (v.simulation.min + v.simulation.max) / 2.0;
        nextVal = raw >= mid;
      } else {
        // float32 / float64: round to 3 decimal places for stability
        nextVal = double.parse(raw.toStringAsFixed(3));
      }

      if (v.value != nextVal) {
        v.value = nextVal;
        onVariableUpdated?.call(v);
      }
    }
  }
}
