import 'dart:math';
import '../i18n/app_i18n.dart';

/// Auto-change Easing Function Types (matching industrial simulator behavior)
enum EaseType {
  sine('Sine Wave'),
  rampUp('Ramp Up'),
  rampDown('Ramp Down'),
  triangle('Triangle Wave'),
  squarePulse('Square Pulse'),
  randomWalk('Random Walk'),
  toggle('Toggle 0/1');

  final String englishDescription;
  const EaseType(this.englishDescription);

  String get description {
    final i18n = AppI18n.instance;
    switch (this) {
      case EaseType.sine:
        return i18n.t('waveSine');
      case EaseType.rampUp:
        return i18n.t('waveRampUp');
      case EaseType.rampDown:
        return i18n.t('waveRampDown');
      case EaseType.triangle:
        return i18n.t('waveTriangle');
      case EaseType.squarePulse:
        return i18n.t('waveSquare');
      case EaseType.randomWalk:
        return i18n.t('waveRandom');
      case EaseType.toggle:
        return i18n.t('waveToggle');
    }
  }

  String get label => description;
}

class EaseCalculator {
  static final Random _rng = Random();

  /// Calculates the simulated value at time [t] seconds
  static double calculate({
    required EaseType type,
    required double t,
    required double min,
    required double max,
    required double period,
  }) {
    if (period <= 0) period = 1.0;
    if (max <= min) max = min + 1.0;

    final range = max - min;
    final progress = (t % period) / period; // 0.0 .. 1.0

    switch (type) {
      case EaseType.sine:
        final angle = progress * 2 * pi;
        final norm = (sin(angle) + 1.0) / 2.0; // 0.0 .. 1.0
        return min + norm * range;

      case EaseType.rampUp:
        return min + progress * range;

      case EaseType.rampDown:
        return max - progress * range;

      case EaseType.triangle:
        final norm = progress < 0.5 ? (progress * 2.0) : ((1.0 - progress) * 2.0);
        return min + norm * range;

      case EaseType.squarePulse:
        return progress < 0.5 ? max : min;

      case EaseType.randomWalk:
        final noise = _rng.nextDouble();
        return min + noise * range;

      case EaseType.toggle:
        return progress < 0.5 ? 1.0 : 0.0;
    }
  }
}
