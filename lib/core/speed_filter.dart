import 'dart:math' as math;

/// One raw location fix from the OS (F-01). Pure data, no plugin types,
/// so the filter and state machine stay unit-testable.
class RawFix {
  const RawFix({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.horizontalAccuracyM,
    this.speedMps,
    this.speedAccuracyMps,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double horizontalAccuracyM;

  /// Doppler speed from the OS. `null` (or negative) when unavailable.
  final double? speedMps;
  final double? speedAccuracyMps;
}

/// Tunable filter parameters. Adjusted during M3 real-drive tests.
class SpeedFilterConfig {
  const SpeedFilterConfig({
    this.maxHorizontalAccuracyM = 30,
    this.maxSpeedAccuracyMps = 2.0,
    this.emaWindow = 4,
    this.staleAfter = const Duration(seconds: 3),
    this.maxPlausibleKph = 300,
  });

  final double maxHorizontalAccuracyM;
  final double maxSpeedAccuracyMps;

  /// EMA over roughly the last N samples (PRD: 3~5). alpha = 2 / (N + 1).
  final int emaWindow;

  /// No accepted sample for this long → "속도 없음".
  final Duration staleAfter;
  final double maxPlausibleKph;

  double get alpha => 2 / (emaWindow + 1);
}

/// F-02: drops low-accuracy samples, smooths with EMA, and reports
/// "no speed" (null) when the last accepted sample is too old.
class SpeedFilter {
  SpeedFilter([this.config = const SpeedFilterConfig()]);

  final SpeedFilterConfig config;

  double? _emaKph;
  DateTime? _lastAccepted;
  RawFix? _prevFix;

  void reset() {
    _emaKph = null;
    _lastAccepted = null;
    _prevFix = null;
  }

  /// Feeds one fix. Returns the smoothed kph, or null if the fix was rejected
  /// and there is no current value.
  double? add(RawFix fix) {
    final prev = _prevFix;
    _prevFix = fix;

    if (fix.horizontalAccuracyM > config.maxHorizontalAccuracyM) {
      return current(fix.timestamp);
    }

    double? kph;
    final doppler = fix.speedMps;
    if (doppler != null && doppler >= 0) {
      final acc = fix.speedAccuracyMps;
      // speedAccuracy of 0 / null means "unknown" on some devices: accept.
      if (acc != null && acc > 0 && acc > config.maxSpeedAccuracyMps) {
        return current(fix.timestamp);
      }
      kph = doppler * 3.6;
    } else if (prev != null) {
      // Fallback only when Doppler speed is missing: distance / time.
      final dt = fix.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
      if (dt > 0) {
        kph = _haversineM(prev, fix) / dt * 3.6;
      }
    }

    if (kph == null || kph > config.maxPlausibleKph) {
      return current(fix.timestamp);
    }

    final ema = _emaKph;
    _emaKph = ema == null ? kph : ema + config.alpha * (kph - ema);
    _lastAccepted = fix.timestamp;
    return _emaKph;
  }

  /// Smoothed kph at [now], or null when stale / never received.
  double? current(DateTime now) {
    final last = _lastAccepted;
    if (last == null || now.difference(last) > config.staleAfter) {
      return null;
    }
    return _emaKph;
  }

  static double _haversineM(RawFix a, RawFix b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
