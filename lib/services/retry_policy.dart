import 'dart:math';

/// Exponential backoff: base, 2×base, 4×base … capped at [maxDelay],
/// with optional ± [jitter] so many devices don't retry in lock-step.
class RetryPolicy {
  const RetryPolicy({
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.jitter = 0.2,
  });

  final Duration baseDelay;
  final Duration maxDelay;

  /// 0.0 disables jitter (useful in tests).
  final double jitter;

  /// Delay before retry number [attempt] (1-based).
  Duration delayFor(int attempt, [Random? random]) {
    final exponent = (attempt.clamp(1, 20)) - 1;
    final raw = baseDelay.inMilliseconds * pow(2, exponent);
    final capped = min(raw.toDouble(), maxDelay.inMilliseconds.toDouble());
    if (jitter <= 0 || random == null) {
      return Duration(milliseconds: capped.round());
    }
    final factor = 1 + (random.nextDouble() * 2 - 1) * jitter;
    return Duration(milliseconds: (capped * factor).round());
  }
}
