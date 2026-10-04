import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../services/offline_database.dart';
import '../widgets/app_widgets.dart';
import 'trip_summary_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key, required this.trip, this.receiptNumber});

  final TripRecord trip;
  final String? receiptNumber;

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  late final DateTime _startTime;
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  // ── GPS Taxi Meter Tracking ────────────────────────────────────────────────
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  Position? _currentPosition;
  Position? _startPosition;
  double _totalDistanceMeters = 0.0;
  double _distanceKm = 0.0;
  double _currentFare = 0.0;
  double _currentSpeedKmh = 0.0;
  bool _isGpsActive = false;
  String _locationStatus = 'Initializing GPS...';
  String? _locationError;
  DateTime? _lastDbSaveTime;

  String _startAddress = '';
  String _endAddress = '';

  @override
  void initState() {
    super.initState();
    _startTime = widget.trip.date ?? DateTime.now();
    _startAddress = widget.trip.startAddress.isNotEmpty ? widget.trip.startAddress : 'Street Pickup';
    _endAddress = widget.trip.endAddress.isNotEmpty ? widget.trip.endAddress : 'In transit...';
    _distanceKm = widget.trip.distanceKm;
    _totalDistanceMeters = widget.trip.distanceKm * 1000.0;
    _recalculateFare();

    // 1-second UI stopwatch timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startTime));
    });
    _elapsed = DateTime.now().difference(_startTime);

    // Initialize real GPS tracking
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
        _locationError = 'Device location is disabled. Please turn on GPS to track distance.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _isGpsActive = false;
        _locationStatus = 'Permission Denied';
        _locationError = 'Location permission is required for the digital taxi meter.';
      });
      return;
    }

    setState(() {
      _locationStatus = 'Acquiring satellite lock...';
      _locationError = null;
    });

    // 1. Immediate initial position fix
    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        _onNewPosition(initial);
        if (_startAddress == 'Street Pickup') {
          _startAddress = 'Pickup (${initial.latitude.toStringAsFixed(4)}, ${initial.longitude.toStringAsFixed(4)})';
        }
      }
    } catch (_) {
      // Position stream will provide fixes once satellite locked
    }

    // 2. High-precision continuous position stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Trigger every 3 meters of movement
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
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

    // Discard inaccurate satellite fixes (> 25 meters accuracy radius)
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
      _currentPosition = position;
      _currentSpeedKmh = speedKmh;
      _endAddress = 'In transit (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    });

    _startPosition ??= position;

    if (_lastPosition == null) {
      _lastPosition = position;
      return;
    }

    // Distance between previous and current fix in meters
    final meters = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Stationary jitter filter:
    // When car is stationary at traffic light or parked, GPS drifts by 1-4 meters.
    // If speed is < 0.5 m/s (~1.8 km/h) and distance < 4m, it is stationary jitter.
    final isStationary = (position.speed >= 0 && position.speed < 0.5) && meters < 4.0;
    if (isStationary) {
      return;
    }

    // Teleport / GPS jump filter:
    final timeDiffMs = position.timestamp.difference(_lastPosition!.timestamp).inMilliseconds;
    if (timeDiffMs > 0) {
      final speedMps = meters / (timeDiffMs / 1000.0);
      if (speedMps > 45.0) { // > 162 km/h is unrealistic jump
        _lastPosition = position;
        return;
      }
    }

    // Valid movement! Accumulate real distance
    _totalDistanceMeters += meters;
    _lastPosition = position;
    _distanceKm = _totalDistanceMeters / 1000.0;

    _recalculateFare();

    // Persist progress to local SQLite periodically (every 10 seconds)
    final now = DateTime.now();
    if (_lastDbSaveTime == null || now.difference(_lastDbSaveTime!).inSeconds >= 10) {
      _lastDbSaveTime = now;
      _persistProgressToDb();
    }
  }

  void _recalculateFare() {
    final rate = widget.trip.ratePerKm;
    final surgeMultiplier = (widget.trip.surgeBreakdown?['multiplier'] as num?)?.toDouble() ?? 1.0;
    final rawFare = _distanceKm * rate * surgeMultiplier;
    setState(() {
      _currentFare = double.parse(rawFare.toStringAsFixed(2));
    });
  }

  Future<void> _persistProgressToDb() async {
    try {
      await OfflineDatabase.instance.updateOfflineTripProgress(
        localId: widget.trip.id,
        distanceKm: _distanceKm,
        fare: _currentFare,
        endAddress: _endAddress,
        status: 'in_progress',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trip = widget.trip;
    final surgeMultiplier = (trip.surgeBreakdown?['multiplier'] as num?)?.toDouble() ?? 1.0;

    return AppShellScaffold(
      appBar: AppBar(
        title: const Text('Live Taxi Meter'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 14),
                SizedBox(width: 4),
                Text(
                  'OFFLINE METER',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── GPS Status Banner ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isGpsActive
                    ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
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
                      color: _isGpsActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationStatus,
                      style: TextStyle(
                        color: _isGpsActive ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_currentSpeedKmh > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

            // ── Location Error / Permission Alert ──────────────────────────────
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
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: _startGpsTracking,
                      child: const Text('RETRY', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Digital Fare Display (Main Taxi Meter) ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2338), Color(0xFF0A1320)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.5),
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
                    'CURRENT FARE',
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
                    'Rate: Rs. ${trip.ratePerKm.toStringAsFixed(0)} / km'
                    '${surgeMultiplier > 1.0 ? ' · Surge: ${surgeMultiplier.toStringAsFixed(2)}×' : ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Primary Trip Metrics (Distance & Duration) ─────────────────────
            Row(
              children: [
                // Live Distance Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.route_rounded, color: Color(0xFF4ADE80), size: 18),
                            SizedBox(width: 6),
                            Text('DISTANCE', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
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
                            const Text(
                              'km',
                              style: TextStyle(color: Color(0xFF4ADE80), fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Live Elapsed Time Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.timer_outlined, color: Color(0xFFFBBF24), size: 18),
                            SizedBox(width: 6),
                            Text('DURATION', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
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

            // ── Trip Details & Route ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFF1E293B),
                        child: Icon(Icons.person, color: Colors.white70, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.customerName.isNotEmpty ? trip.customerName : 'Passenger',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Text('Street Hail / Offline Passenger', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _detailRow('Pickup', _startAddress, icon: Icons.my_location_rounded),
                  const SizedBox(height: 8),
                  _detailRow('Current location', _endAddress, icon: Icons.location_on_rounded),
                  const SizedBox(height: 8),
                  _detailRow('Payment', 'Cash (Direct to Driver)', icon: Icons.payments_rounded),
                  if (widget.receiptNumber != null) ...[
                    const SizedBox(height: 8),
                    _detailRow('Receipt #', widget.receiptNumber!, icon: Icons.receipt_long_rounded),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── End Trip Button ────────────────────────────────────────────────
            PrimaryActionButton(
              label: 'End Trip & Generate Receipt',
              isBusy: auth.busy,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: const Color(0xFF131D2E),
                    title: const Text('End trip & calculate fare?'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Are you sure you want to complete this ride?'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              _dialogRow('Total Distance:', '${_distanceKm.toStringAsFixed(2)} km'),
                              const SizedBox(height: 6),
                              _dialogRow('Duration:', _elapsedLabel),
                              const SizedBox(height: 6),
                              _dialogRow(
                                'Final Fare:',
                                'Rs. ${_currentFare.toStringAsFixed(2)}',
                                highlight: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('End Trip'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;

                // Stop tracking
                _positionSubscription?.cancel();
                _positionSubscription = null;

                final finalReceipt = widget.receiptNumber?.trim().isNotEmpty == true
                    ? widget.receiptNumber!.trim()
                    : (trip.receiptNumber?.trim().isNotEmpty == true
                        ? trip.receiptNumber!.trim()
                        : 'REC-OFFLINE-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}');

                final completedTrip = TripRecord(
                  id: trip.id,
                  customerName: trip.customerName.isNotEmpty ? trip.customerName : 'Passenger',
                  startAddress: _startAddress,
                  endAddress: _currentPosition != null
                      ? 'Dropoff (${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)})'
                      : _endAddress,
                  distanceKm: _distanceKm,
                  ratePerKm: trip.ratePerKm,
                  fare: _currentFare,
                  status: 'completed',
                  date: DateTime.now(),
                  receiptNumber: finalReceipt,
                  surgeBreakdown: trip.surgeBreakdown,
                );

                // Always save the final completed record to local SQLite
                await OfflineDatabase.instance.insertOfflineTrip(
                  localId: completedTrip.id,
                  customerName: completedTrip.customerName,
                  startAddress: completedTrip.startAddress,
                  endAddress: completedTrip.endAddress,
                  distanceKm: completedTrip.distanceKm,
                  ratePerKm: completedTrip.ratePerKm,
                  fare: completedTrip.fare,
                  receiptNumber: finalReceipt,
                  surgeBreakdown: completedTrip.surgeBreakdown,
                  status: 'completed',
                  date: completedTrip.date,
                );

                // If online and not an offline-generated id, attempt cloud completion
                if (!trip.id.startsWith('offline-')) {
                  try {
                    final result = await auth.api.endTrip(
                      trip.id,
                      distanceKm: _distanceKm,
                      totalFare: _currentFare,
                    );
                    await OfflineDatabase.instance.cacheServerTrip(result.trip);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => TripSummaryScreen(
                          trip: result.trip,
                          receiptNumber: result.receiptNumber ?? finalReceipt,
                        ),
                      ),
                    );
                    return;
                  } catch (_) {
                    // Falls through to offline summary below
                  }
                }

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Trip completed and saved offline. Will sync when online.'),
                    backgroundColor: Color(0xFFEAB308),
                  ),
                );

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => TripSummaryScreen(
                      trip: completedTrip,
                      receiptNumber: finalReceipt,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
        ],
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _dialogRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFF4ADE80) : Colors.white,
            fontSize: highlight ? 16 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
