import 'dart:math';
import '../i18n/app_i18n.dart';

enum EaseWaveType {
  none('None', 'waveNone'),
  sine('Sine Wave', 'waveSine'),
  triangle('Triangle Wave', 'waveTriangle'),
  square('Square Wave', 'waveSquare'),
  sawtooth('Sawtooth Wave', 'waveSawtooth'),
  increment('Linear Counter', 'waveIncrement'),
  random('Random Walk', 'waveRandom');

  final String englishLabel;
  final String key;
  const EaseWaveType(this.englishLabel, this.key);

  String get label {
    final translated = AppI18n.instance.t(key);
    return translated.isNotEmpty && translated != key ? translated : englishLabel;
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
  bool get isEnabled => enabled;
  set isEnabled(bool v) => enabled = v;

  EaseWaveType waveType;
  EaseWaveType get waveform => waveType;
  set waveform(EaseWaveType v) => waveType = v;

  double min;
  double max;
  double step;
  int durationMs;

  SimulationConfig({
    this.enabled = false,
    this.waveType = EaseWaveType.none,
    this.min = 0.0,
    this.max = 100.0,
    this.step = 1.0,
    this.durationMs = 2000,
  });

  double compute(double progressFraction, [double? lastValue]) {
    if (!enabled || waveType == EaseWaveType.none) return min;

    final range = max - min;
    if (range.abs() < 1e-9) return min;

    final t = progressFraction.clamp(0.0, 1.0);

    switch (waveType) {
      case EaseWaveType.none:
        return min;

      case EaseWaveType.sine:
        final rad = t * 2 * pi;
        final factor = (sin(rad - pi / 2) + 1.0) / 2.0;
        return min + range * factor;

      case EaseWaveType.triangle:
        final factor = t < 0.5 ? t * 2.0 : (1.0 - t) * 2.0;
        return min + range * factor;

      case EaseWaveType.square:
        return t < 0.5 ? max : min;

      case EaseWaveType.sawtooth:
        return min + range * t;

      case EaseWaveType.increment:
        if (lastValue == null || lastValue < min || lastValue >= max) {
          return min;
        }
        final next = lastValue + step;
        return (next > max) ? min : next;

      case EaseWaveType.random:
        final rnd = Random();
        return min + rnd.nextDouble() * range;
    }
  }

  Map<String, dynamic> toJson() => {
    'Enabled': enabled,
    'WaveType': waveType.index,
    'Min': min,
    'Max': max,
    'Step': step,
    'DurationMs': durationMs,
  };

  factory SimulationConfig.fromJson(Map<String, dynamic> json) {
    return SimulationConfig(
      enabled: json['Enabled'] as bool? ?? false,
      waveType: EaseWaveType.fromIndex(json['WaveType'] as int? ?? 0),
      min: (json['Min'] as num?)?.toDouble() ?? 0.0,
      max: (json['Max'] as num?)?.toDouble() ?? 100.0,
      step: (json['Step'] as num?)?.toDouble() ?? 1.0,
      durationMs: json['DurationMs'] as int? ?? 2000,
    );
  }

  SimulationConfig copyWith({
    bool? enabled,
    EaseWaveType? waveType,
    double? min,
    double? max,
    double? step,
    int? durationMs,
  }) {
    return SimulationConfig(
      enabled: enabled ?? this.enabled,
      waveType: waveType ?? this.waveType,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

typedef SimulationWaveform = EaseWaveType;
