import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'distance_engine.dart';
import 'offline_map.dart';
import 'navigation_screen.dart';
import 'qr_exchange.dart';
import 'trip_session.dart';
import 'trip_store.dart';

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
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw StateError('Turn on location services to run the meter.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
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
              if (mounted) setState(() => _error = 'GPS stopped: $e');
            },
          );
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
            '${_trip.distanceKm.toStringAsFixed(2)} km • Rs. ${_trip.fare.toStringAsFixed(2)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
        _trip.data['endTime'] ??= DateTime.now().toIso8601String();
        _trip.data['status'] = 'completed';
        _trip.data['totalFare'] = _trip.fare;
        _trip.data['receiptNumber'] = _trip.receiptNumber;
        await _positions?.cancel();
        _positions = null;
        await _save();
        await widget.onComplete?.call(_trip);
        if (mounted)
          await showTripQr(
            context,
            'Final trip receipt',
            _trip.qr('TRIP_RECEIPT'),
          );
      } else {
        final qr = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => TripQrScanner(
              title: 'Scan driver receipt',
              validate: (qr) => _trip.validateExchange(qr, 'TRIP_RECEIPT'),
            ),
          ),
        );
        if (qr == null) return;
        await _positions?.cancel();
        _positions = null;
        _trip.data.addAll({
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
    final elapsed = end.difference(_trip.startTime);
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _trip.completed ? 'Trip completed' : 'Trip in progress',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${_trip.data['driverName'] ?? 'Driver'} • ${_trip.data['vehicleNumber'] ?? ''}',
            ),
            Text(
              '${_trip.data['customerName'] ?? 'Passenger'} • ${elapsed.inMinutes}m ${elapsed.inSeconds.remainder(60)}s',
            ),
            const SizedBox(height: 12),
            Text(
              '${_trip.distanceKm.toStringAsFixed(2)} km',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Rs. ${_trip.fare.toStringAsFixed(2)} • Rs. ${_trip.rate.toStringAsFixed(2)} / km',
            ),
            if (!widget.driverMode && !_trip.completed)
              const Text(
                'Passenger GPS estimate. Scan the driver’s receipt for the final distance and fare.',
              ),
            if (!_trip.completed)
              const Text(
                'Keep this screen open while travelling. Tracking pauses when the app goes into the background.',
              ),
            if (_trip.data['trackingGap'] == true)
              const Text(
                'GPS tracking was interrupted. Distance during the gap was not billed.',
                style: TextStyle(color: Colors.orange),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_trip.completed && _positions == null)
              TextButton(onPressed: _startGps, child: const Text('Retry GPS')),
            const SizedBox(height: 12),
            OfflineTripMap(
              destination: OfflineDestination.fromJson(
                _trip.data['destination'],
                profile: _trip.data['navigationProfile'] as String? ?? 'tuk',
              ),
              profile: _trip.data['navigationProfile'] as String? ?? 'tuk',
              points: _fixes
                  .map(
                    (p) => LatLng(
                      (p['lat'] as num).toDouble(),
                      (p['lng'] as num).toDouble(),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (widget.driverMode && !_trip.completed)
              OutlinedButton(
                onPressed: () => showTripQr(
                  context,
                  'Passenger trip confirmation',
                  _trip.qr('TRIP_ACCEPTED'),
                ),
                child: const Text('Show acceptance QR'),
              ),
            if (widget.driverMode || !_trip.completed)
              FilledButton(
                onPressed: _busy ? null : _finish,
                child: Text(
                  _busy
                      ? 'Saving…'
                      : widget.driverMode
                      ? (_trip.completed
                            ? 'Show receipt / retry sync'
                            : 'End offline trip')
                      : 'Scan final receipt',
                ),
              ),
            if (_trip.completed)
              Text(
                'Receipt: ${_trip.data['receiptNumber'] ?? _trip.receiptNumber}',
              ),
          ],
        ),
      ),
    );
  }
}
