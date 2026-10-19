import 'dart:math' as math;

/// Foreground GPS odometer. Rejects inaccurate fixes, jitter and impossible jumps.
class DistanceEngine {
  DistanceEngine({this.distanceMeters = 0, Map<String, dynamic>? lastFix})
    : _lastFix = lastFix;

  double distanceMeters;
  Map<String, dynamic>? _lastFix;
  Map<String, dynamic>? get lastFix => _lastFix;
  bool gapDetected = false;

  void resetAnchor() {
    _lastFix = null;
    gapDetected = true;
  }

  bool addFix({
    required double lat,
    required double lng,
    required double accuracy,
    required DateTime time,
    bool mocked = false,
  }) {
    if (mocked ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 30) {
      return false;
    }
    final fix = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'time': time.toIso8601String(),
    };
    final last = _lastFix;
    if (last == null) {
      _lastFix = fix;
      return true;
    }
    final seconds =
        time.difference(DateTime.parse(last['time'] as String)).inMilliseconds /
        1000;
    if (seconds <= 0) return false;
    // Never bill the straight line across a pause or app termination.
    if (seconds > 30) {
      gapDetected = true;
      _lastFix = fix;
      return true;
    }
    final meters = haversine(
      (last['lat'] as num).toDouble(),
      (last['lng'] as num).toDouble(),
      lat,
      lng,
    );
    if (meters / seconds > 55) return false;
    final jitter = math.max(
      5.0,
      math.min(12.0, ((last['accuracy'] as num).toDouble() + accuracy) / 2),
    );
    if (meters < jitter) return false;
    distanceMeters += meters;
    _lastFix = fix;
    return true;
  }

  static double haversine(double lat1, double lng1, double lat2, double lng2) {
    const rad = math.pi / 180;
    final a =
        math.pow(math.sin((lat2 - lat1) * rad / 2), 2) +
        math.cos(lat1 * rad) *
            math.cos(lat2 * rad) *
            math.pow(math.sin((lng2 - lng1) * rad / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}
