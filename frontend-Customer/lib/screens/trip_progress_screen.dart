import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/receipt_model.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../repositories/trip_repository.dart';
import '../services/api_service.dart';
import '../services/customer_socket_service.dart';
import '../theme.dart';
import '../utils/google_polyline.dart';
import 'trip_summary_screen.dart';

const Map<String, (double, double)> _districts = {
  'Ampara': (7.2912, 81.6724),
  'Anuradhapura': (8.3114, 80.4037),
  'Badulla': (6.9934, 81.0550),
  'Batticaloa': (7.7310, 81.6747),
  'Colombo': (6.9271, 79.8612),
  'Galle': (6.0535, 80.2210),
  'Gampaha': (7.0840, 79.9925),
  'Hambantota': (6.1429, 81.1212),
  'Jaffna': (9.6615, 80.0255),
  'Kalutara': (6.5854, 79.9607),
  'Kandy': (7.2906, 80.6337),
  'Kegalle': (7.2513, 80.3464),
  'Kilinochchi': (9.3803, 80.3770),
  'Kurunegala': (7.4863, 80.3623),
  'Mannar': (8.9810, 79.9044),
  'Matale': (7.4675, 80.6234),
  'Matara': (5.9549, 80.5550),
  'Monaragala': (6.8728, 81.3507),
  'Mullaitivu': (9.2671, 80.8142),
  'Nuwara Eliya': (6.9497, 80.7891),
  'Polonnaruwa': (7.9403, 81.0188),
  'Puttalam': (8.0362, 79.8283),
  'Ratnapura': (6.7056, 80.3847),
  'Trincomalee': (8.5874, 81.2152),
  'Vavuniya': (8.7514, 80.4971),
};

class TripProgressScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> driver;
  final TripModel? trip;
  final double distanceKm;
  final double ratePerKm;
  final double totalFare;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  const TripProgressScreen({
    super.key,
    required this.requestId,
    required this.driver,
    this.trip,
    required this.distanceKm,
    required this.ratePerKm,
    required this.totalFare,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
  });

  @override
  State<TripProgressScreen> createState() => _TripProgressScreenState();
}

class _TripProgressScreenState extends State<TripProgressScreen>
    with SingleTickerProviderStateMixin {
  final _repository = const TripRepository();
  GoogleMapController? _mapController;
  LatLng? _driverPosition;

  // The car marker glides from its last position to the newest one instead
  // of jumping between location updates.
  LatLng? _shownDriver;
  LatLng? _moveFrom;
  LatLng? _moveTo;
  late final AnimationController _moveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addListener(_onMoveTick);

  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _youIcon;
  bool _showMyLocation = false;
  LatLng? _lastFitAt;

  /// True once the driver is waiting at the pickup point.
  bool _arrived = false;
  // Pickup -> destination: the planned trip.
  List<LatLng> _routePoints = const [];
  // Driver -> next stop (pickup, then destination): redrawn as the driver moves.
  List<LatLng> _liveRoute = const [];
  double? _liveDistanceKm;
  String? _liveEta;
  LatLng? _liveRouteOrigin;
  DateTime? _liveRouteAt;
  bool _loadingLiveRoute = false;

  /// False while the driver is still coming to the pickup point.
  bool _pickedUp = false;
  bool _userMovedMap = false;
  bool _loadingRoute = false;
  bool _ending = false;

  /// Set once the trip is over (ended or cancelled by either side) so the
  /// socket, the status check and the End Trip button can't all act on it.
  bool _finished = false;
  Timer? _statusPoll;
  String? _error;

  LatLng get _pickup {
    if (widget.pickupLat != null && widget.pickupLng != null) {
      return LatLng(widget.pickupLat!, widget.pickupLng!);
    }
    final loc = widget.trip?.pickupLocation;
    if (loc != null && _districts.containsKey(loc)) {
      final (lat, lng) = _districts[loc]!;
      return LatLng(lat, lng);
    }
    return const LatLng(6.9271, 79.8612);
  }

  LatLng get _destination {
    if (widget.destLat != null && widget.destLng != null) {
      return LatLng(widget.destLat!, widget.destLng!);
    }
    final loc = widget.trip?.dropLocation;
    if (loc != null && _districts.containsKey(loc)) {
      final (lat, lng) = _districts[loc]!;
      return LatLng(lat, lng);
    }
    return const LatLng(6.0535, 80.2210);
  }

  @override
  void initState() {
    super.initState();
    _driverPosition = _resolveDriverInitial();
    _shownDriver = _driverPosition;
    _pickedUp = widget.trip?.pickedUpAt != null;
    _arrived = _pickedUp || widget.trip?.arrivedAt != null;
    _loadMarkerIcons();
    _checkMyLocation();
    _initSocketAndTrip();
    _loadRoadRoute();
    _refreshLiveRoute(force: true);
    // The socket can drop; checking the trip keeps the driver's position and
    // the trip's status correct regardless.
    _checkTrip();
    _statusPoll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkTrip(),
    );
  }

  String? get _tripId {
    final id = widget.trip?.id;
    return id == null || id.isEmpty ? null : id;
  }

  static double _metersBetween(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// A round badge with an icon, used for the car and the customer markers.
  static Future<BitmapDescriptor> _badgeIcon(IconData icon, Color color) async {
    const size = 120.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      center,
      size / 2 - 4,
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, size / 2 - 8, Paint()..color = Colors.white);
    canvas.drawCircle(center, size / 2 - 15, Paint()..color = color);
    final glyph = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 60,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 46,
      height: 46,
    );
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final car = await _badgeIcon(
        Icons.local_taxi_rounded,
        const Color(0xFF111827),
      );
      final you = await _badgeIcon(
        Icons.person_rounded,
        const Color(0xFF22C55E),
      );
      if (!mounted) return;
      setState(() {
        _carIcon = car;
        _youIcon = you;
      });
    } catch (_) {
      // The default pins are used instead.
    }
  }

  /// Shows the customer's own blue dot, but only if location is already
  /// allowed: this screen never asks for the permission itself.
  Future<void> _checkMyLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      final allowed =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (allowed && mounted) setState(() => _showMyLocation = true);
    } catch (_) {}
  }

  void _onMoveTick() {
    final from = _moveFrom;
    final to = _moveTo;
    if (from == null || to == null || !mounted) return;
    final t = _moveController.value;
    setState(() {
      _shownDriver = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
    });
  }

  void _onDriverMoved(LatLng position) {
    if (!mounted || _finished) return;
    _driverPosition = position;
    final shown = _shownDriver;
    if (shown == null || _metersBetween(shown, position) > 1500) {
      // First fix, or a jump too big to be driving: don't slide across town.
      _moveController.stop();
      setState(() => _shownDriver = position);
    } else if (_metersBetween(shown, position) >= 2) {
      _moveFrom = shown;
      _moveTo = position;
      _moveController.forward(from: 0);
    }
    _refreshLiveRoute();
    _followDriver();
  }

  /// Keeps the driver and the next stop in view as the driver moves.
  void _followDriver() {
    final driver = _driverPosition;
    if (driver == null || _userMovedMap) return;
    final last = _lastFitAt;
    if (last != null && _metersBetween(last, driver) < 40) return;
    _fitMapBounds();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _markArrived() {
    if (_arrived || _pickedUp || !mounted) return;
    setState(() {
      _arrived = true;
      _liveRoute = const [];
      _liveDistanceKm = null;
      _liveEta = null;
    });
    _notify('Your driver has arrived at the pickup point.');
    if (!_userMovedMap) _fitMapBounds();
  }

  void _markPickedUp() {
    if (_pickedUp || !mounted) return;
    setState(() {
      _pickedUp = true;
      _arrived = true;
      _liveRoute = const [];
      _liveDistanceKm = null;
      _liveEta = null;
    });
    _notify('Your trip has started.');
    // The camera now frames the drive to the destination.
    _userMovedMap = false;
    _fitMapBounds();
    _refreshLiveRoute(force: true);
  }

  /// Reads the trip from the server: live driver position, whether the ride
  /// has started, and whether the other side ended or cancelled it.
  Future<void> _checkTrip() async {
    final tripId = _tripId;
    if (tripId == null || _finished || _ending) return;
    late final Map<String, dynamic> data;
    try {
      final response = await ApiService.getTripDetails(tripId);
      final body = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final nested = body['trip'];
      data = nested is Map ? Map<String, dynamic>.from(nested) : body;
    } catch (_) {
      return; // Offline: try again on the next tick.
    }
    if (!mounted || _finished || _ending) return;

    final status = data['status']?.toString();
    if (status == 'completed') {
      await _finishEndedElsewhere();
      return;
    }
    if (status == 'cancelled') {
      await _handleCancelled();
      return;
    }

    if (data['pickedUpAt'] != null) {
      _markPickedUp();
    } else if (data['arrivedAt'] != null) {
      _markArrived();
    }

    final driver = data['driver'];
    final location = driver is Map ? driver['location'] : null;
    if (location is Map) {
      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) _onDriverMoved(LatLng(lat, lng));
    }
  }

  void _openSummary(TripModel trip, ReceiptModel? receipt, {String? notice}) {
    _finished = true;
    _statusPoll?.cancel();
    context.read<TripProvider>().upsertTrip(trip);
    if (notice != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TripSummaryScreen(trip: trip, receipt: receipt),
      ),
    );
  }

  /// The driver ended the trip: fetch the final trip and receipt (ending an
  /// already-completed trip just returns them) and show the summary.
  Future<void> _finishEndedElsewhere() async {
    final tripId = _tripId;
    if (tripId == null || _finished) return;
    _finished = true;
    _statusPoll?.cancel();
    try {
      final (trip, receipt) = await _repository.endTrip(tripId);
      if (!mounted) return;
      _openSummary(trip, receipt, notice: 'The driver ended the trip.');
    } catch (_) {
      // Let the next status check try again.
      _finished = false;
      if (mounted) {
        _statusPoll = Timer.periodic(
          const Duration(seconds: 4),
          (_) => _checkTrip(),
        );
      }
    }
  }

  Future<void> _handleCancelled() async {
    if (_finished) return;
    _finished = true;
    _statusPoll?.cancel();
    final tripId = _tripId;
    final provider = context.read<TripProvider>();
    final navigator = Navigator.of(context);
    if (tripId != null) {
      try {
        provider.upsertTrip(await _repository.getTripDetails(tripId));
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Trip cancelled'),
        content: const Text('This trip was cancelled. No fare is charged.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) navigator.popUntil((route) => route.isFirst);
  }

  /// Redraws the road route from the driver to the next stop. Throttled so a
  /// moving driver doesn't trigger a request on every GPS update.
  Future<void> _refreshLiveRoute({bool force = false}) async {
    final driver = _driverPosition;
    if (driver == null || _loadingLiveRoute || _finished) return;
    // Waiting at the pickup point: nothing to route until the ride starts.
    if (_arrived && !_pickedUp) return;
    final target = _pickedUp ? _destination : _pickup;

    if (!force) {
      final origin = _liveRouteOrigin;
      final at = _liveRouteAt;
      final movedEnough =
          origin == null || _metersBetween(origin, driver) >= 120;
      final waitedEnough =
          at == null ||
          DateTime.now().difference(at) >= const Duration(seconds: 10);
      if (!movedEnough || !waitedEnough) return;
    }
    if (_metersBetween(driver, target) < 30) return; // Already there.

    _loadingLiveRoute = true;
    final forPickedUp = _pickedUp;
    try {
      final response = await ApiService.getDrivingRoute(
        pickupLatitude: driver.latitude,
        pickupLongitude: driver.longitude,
        destinationLatitude: target.latitude,
        destinationLongitude: target.longitude,
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final points = decodeGooglePolyline(
        data['encodedPolyline']?.toString() ?? '',
      );
      // The ride may have started while this was loading: drop a stale leg.
      if (!mounted || _finished || forPickedUp != _pickedUp) return;
      if (_arrived && !_pickedUp) return;
      final meters = data['distanceMeters'];
      setState(() {
        _liveRoute = points;
        _liveRouteOrigin = driver;
        _liveRouteAt = DateTime.now();
        _liveDistanceKm = meters is num ? meters / 1000 : null;
        _liveEta = _formatDuration(data['duration']);
      });
      if (!_userMovedMap) _fitMapBounds();
    } catch (_) {
      // Keep the previous line; the next movement tries again.
    } finally {
      _loadingLiveRoute = false;
    }
  }

  static String? _formatDuration(Object? value) {
    final seconds = int.tryParse(value?.toString().replaceFirst('s', '') ?? '');
    if (seconds == null) return null;
    final minutes = (seconds / 60).round();
    if (minutes < 1) return '< 1 min';
    return minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  LatLng? _resolveDriverInitial() {
    final loc = widget.driver['location'];
    if (loc is Map) {
      final lat = (loc['lat'] ?? loc['latitude']) as num?;
      final lng = (loc['lng'] ?? loc['longitude']) as num?;
      if (lat != null && lng != null) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
      final coords = loc['coordinates'];
      if (coords is List && coords.length >= 2) {
        return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
      }
    }
    return null;
  }

  void _initSocketAndTrip() {
    final tripId = widget.trip?.id ?? widget.requestId;
    CustomerSocketService.instance.listenToTrip(
      tripId: tripId,
      onLocation: (data) {
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) _onDriverMoved(LatLng(lat, lng));
      },
      onTripEnded: (data) {
        if (!mounted || _ending || _finished) return;
        final tripJson = data['trip'];
        final receiptJson = data['receipt'];
        if (tripJson is Map && receiptJson is Map) {
          _openSummary(
            TripModel.fromJson(Map<String, dynamic>.from(tripJson)),
            ReceiptModel.fromJson(Map<String, dynamic>.from(receiptJson)),
            notice: 'The driver ended the trip.',
          );
        } else {
          _finishEndedElsewhere();
        }
      },
      onTripEvent: (event, data) {
        if (!mounted || _finished || _ending) return;
        final id = data['tripId']?.toString();
        if (id != null && _tripId != null && id != _tripId) return;
        switch (event) {
          case 'driver_arrived':
            _markArrived();
          case 'trip_started':
            _markPickedUp();
          case 'trip_cancelled':
            _handleCancelled();
        }
      },
    );
  }

  Future<void> _loadRoadRoute() async {
    final pickup = _pickup;
    final dest = _destination;
    if (pickup.latitude == dest.latitude && pickup.longitude == dest.longitude) {
      return;
    }

    setState(() => _loadingRoute = true);
    try {
      final response = await ApiService.getDrivingRoute(
        pickupLatitude: pickup.latitude,
        pickupLongitude: pickup.longitude,
        destinationLatitude: dest.latitude,
        destinationLongitude: dest.longitude,
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final points = decodeGooglePolyline(data['encodedPolyline']?.toString() ?? '');
      if (points.isNotEmpty && mounted) {
        setState(() => _routePoints = points);
        _fitMapBounds();
      }
    } catch (_) {
      // Offline or network error: fallback to straight connection
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    final driver = _driverPosition;
    // Before pickup, frame the driver coming to the customer; afterwards,
    // the drive to the destination.
    final allPoints = <LatLng>[
      if (!_pickedUp || driver == null) _pickup,
      if (_pickedUp || driver == null) _destination,
      ?driver,
      ..._liveRoute,
    ];
    if (allPoints.isEmpty) return;
    _lastFitAt = driver;

    var minLat = allPoints.first.latitude;
    var maxLat = allPoints.first.latitude;
    var minLng = allPoints.first.longitude;
    var maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.002, minLng - 0.002),
          northeast: LatLng(maxLat + 0.002, maxLng + 0.002),
        ),
        60,
      ),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    _moveController.dispose();
    CustomerSocketService.instance.stopListeningTrip();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.trip?.driverName ??
        (widget.driver['name'] as String?) ??
        'Driver';
    final vehicleNumber = widget.trip?.vehicleNumber ??
        (widget.driver['vehicleNumber'] as String?) ??
        '-';
    final distanceKm = widget.trip?.distanceKm ?? widget.distanceKm;
    final ratePerKm = widget.trip?.ratePerKm ?? widget.ratePerKm;
    final totalFare = widget.trip?.totalFare ?? widget.totalFare;

    final markers = <Marker>{
      // Where the customer is waiting. Once on board, the customer travels
      // with the car, so this marker is dropped.
      if (!_pickedUp)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup,
          icon:
              _youIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: _youIcon == null
              ? const Offset(0.5, 1)
              : const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'You · Pickup point'),
          zIndexInt: 1,
        ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ),
    };

    final shownDriver = _shownDriver ?? _driverPosition;
    if (shownDriver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: shownDriver,
          icon:
              _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: _carIcon == null
              ? const Offset(0.5, 1)
              : const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: '$driverName ($vehicleNumber)'),
          zIndexInt: 2,
        ),
      );
    }

    final enRoute = !_arrived && !_pickedUp;

    final polylines = <Polyline>{
      // Before pickup: the planned trip, with the driver's approach on top.
      // After pickup: only what is left to drive.
      if (_routePoints.length > 1 && (!_pickedUp || _liveRoute.length < 2))
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          width: 5,
          color: enRoute
              ? const Color(0xFF2563EB).withValues(alpha: 0.45)
              : const Color(0xFF2563EB),
        ),
      if (_liveRoute.length > 1)
        Polyline(
          polylineId: const PolylineId('live'),
          points: _liveRoute,
          width: 6,
          color: _pickedUp ? const Color(0xFF2563EB) : const Color(0xFF22C55E),
          patterns: _pickedUp
              ? const <PatternItem>[]
              : [PatternItem.dash(18), PatternItem.gap(10)],
          zIndex: 1,
        ),
    };

    final liveParts = [
      if (_liveDistanceKm != null) '${_liveDistanceKm!.toStringAsFixed(1)} km',
      ?_liveEta,
    ];
    final driverNow = _driverPosition;
    final nearPickup =
        enRoute &&
        driverNow != null &&
        _metersBetween(driverNow, _pickup) <= 150;
    final String liveStatus;
    final String headline;
    final String detail;
    if (_pickedUp) {
      liveStatus = ['Heading to destination', ...liveParts].join(' · ');
      headline = 'On the way to your destination';
      detail = liveParts.isEmpty
          ? 'Your driver ends the trip when you arrive.'
          : '${liveParts.join(' · ')} left';
    } else if (_arrived) {
      liveStatus = 'Your driver has arrived';
      headline = 'Your driver has arrived';
      detail = 'Meet $driverName at the pickup point · $vehicleNumber';
    } else if (driverNow == null) {
      liveStatus = 'Waiting for the driver\'s location…';
      headline = 'Driver is on the way';
      detail = 'Waiting for the driver\'s location…';
    } else if (nearPickup) {
      liveStatus = 'Your driver is arriving now';
      headline = 'Your driver is arriving now';
      detail = 'Be ready at the pickup point · $vehicleNumber';
    } else {
      liveStatus = ['Driver is on the way', ...liveParts].join(' · ');
      headline = 'Driver is on the way';
      detail = liveParts.isEmpty
          ? 'Follow the car on the map.'
          : 'Arriving in ${liveParts.reversed.join(' · ')}';
    }
    final step = _pickedUp ? 2 : (_arrived ? 1 : 0);
    final sheetHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pickedUp
              ? 'Trip In Progress'
              : _arrived
              ? 'Driver Has Arrived'
              : 'Driver On The Way',
        ),
        actions: [
          IconButton(
            tooltip: 'Fit route',
            icon: const Icon(Icons.crop_free_rounded),
            onPressed: () {
              _userMovedMap = false;
              _fitMapBounds();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Google Map. Once the customer pans it, stop re-framing the
          // route under their finger until they tap "Fit route".
          Listener(
            onPointerDown: (_) => _userMovedMap = true,
            child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverPosition ?? _pickup,
              zoom: 13,
            ),
            markers: markers,
            polylines: polylines,
            // Keeps the route clear of the status pill and the bottom sheet.
            padding: EdgeInsets.only(top: 56, bottom: sheetHeight),
            myLocationEnabled: _showMyLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapBounds();
            },
            ),
          ),

          // Where the driver is heading, how far and how long
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _pickedUp
                          ? Icons.navigation_rounded
                          : _arrived
                          ? Icons.where_to_vote_rounded
                          : Icons.local_taxi_rounded,
                      color: _pickedUp
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF22C55E),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        liveStatus,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_loadingRoute && _liveRoute.isEmpty)
            Positioned(
              top: 56,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Calculating fastest road route...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Trip Info Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // On the way -> Arrived -> On trip
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= step
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      headline,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      detail,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF2563EB), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              vehicleNumber,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                            SizedBox(width: 6),
                            Text(
                              'Live',
                              style: TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricCol('Distance', '${distanceKm.toStringAsFixed(1)} km'),
                        _metricCol('Rate', 'Rs. ${ratePerKm.toStringAsFixed(0)} / km'),
                        _metricCol('Fare', 'Rs. ${totalFare.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: AppTheme.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      // Before the ride starts there is nothing to charge
                      // for, so the customer cancels rather than ends.
                      onPressed: _ending
                          ? null
                          : () => _pickedUp
                                ? _confirmEndTrip(context)
                                : _confirmCancelRide(context),
                      child: _ending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _pickedUp ? 'End Trip' : 'Cancel Ride',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }

  void _confirmEndTrip(BuildContext context) {
    if (widget.trip == null || widget.trip!.id.isEmpty) {
      setState(() => _error = 'Trip details are not available yet. Please try again.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip?'),
        content: const Text(
          'Are you sure you want to end the trip? The final receipt will be generated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shadowColor: Colors.transparent,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _endTrip();
            },
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelRide(BuildContext context) {
    if (_tripId == null) {
      setState(() => _error = 'Trip details are not available yet. Please try again.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text(
          'Your driver is already on the way. Do you want to cancel this ride?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shadowColor: Colors.transparent,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _cancelRide();
            },
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide() async {
    final tripId = _tripId;
    if (tripId == null || _finished) return;
    final provider = context.read<TripProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _ending = true;
      _error = null;
    });

    try {
      final trip = await _repository.cancelTrip(tripId);
      _finished = true;
      _statusPoll?.cancel();
      provider.upsertTrip(trip);
      messenger.showSnackBar(
        const SnackBar(content: Text('Ride cancelled.')),
      );
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ending = false;
        _error = 'Failed to cancel the ride. Please try again.';
      });
    }
  }

  Future<void> _endTrip() async {
    setState(() {
      _ending = true;
      _error = null;
    });

    try {
      final (trip, receipt) = await _repository.endTrip(widget.trip!.id);
      if (!mounted || _finished) return;
      _openSummary(trip, receipt);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to end trip. Please try again.');
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }
}
