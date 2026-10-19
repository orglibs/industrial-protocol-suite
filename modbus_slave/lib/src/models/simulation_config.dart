import 'dart:math';
import '../i18n/app_i18n.dart';

/// Easing and Waveform types replicating MSE EaseFunctionConfig
enum EaseWaveType {
  none,
  sine,
  triangle,
  square,
  sawtooth,
  increment,
  random,
  easeInQuint,
  easeOutQuint,
  easeInOutQuint;

  String get label {
    switch (this) {
      case EaseWaveType.none:
        return AppI18n.instance.t('waveNone');
      case EaseWaveType.sine:
        return AppI18n.instance.t('waveSine');
      case EaseWaveType.triangle:
        return AppI18n.instance.t('waveTriangle');
      case EaseWaveType.square:
        return AppI18n.instance.t('waveSquare');
      case EaseWaveType.sawtooth:
        return AppI18n.instance.t('waveSawtooth');
      case EaseWaveType.increment:
        return AppI18n.instance.t('waveIncrement');
      case EaseWaveType.random:
        return AppI18n.instance.t('waveRandom');
      case EaseWaveType.easeInQuint:
        return AppI18n.instance.t('waveEaseIn');
      case EaseWaveType.easeOutQuint:
        return AppI18n.instance.t('waveEaseOut');
      case EaseWaveType.easeInOutQuint:
        return AppI18n.instance.t('waveEaseInOut');
    }
  }

  String get shortLabel {
    switch (this) {
      case EaseWaveType.none:
        return '-';
      case EaseWaveType.sine:
        return AppI18n.instance.t('shortSine');
      case EaseWaveType.triangle:
        return AppI18n.instance.t('shortTriangle');
      case EaseWaveType.square:
        return AppI18n.instance.t('shortSquare');
      case EaseWaveType.sawtooth:
        return AppI18n.instance.t('shortSawtooth');
      case EaseWaveType.increment:
        return AppI18n.instance.t('shortIncrement');
      case EaseWaveType.random:
        return AppI18n.instance.t('shortRandom');
      case EaseWaveType.easeInQuint:
        return 'EaseIn';
      case EaseWaveType.easeOutQuint:
        return 'EaseOut';
      case EaseWaveType.easeInOutQuint:
        return 'EaseInOut';
    }
  }

  static EaseWaveType fromIndex(int index) {
    if (index >= 0 && index < EaseWaveType.values.length) {
      return EaseWaveType.values[index];
    }
    return EaseWaveType.none;
  }
}

class SimulationConfig {
  bool enabled;
  EaseWaveType waveType;
  double min;
  double max;
  double step;
  int durationMs; // Cycle duration in milliseconds (e.g. 2000)
  bool reverse;

  SimulationConfig({
    this.enabled = false,
    this.waveType = EaseWaveType.none,
    this.min = 0.0,
    this.max = 100.0,
    this.step = 1.0,
    this.durationMs = 2000,
    this.reverse = false,
  });

  /// Computes simulated value at fraction t (0.0 .. 1.0) of cycle
  double compute(double t, [double? lastValue]) {
    if (!enabled || waveType == EaseWaveType.none) return min;

    final range = max - min;
    if (range.abs() < 1e-9) return min;

    // Clamp t to [0, 1]
    final progress = t.clamp(0.0, 1.0);

    switch (waveType) {
      case EaseWaveType.none:
        return min;

      case EaseWaveType.sine:
        // Oscillates smoothly min..max..min
        final rad = progress * 2 * pi;
        final factor = (sin(rad - pi / 2) + 1.0) / 2.0; // 0..1..0
        return min + range * factor;

      case EaseWaveType.triangle:
        // Linearly goes from min to max (0..0.5) and back to min (0.5..1.0)
        double factor;
        if (progress < 0.5) {
          factor = progress * 2.0;
        } else {
          factor = (1.0 - progress) * 2.0;
        }
        return min + range * factor;

      case EaseWaveType.square:
        // Half cycle min, half cycle max
        return (progress < 0.5) ? max : min;

      case EaseWaveType.sawtooth:
        // Linearly goes from min to max then resets
        return min + range * progress;

      case EaseWaveType.increment:
        if (lastValue == null || lastValue < min || lastValue >= max) {
          return min;
        }
        final next = lastValue + step;
        return (next > max) ? min : next;

      case EaseWaveType.random:
        final rnd = Random();
        return min + rnd.nextDouble() * range;

      case EaseWaveType.easeInQuint:
        // t^5
        final factor = pow(progress, 5).toDouble();
        return min + range * factor;

      case EaseWaveType.easeOutQuint:
        // 1 - (1-t)^5
        final factor = 1.0 - pow(1.0 - progress, 5).toDouble();
        return min + range * factor;

      case EaseWaveType.easeInOutQuint:
        double factor;
        if (progress < 0.5) {
          factor = 16.0 * pow(progress, 5).toDouble();
        } else {
          factor = 1.0 - pow(-2.0 * progress + 2.0, 5).toDouble() / 2.0;
        }
        return min + range * factor;
    }
  }

  Map<String, dynamic> toJson() => {
    'Enabled': enabled,
    'WaveType': waveType.index,
    'Min': min,
    'Max': max,
    'Step': step,
    'DurationMs': durationMs,
    'Reverse': reverse,
  };

  factory SimulationConfig.fromJson(Map<String, dynamic> json) {
    return SimulationConfig(
      enabled: json['Enabled'] as bool? ?? false,
      waveType: EaseWaveType.fromIndex(json['WaveType'] as int? ?? 0),
      min: (json['Min'] as num?)?.toDouble() ?? 0.0,
      max: (json['Max'] as num?)?.toDouble() ?? 100.0,
      step: (json['Step'] as num?)?.toDouble() ?? 1.0,
      durationMs: json['DurationMs'] as int? ?? 2000,
      reverse: json['Reverse'] as bool? ?? false,
    );
  }

  SimulationConfig copyWith({
    bool? enabled,
    EaseWaveType? waveType,
    double? min,
    double? max,
    double? step,
    int? durationMs,
    bool? reverse,
  }) {
    return SimulationConfig(
      enabled: enabled ?? this.enabled,
      waveType: waveType ?? this.waveType,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
      durationMs: durationMs ?? this.durationMs,
      reverse: reverse ?? this.reverse,
    );
  }
}
