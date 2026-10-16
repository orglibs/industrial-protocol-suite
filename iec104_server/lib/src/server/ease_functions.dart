import 'dart:math';

/// Auto-change Easing Function Types (matching industrial simulator behavior)
enum EaseType {
  sine('正弦波 (Sine Wave)'),
  rampUp('递增 (Ramp Up)'),
  rampDown('递减 (Ramp Down)'),
  triangle('三角波 (Triangle)'),
  squarePulse('方波 (Square Pulse)'),
  randomWalk('随机波动 (Random Walk)'),
  toggle('交替 (Toggle 0/1)');

  final String description;
  const EaseType(this.description);
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
