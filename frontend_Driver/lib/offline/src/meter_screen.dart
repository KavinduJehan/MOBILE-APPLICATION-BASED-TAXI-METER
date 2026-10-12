import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'distance_engine.dart';
import 'navigation_screen.dart';
import 'qr_exchange.dart';
import 'trip_session.dart';
import 'trip_store.dart';
import 'offline_widgets.dart';

class OfflineMeterScreen extends StatefulWidget {
  const OfflineMeterScreen({
    super.key,
    required this.trip,
    required this.owner,
    required this.driverMode,
    this.onComplete,
  });
  final TripSession trip;
  final String owner;
  final bool driverMode;

  /// Driver queues the completed snapshot for cloud sync. Must be retry-safe.
  final Future<void> Function(TripSession)? onComplete;
  @override
  State<OfflineMeterScreen> createState() => _OfflineMeterScreenState();
}

class _OfflineMeterScreenState extends State<OfflineMeterScreen>
    with WidgetsBindingObserver {
  late final TripSession _trip = widget.trip;
  late final DistanceEngine _engine = DistanceEngine(
    distanceMeters: _trip.distanceKm * 1000,
    lastFix: _trip.data['lastFix'] == null
        ? null
        : Map<String, dynamic>.from(_trip.data['lastFix'] as Map),
  );
  late final List<Map<String, dynamic>> _fixes = _trip.fixes;
  StreamSubscription<Position>? _positions;
  Timer? _timer;
  Future<void> _writes = Future.value();
  String? _error;
  bool _busy = false;
  bool _gpsStarting = false;
  bool _paused = false;
  String _gpsMessage = 'Waiting for GPS';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (!_trip.completed) _startGps();
  }

  Future<void> _save() {
    // Serialize immutable snapshots so older GPS fixes cannot overwrite completion.
    final snapshot = TripSession(Map<String, dynamic>.from(_trip.data));
    final next = _writes.then((_) => TripStore.save(widget.owner, snapshot));
    _writes = next.catchError((Object e) {
      if (mounted) setState(() => _error = 'Trip save failed: $e');
    });
    return next;
  }

  Future<void> _startGps() async {
    if (_gpsStarting || _positions != null || _trip.completed) return;
    _gpsStarting = true;
    if (mounted) setState(() => _gpsMessage = 'Waiting for GPS');
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services to run the meter.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is needed. Enable it in app settings, then retry GPS.',
        );
      }
      if (!mounted || _paused || _trip.completed) return;
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 3,
            ),
          ).listen(
            (position) {
              if (!mounted || _paused || _trip.completed) return;
              if (position.isMocked ||
                  !position.accuracy.isFinite ||
                  position.accuracy > 30) {
                setState(() => _gpsMessage = 'Location accuracy is low');
              } else {
                setState(() => _gpsMessage = 'GPS tracking active');
              }
              if (_engine.addFix(
                lat: position.latitude,
                lng: position.longitude,
                accuracy: position.accuracy,
                time: position.timestamp,
                mocked: position.isMocked,
              )) {
                _fixes.add(Map<String, dynamic>.from(_engine.lastFix!));
                // Keep map rendering and persistent checkpoints bounded on long trips.
                if (_fixes.length > 1500) _fixes.removeAt(1);
                _trip.data.addAll({
                  'startLocation': _trip.data['startLocation'] ?? _fixes.first,
                  'distanceKm': _engine.distanceMeters / 1000,
                  'lastFix': _engine.lastFix,
                  'fixes': List.of(_fixes),
                  'trackingGap':
                      _engine.gapDetected || _trip.data['trackingGap'] == true,
                });
                _save().catchError((Object _) {});
                if (mounted) setState(() {});
              }
            },
            onError: (Object e) {
              _positions?.cancel();
              _positions = null;
              if (mounted) {
                setState(() {
                  _gpsMessage = 'GPS paused';
                  _error = 'Location is unavailable. Check GPS and try again.';
                });
              }
            },
          );
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsMessage = 'GPS paused';
          _error = offlineErrorMessage(
            e,
            'Check GPS and location permission, then retry.',
          );
        });
      }
    } finally {
      _gpsStarting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _startGps();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _paused = true;
      _positions?.cancel();
      _positions = null;
      if (!_trip.completed) {
        _engine.resetAnchor();
        _trip.data['lastFix'] = null;
        _trip.data['trackingGap'] = true;
        _save().catchError((Object _) {});
      }
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    if (widget.driverMode && !_trip.completed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End offline trip?'),
          content: Text(
            '${_trip.distanceKm.toStringAsFixed(2)} km • Rs. ${_trip.fare.toStringAsFixed(2)}\n\nYou will get a receipt QR for the passenger to scan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OfflineUi.danger,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End trip'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (widget.driverMode) {
        _trip.data['endTime'] ??= DateTime.now().toUtc().toIso8601String();
        _trip.data['status'] = 'completed';
        _trip.data['totalFare'] = _trip.fare;
        _trip.data['receiptNumber'] = _trip.receiptNumber;
        await _positions?.cancel();
        _positions = null;
        await _save();
        await widget.onComplete?.call(_trip);
        if (mounted) {
          await showTripQr(
            context,
            'Final trip receipt',
            _trip.qr('TRIP_RECEIPT'),
            hint: 'Trip saved. Ask the passenger to scan this receipt.',
          );
        }
      } else {
        final qr = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => TripQrScanner(
              title: 'Scan driver receipt',
              hint: 'Scan the final receipt on the driver’s phone',
              validate: (qr) => _trip.validateExchange(qr, 'TRIP_RECEIPT'),
            ),
          ),
        );
        if (qr == null) return;
        await _positions?.cancel();
        _positions = null;
        _trip.data.addAll({
          'startTime': qr['startTime'],
          'awaitingDriverReceipt': false,
          'driverName': qr['driverName'],
          'vehicleNumber': qr['vehicleNumber'],
          'distanceKm': qr['distanceKm'],
          'totalFare': qr['totalFare'],
          'endTime': qr['endTime'],
          'receiptNumber': qr['receiptNumber'],
          'status': 'completed',
          'receiptConfirmed': true,
        });
        await _save();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    if (!_trip.completed) {
      _trip.data['lastFix'] = null;
      _trip.data['trackingGap'] = true;
      _save().catchError((Object _) {});
    }
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _positions?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end =
        DateTime.tryParse(_trip.data['endTime']?.toString() ?? '') ??
        DateTime.now();
    final difference = end.difference(_trip.startTime);
    final elapsed = difference.isNegative ? Duration.zero : difference;
    if (!_trip.completed) {
      final last = _fixes.isEmpty ? null : _fixes.last;
      return OfflineNavigationScreen(
        initialPosition: last == null
            ? null
            : LatLng(
                (last['lat'] as num).toDouble(),
                (last['lng'] as num).toDouble(),
              ),
        destination: OfflineDestination.fromJson(_trip.data['destination']),
        tripControls: _controls(context, elapsed),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Trip information',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Offline trip'),
                content: const Text(
                  'Your starting point is detected by GPS. Keep this screen or navigation open while travelling. The customer meter is an estimate until the driver’s final receipt is scanned.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OfflineHeader(
                icon: Icons.check_circle_rounded,
                title: 'Trip completed',
                subtitle:
                    '${_trip.data['driverName'] ?? 'Driver'} • ${_trip.data['vehicleNumber'] ?? ''}',
              ),
              const SizedBox(height: 16),
              OfflinePanel(
                highlight: true,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Final fare',
                      style: TextStyle(color: OfflineUi.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${_trip.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Divider(height: 28),
                    OfflineInfoRow(
                      icon: Icons.route_rounded,
                      label: 'Distance',
                      value: '${_trip.distanceKm.toStringAsFixed(2)} km',
                    ),
                    OfflineInfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: _fmt(elapsed),
                    ),
                    OfflineInfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Agreed rate',
                      value: 'Rs. ${_trip.rate.toStringAsFixed(2)} / km',
                    ),
                    OfflineInfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Passenger',
                      value: '${_trip.data['customerName'] ?? 'Passenger'}',
                    ),
                    OfflineInfoRow(
                      icon: Icons.tag_rounded,
                      label: 'Receipt',
                      value:
                          '${_trip.data['receiptNumber'] ?? _trip.receiptNumber}',
                    ),
                  ],
                ),
              ),
              if (_trip.data['trackingGap'] == true) ...[
                const SizedBox(height: 12),
                const OfflineNotice(
                  'GPS tracking was interrupted. Distance during the gap was not billed.',
                  tone: OfflineTone.warning,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                OfflineNotice(_error!, tone: OfflineTone.danger),
              ],
              if (widget.driverMode) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _finish,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    _busy ? 'Saving…' : 'Show receipt / retry sync',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) => d.inHours > 0
      ? '${d.inHours}h ${d.inMinutes.remainder(60)}m'
      : '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';

  void _showInfo(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: OfflineUi.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            OfflineInfoRow(
              icon: Icons.directions_car_rounded,
              label: 'Driver',
              value:
                  '${_trip.data['driverName'] ?? 'Driver'} • ${_trip.data['vehicleNumber'] ?? ''}',
            ),
            OfflineInfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Passenger',
              value: '${_trip.data['customerName'] ?? 'Passenger'}',
            ),
            OfflineInfoRow(
              icon: Icons.payments_outlined,
              label: 'Rate',
              value: 'Rs. ${_trip.rate.toStringAsFixed(2)} / km',
            ),
            const SizedBox(height: 10),
            const OfflineNotice(
              'Keep the trip screen open while travelling. Customer totals are estimates until the final receipt is scanned.',
            ),
            if (_trip.data['trackingGap'] == true) ...[
              const SizedBox(height: 8),
              const OfflineNotice(
                'Tracking was interrupted. Distance during the gap was not billed.',
                tone: OfflineTone.warning,
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _stat(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 18, color: OfflineUi.accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(
          label,
          style: const TextStyle(color: OfflineUi.muted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _controls(BuildContext context, Duration elapsed) {
    final gpsOk = _gpsMessage == 'GPS tracking active';
    return Material(
      color: OfflineUi.panel,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: OfflineUi.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverMode ? 'Trip fare' : 'Estimated fare',
                        style: const TextStyle(
                          color: OfflineUi.muted,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Rs. ${_trip.fare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                OfflineStatusPill(
                  gpsOk ? 'GPS active' : _gpsMessage,
                  tone: gpsOk ? OfflineTone.success : OfflineTone.warning,
                  icon: gpsOk ? Icons.gps_fixed : Icons.gps_not_fixed,
                ),
                IconButton(
                  tooltip: 'Trip information',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showInfo(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _stat(
                    Icons.route_rounded,
                    '${_trip.distanceKm.toStringAsFixed(2)} km',
                    'Distance',
                  ),
                  _stat(Icons.timer_outlined, _fmt(elapsed), 'Time'),
                  _stat(
                    Icons.payments_outlined,
                    'Rs. ${_trip.rate.toStringAsFixed(0)}',
                    'Per km',
                  ),
                ],
              ),
            ),
            if (_error != null || _positions == null) ...[
              const SizedBox(height: 10),
              OfflineNotice(
                _error ?? 'GPS is paused, so the meter is not counting.',
                tone: OfflineTone.warning,
                action: _positions == null ? 'Retry GPS' : null,
                onAction: _gpsStarting ? null : _startGps,
              ),
            ] else if (_trip.data['trackingGap'] == true) ...[
              const SizedBox(height: 10),
              const OfflineNotice(
                'Tracking was interrupted earlier. That stretch was not billed.',
                tone: OfflineTone.warning,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.driverMode) ...[
                  IconButton.filledTonal(
                    tooltip: 'Show acceptance QR',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                    ),
                    onPressed: _busy
                        ? null
                        : () => showTripQr(
                            context,
                            'Passenger trip confirmation',
                            _trip.qr('TRIP_ACCEPTED'),
                          ),
                    icon: const Icon(Icons.qr_code),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: widget.driverMode
                          ? OfflineUi.danger
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(
                      widget.driverMode
                          ? Icons.stop_circle_outlined
                          : Icons.qr_code_scanner,
                    ),
                    label: Text(
                      _busy
                          ? 'Saving...'
                          : widget.driverMode
                          ? 'End offline trip'
                          : 'Scan final receipt',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                '© OpenStreetMap contributors / ODbL',
                style: TextStyle(fontSize: 10, color: OfflineUi.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
