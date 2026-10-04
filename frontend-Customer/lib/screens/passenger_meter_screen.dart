import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme.dart';

/// Offline passenger-side taxi meter that calculates real-time distance and fare
/// on the passenger's own phone to compare and verify against the driver's meter.
class PassengerMeterScreen extends StatefulWidget {
  final Map<String, dynamic> driver;
  final String customerName;
  final double agreedRatePerKm;

  const PassengerMeterScreen({
    super.key,
    required this.driver,
    required this.customerName,
    required this.agreedRatePerKm,
  });

  @override
  State<PassengerMeterScreen> createState() => _PassengerMeterScreenState();
}

class _PassengerMeterScreenState extends State<PassengerMeterScreen> {
  late final DateTime _startTime;
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  double _totalDistanceMeters = 0.0;
  double _distanceKm = 0.0;
  double _currentFare = 0.0;
  double _currentSpeedKmh = 0.0;
  bool _isGpsActive = false;
  String _locationStatus = 'Initializing GPS...';
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // 1-second elapsed timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startTime));
    });

    _startGpsTracking();
  }

  @override
  void dispose() {
    _timer.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _startGpsTracking() async {
    setState(() {
      _locationStatus = 'Checking GPS service...';
      _locationError = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _isGpsActive = false;
        _locationStatus = 'GPS Disabled';
        _locationError = 'Please enable GPS on your device to track distance.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _isGpsActive = false;
        _locationStatus = 'Permission Denied';
        _locationError = 'Location permission is required for passenger meter.';
      });
      return;
    }

    setState(() {
      _locationStatus = 'Acquiring satellite signal...';
      _locationError = null;
    });

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) _onNewPosition(initial);
    } catch (_) {}

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      _onNewPosition,
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isGpsActive = false;
          _locationError = 'GPS signal interrupted: $err';
        });
      },
    );
  }

  void _onNewPosition(Position position) {
    if (!mounted) return;

    if (position.accuracy > 25.0) {
      setState(() {
        _locationStatus = 'Weak Signal (±${position.accuracy.toStringAsFixed(0)}m)';
      });
      return;
    }

    final speedKmh = (position.speed.isFinite && position.speed > 0)
        ? (position.speed * 3.6).clamp(0.0, 160.0)
        : 0.0;

    setState(() {
      _isGpsActive = true;
      _locationStatus = 'GPS Active (±${position.accuracy.toStringAsFixed(0)}m)';
      _locationError = null;
      _currentSpeedKmh = speedKmh;
    });

    if (_lastPosition == null) {
      _lastPosition = position;
      return;
    }

    final meters = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Filter stationary jitter (<0.5 m/s speed and <4m jitter)
    final isStationary =
        (position.speed >= 0 && position.speed < 0.5) && meters < 4.0;
    if (isStationary) return;

    // Filter unrealistic teleport spikes (> 162 km/h)
    final timeDiffMs =
        position.timestamp.difference(_lastPosition!.timestamp).inMilliseconds;
    if (timeDiffMs > 0) {
      final speedMps = meters / (timeDiffMs / 1000.0);
      if (speedMps > 45.0) {
        _lastPosition = position;
        return;
      }
    }

    _totalDistanceMeters += meters;
    _lastPosition = position;
    _distanceKm = _totalDistanceMeters / 1000.0;

    final rawFare = _distanceKm * widget.agreedRatePerKm;
    setState(() {
      _currentFare = double.parse(rawFare.toStringAsFixed(2));
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.driver['name'] as String? ?? 'Driver';
    final vehicleNumber = widget.driver['vehicleNumber'] as String? ?? '—';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Passenger Taxi Meter', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── GPS Status Banner ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _isGpsActive
                      ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isGpsActive
                        ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isGpsActive
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationStatus,
                        style: TextStyle(
                          color: _isGpsActive
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF87171),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_currentSpeedKmh > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentSpeedKmh.toStringAsFixed(0)} km/h',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_locationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF451A03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationError!,
                          style: const TextStyle(
                              color: Color(0xFFFDE68A), fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _startGpsTracking,
                        child: const Text('RETRY',
                            style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Main Live Fare Card ─────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'ESTIMATED METER FARE',
                      style: TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'Rs. ',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _currentFare.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agreed Rate: Rs. ${widget.agreedRatePerKm.toStringAsFixed(0)} / km',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Metrics Row (Distance & Duration) ───────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.route_rounded,
                                  color: Color(0xFF4ADE80), size: 18),
                              SizedBox(width: 6),
                              Text('DISTANCE',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _distanceKm.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('km',
                                  style: TextStyle(
                                      color: Color(0xFF4ADE80),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  color: Color(0xFFFBBF24), size: 18),
                              SizedBox(width: 6),
                              Text('DURATION',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _elapsedLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Driver Details ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.local_taxi, 'Driver', '$driverName ($vehicleNumber)'),
                    const Divider(color: Colors.white10, height: 18),
                    _infoRow(Icons.verified_user_rounded, 'Meter Verification',
                        'Compare live with driver meter',
                        highlightColor: const Color(0xFF38BDF8)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Finish / Return ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Exit Meter / Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? highlightColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white60),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: highlightColor ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
