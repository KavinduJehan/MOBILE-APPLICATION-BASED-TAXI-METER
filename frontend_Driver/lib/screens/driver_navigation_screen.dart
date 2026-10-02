import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/google_polyline.dart';
import '../widgets/app_widgets.dart';
import 'trip_summary_screen.dart';

enum _NavigationState { headingToPickup, atPickup, inProgress }

class DriverNavigationScreen extends StatefulWidget {
  const DriverNavigationScreen({
    super.key,
    required this.trip,
    required this.request,
    this.receiptNumber,
  });

  final TripRecord trip;
  final RideRequest request;
  final String? receiptNumber;

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _routeRefreshTimer;
  LatLng? _driverPosition;
  List<LatLng> _roadRoute = const [];
  _NavigationState _navigationState = _NavigationState.headingToPickup;
  bool _loadingRoute = false;
  bool _actionBusy = false;
  String? _locationError;
  double? _routeDistanceMeters;
  String? _routeDuration;
  LatLng? _lastRouteOrigin;
  google_maps.GoogleMapController? _mapController;
  final ApiService _api = ApiService();

  // ── Navigation camera state ────────────────────────────────────────────────
  static const _distance = Distance();
  static const double _navigationTilt = 50;
  static const Duration _cameraAnimation = Duration(milliseconds: 900);
  static const Duration _minCameraInterval = Duration(milliseconds: 750);

  /// True while the camera follows the driver; false after the driver pans
  /// the map manually, until they tap re-center.
  bool _followDriver = true;
  double _cameraBearing = 0;
  double _speedMps = 0;
  LatLng? _lastBearingOrigin;
  DateTime? _lastCameraUpdate;
  Timer? _cameraThrottle;
  double _mapHeight = 0;
  double _panelHeight = 240;
  final GlobalKey _panelKey = GlobalKey();

  // Cached position along the current road route, so the nearest-point search
  // only scans a small window each GPS update.
  List<LatLng>? _indexedRoute;
  int _routeIndex = 0;

  LatLng get _pickup =>
      LatLng(widget.request.pickupLatitude, widget.request.pickupLongitude);
  LatLng get _destination => LatLng(
    widget.request.destinationLatitude,
    widget.request.destinationLongitude,
  );
  bool get _headingToPickup =>
      _navigationState == _NavigationState.headingToPickup;
  bool get _tripInProgress => _navigationState == _NavigationState.inProgress;
  LatLng get _target => _headingToPickup ? _pickup : _destination;
  String get _targetAddress => _headingToPickup
      ? widget.request.pickupAddress
      : widget.request.destinationAddress;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  DateTime? _lastSyncTime;
  void _syncLocationThrottle(double lat, double lng) {
    final now = DateTime.now();
    if (_lastSyncTime == null || now.difference(_lastSyncTime!).inSeconds >= 10) {
      _lastSyncTime = now;
      _api.updateLocation(lat: lat, lng: lng).catchError((_) {});
    }
  }

  Future<void> _startLocationTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(
        () => _locationError =
            'Turn on location services to see your live position.',
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(
        () =>
            _locationError = 'Location permission is required for navigation.',
      );
      return;
    }
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (position) {
            if (!mounted) return;
            setState(
              () => _driverPosition = LatLng(
                position.latitude,
                position.longitude,
              ),
            );
            DriverSocketService.instance.emitLocationUpdate(
              lat: position.latitude,
              lng: position.longitude,
              tripId: widget.trip.id,
              customerId: widget.request.customerId,
            );
            _syncLocationThrottle(position.latitude, position.longitude);
            _scheduleRouteRefresh();
            _onDriverMoved(position);
          },
          onError: (_) {
            if (mounted) {
              setState(
                () => _locationError = 'Unable to update your location.',
              );
            }
          },
        );
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() => _driverPosition = LatLng(position.latitude, position.longitude));

      // Broadcast live coordinates to customer and backend
      DriverSocketService.instance.emitLocationUpdate(
        lat: position.latitude,
        lng: position.longitude,
        tripId: widget.trip.id,
        customerId: widget.request.customerId,
      );
      _syncLocationThrottle(position.latitude, position.longitude);
      _onDriverMoved(position);

      if (_roadRoute.isEmpty && !_loadingRoute) {
        _loadRoadRoute();
      }
    } catch (_) {
      if (mounted && _driverPosition == null) {
        setState(() => _locationError = 'Unable to get your current location.');
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _routeRefreshTimer?.cancel();
    _cameraThrottle?.cancel();
    super.dispose();
  }

  void _scheduleRouteRefresh() {
    if (_navigationState == _NavigationState.atPickup ||
        _driverPosition == null ||
        _loadingRoute) {
      return;
    }
    final lastOrigin = _lastRouteOrigin;
    if (lastOrigin != null &&
        const Distance().as(LengthUnit.Meter, lastOrigin, _driverPosition!) <
            75) {
      return;
    }
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer(const Duration(seconds: 8), () {
      _routeRefreshTimer = null;
      _loadRoadRoute();
    });
  }

  Future<void> _loadRoadRoute() async {
    final start = _driverPosition;
    if (start == null ||
        _loadingRoute ||
        _navigationState == _NavigationState.atPickup) {
      return;
    }
    setState(() {
      _loadingRoute = true;
      _locationError = null;
    });
    try {
      final data = await _api.getDrivingRoute(
        pickupLatitude: start.latitude,
        pickupLongitude: start.longitude,
        destinationLatitude: _target.latitude,
        destinationLongitude: _target.longitude,
      );
      final encodedPolyline = data['encodedPolyline']?.toString() ?? '';
      final points = decodeGooglePolyline(encodedPolyline);
      if (!mounted) return;
      setState(() {
        _roadRoute = points;
        _lastRouteOrigin = start;
        final distanceMeters = data['distanceMeters'];
        _routeDistanceMeters = distanceMeters is num
            ? distanceMeters.toDouble()
            : null;
        _routeDuration = _formatDuration(data['duration']);
      });
      _updateNavigationCamera();
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError =
              'Road route could not be loaded. Check your internet connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  String? _formatDuration(Object? value) {
    final raw = value?.toString().replaceFirst('s', '');
    final seconds = int.tryParse(raw ?? '');
    if (seconds == null) return null;
    if (seconds < 60) return '$seconds min';
    final minutes = (seconds / 60).round();
    return minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  void _fitMapToRoute() {
    final controller = _mapController;
    if (controller == null) return;
    final points = <LatLng>[
      ...?_driverPosition == null ? null : <LatLng>[_driverPosition!],
      _target,
      ..._roadRoute,
    ];
    if (points.length < 2) return;
    final latitudes = points.map((point) => point.latitude).toList();
    final longitudes = points.map((point) => point.longitude).toList();
    controller.animateCamera(
      google_maps.CameraUpdate.newLatLngBounds(
        google_maps.LatLngBounds(
          southwest: google_maps.LatLng(
            latitudes.reduce((a, b) => a < b ? a : b),
            longitudes.reduce((a, b) => a < b ? a : b),
          ),
          northeast: google_maps.LatLng(
            latitudes.reduce((a, b) => a > b ? a : b),
            longitudes.reduce((a, b) => a > b ? a : b),
          ),
        ),
        72,
      ),
    );
  }

  /// Re-enters follow mode and snaps the camera back onto the driver.
  void _recenterMap() {
    if (!_followDriver) setState(() => _followDriver = true);
    _lastCameraUpdate = null;
    if (_driverPosition != null) {
      _updateNavigationCamera();
      return;
    }
    _mapController?.animateCamera(
      google_maps.CameraUpdate.newLatLngZoom(
        google_maps.LatLng(_target.latitude, _target.longitude),
        16,
      ),
    );
  }

  /// Manual whole-route view; pauses follow mode until re-center is tapped.
  void _showRouteOverview() {
    setState(() => _followDriver = false);
    _fitMapToRoute();
  }

  void _pauseFollow() {
    if (!_followDriver) return;
    _cameraThrottle?.cancel();
    setState(() => _followDriver = false);
  }

  void _onDriverMoved(Position position) {
    final driver = _driverPosition;
    if (driver == null) return;
    _speedMps = position.speed.isFinite && position.speed > 0
        ? position.speed
        : 0;
    final bearing = _resolveBearing(position, driver);
    if (bearing != null) {
      _cameraBearing = _smoothBearing(_cameraBearing, bearing);
    }
    _updateNavigationCamera();
  }

  /// GPS heading when moving fast enough for it to be trustworthy, otherwise
  /// the direction of the road route just ahead, otherwise recent movement.
  double? _resolveBearing(Position position, LatLng driver) {
    final headingAccuracy = position.headingAccuracy;
    final gpsHeadingReliable = position.speed >= 2.5 &&
        position.heading >= 0 &&
        (headingAccuracy <= 0 || headingAccuracy <= 35);
    if (gpsHeadingReliable) return position.heading;

    final routeBearing = _routeBearingAhead(driver);
    if (routeBearing != null) return routeBearing;

    final origin = _lastBearingOrigin;
    if (origin == null) {
      _lastBearingOrigin = driver;
      return null;
    }
    if (_distance.as(LengthUnit.Meter, origin, driver) < 10) return null;
    _lastBearingOrigin = driver;
    return _normalizeBearing(_distance.bearing(origin, driver));
  }

  double _smoothBearing(double current, double next) {
    final delta = _bearingDelta(current, next);
    // Ignore GPS jitter, follow real turns quickly.
    if (delta.abs() < 4) return current;
    final factor = delta.abs() > 60 ? 0.8 : 0.5;
    return _normalizeBearing(current + delta * factor);
  }

  static double _normalizeBearing(double bearing) => (bearing % 360 + 360) % 360;

  /// Signed shortest rotation from [from] to [to], in -180..180.
  static double _bearingDelta(double from, double to) =>
      ((to - from + 540) % 360) - 180;

  int? _nearestRouteIndex(LatLng point) {
    final route = _roadRoute;
    if (route.length < 2) return null;
    if (!identical(route, _indexedRoute)) {
      _indexedRoute = route;
      _routeIndex = 0;
    }

    int scan(int from, int to) {
      var bestIndex = from;
      var bestDistance = double.infinity;
      for (var i = from; i < to; i++) {
        final d = _distance.as(LengthUnit.Meter, point, route[i]);
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      }
      return bestIndex;
    }

    final from = math.max(0, _routeIndex - 10);
    final to = math.min(route.length, _routeIndex + 300);
    var index = scan(from, to);
    if (_distance.as(LengthUnit.Meter, point, route[index]) > 60) {
      index = scan(0, route.length);
    }
    _routeIndex = index;
    return index;
  }

  /// Walks [meters] forward along the route from [fromIndex].
  ({LatLng point, int index}) _pointAlongRoute(int fromIndex, double meters) {
    final route = _roadRoute;
    var remaining = meters;
    for (var i = fromIndex; i < route.length - 1; i++) {
      final segment = _distance.as(LengthUnit.Meter, route[i], route[i + 1]);
      if (segment >= remaining && segment > 0) {
        final bearing = _distance.bearing(route[i], route[i + 1]);
        return (point: _distance.offset(route[i], remaining, bearing), index: i);
      }
      remaining -= segment;
    }
    return (point: route.last, index: route.length - 1);
  }

  double? _routeBearingAhead(LatLng driver) {
    final index = _nearestRouteIndex(driver);
    if (index == null) return null;
    final ahead = _pointAlongRoute(index, 35).point;
    if (_distance.as(LengthUnit.Meter, driver, ahead) < 5) return null;
    return _normalizeBearing(_distance.bearing(driver, ahead));
  }

  /// The next point within [lookAheadMeters] where the route bends by 35°+,
  /// with the distance to it and the road bearing after the bend.
  ({LatLng point, double distance, double bearingAfter})? _upcomingTurn(
    LatLng driver, {
    double lookAheadMeters = 220,
  }) {
    final index = _nearestRouteIndex(driver);
    if (index == null) return null;
    final route = _roadRoute;
    final roadAhead = _pointAlongRoute(index, 20).point;
    if (_distance.as(LengthUnit.Meter, route[index], roadAhead) < 2) {
      return null;
    }
    final baseBearing = _distance.bearing(route[index], roadAhead);
    var travelled = _distance.as(LengthUnit.Meter, driver, route[index]);
    for (var i = index; i < route.length - 1; i++) {
      final segment = _distance.as(LengthUnit.Meter, route[i], route[i + 1]);
      if (travelled > lookAheadMeters) return null;
      if (segment >= 3) {
        final bearing = _distance.bearing(route[i], route[i + 1]);
        if (_bearingDelta(baseBearing, bearing).abs() >= 35) {
          return (
            point: route[i],
            distance: travelled,
            bearingAfter: _normalizeBearing(bearing),
          );
        }
      }
      travelled += segment;
    }
    return null;
  }

  double _zoomForSpeed() {
    final kmh = _speedMps * 3.6;
    if (kmh > 60) return 16.4;
    if (kmh > 30) return 16.9;
    return 17.5;
  }

  /// How far ahead of the driver to aim the camera so the driver sits in the
  /// lower part of the visible map, leaving the road ahead on screen.
  double _lookAheadMeters(LatLng driver, double zoom) {
    final visibleHeight = math.max(200.0, _mapHeight - _panelHeight);
    final metersPerDp = 156543.03392 *
        math.cos(driver.latitude * math.pi / 180) /
        math.pow(2, zoom);
    // Driver ~25% of the visible height below centre; tilt stretches ground
    // distance on screen, hence the extra factor.
    return visibleHeight * 0.25 * metersPerDp * 1.3;
  }

  void _updateNavigationCamera() {
    final controller = _mapController;
    final driver = _driverPosition;
    if (controller == null || driver == null || !_followDriver) return;

    // Throttle so overlapping animations don't make the camera stutter; the
    // trailing call keeps the final position up to date.
    final now = DateTime.now();
    final last = _lastCameraUpdate;
    if (last != null && now.difference(last) < _minCameraInterval) {
      _cameraThrottle ??= Timer(_minCameraInterval - now.difference(last), () {
        _cameraThrottle = null;
        _updateNavigationCamera();
      });
      return;
    }
    _cameraThrottle?.cancel();
    _cameraThrottle = null;
    _lastCameraUpdate = now;

    var zoom = _zoomForSpeed();
    var bearing = _cameraBearing;
    var lookAhead = _lookAheadMeters(driver, zoom);

    if (_navigationState != _NavigationState.atPickup) {
      final turn = _upcomingTurn(driver);
      if (turn != null && turn.distance <= 160) {
        // Close in on the junction and rotate slightly into the new road so
        // the turn and the street after it are both in view.
        final closeness = 1 - (turn.distance / 160);
        zoom = math.max(zoom, 17.2);
        lookAhead = math.min(lookAhead, math.max(turn.distance, 25.0));
        bearing = _normalizeBearing(
          bearing + _bearingDelta(bearing, turn.bearingAfter) * 0.25 * closeness,
        );
      }
    }

    final target = _distance.offset(driver, lookAhead, bearing);
    controller.animateCamera(
      google_maps.CameraUpdate.newCameraPosition(
        google_maps.CameraPosition(
          target: google_maps.LatLng(target.latitude, target.longitude),
          zoom: zoom,
          bearing: bearing,
          tilt: _navigationTilt,
        ),
      ),
      duration: _cameraAnimation,
    );
  }

  void _measurePanel() {
    final height = _panelKey.currentContext?.size?.height;
    if (height == null) return;
    // Panel height + its 16dp margin.
    final total = height + 16;
    if ((total - _panelHeight).abs() > 1) {
      setState(() => _panelHeight = total);
    }
  }

  void _markAtPickup() {
    if (_actionBusy) return;
    setState(() {
      _navigationState = _NavigationState.atPickup;
      _roadRoute = const [];
      _routeDistanceMeters = null;
      _routeDuration = null;
      _locationError = null;
    });
    _recenterMap();
  }

  Future<void> _startTrip() async {
    if (_actionBusy || _navigationState != _NavigationState.atPickup) return;
    setState(() {
      _actionBusy = true;
      _locationError = null;
    });
    try {
      await _api.startTrip(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _navigationState = _NavigationState.inProgress;
        _actionBusy = false;
      });
      await _loadRoadRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _locationError = 'Unable to start the trip. Please try again.';
      });
    }
  }

  Future<void> _endTrip() async {
    if (_actionBusy || !_tripInProgress) return;
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    setState(() {
      _actionBusy = true;
      _locationError = null;
    });
    try {
      final result = await _api.endTrip(widget.trip.id);
      if (!mounted) return;
      auth.stopLocationUpdates();
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => TripSummaryScreen(
            trip: result.trip,
            receiptNumber: result.receiptNumber ?? widget.receiptNumber,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _locationError = 'Unable to end the trip. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measurePanel();
    });
    final routePoints = _roadRoute;
    final distance = _routeDistanceMeters;
    final targetMarker = google_maps.Marker(
      markerId: const google_maps.MarkerId('target'),
      position: google_maps.LatLng(_target.latitude, _target.longitude),
      icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
        google_maps.BitmapDescriptor.hueRed,
      ),
    );
    final markers = <google_maps.Marker>{targetMarker};
    if (_driverPosition != null) {
      markers.add(
        google_maps.Marker(
          markerId: const google_maps.MarkerId('driver'),
          position: google_maps.LatLng(
            _driverPosition!.latitude,
            _driverPosition!.longitude,
          ),
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
            google_maps.BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    final polylines = routePoints.length > 1
        ? {
            google_maps.Polyline(
              polylineId: const google_maps.PolylineId('google-route'),
              points: routePoints
                  .map(
                    (point) =>
                        google_maps.LatLng(point.latitude, point.longitude),
                  )
                  .toList(),
              width: 5,
              color: const Color(0xFF69A8FF),
            ),
          }
        : <google_maps.Polyline>{};
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _headingToPickup ? 'Navigate to pickup' : 'Navigate to destination',
        ),
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              _mapHeight = constraints.maxHeight;
              final start = _driverPosition ?? _target;
              // Any touch on the map hands the camera to the driver until
              // they tap re-center.
              return Listener(
                onPointerDown: (_) => _pauseFollow(),
                child: google_maps.GoogleMap(
                  initialCameraPosition: google_maps.CameraPosition(
                    target: google_maps.LatLng(start.latitude, start.longitude),
                    zoom: _driverPosition != null ? 17.5 : 15,
                    tilt: _driverPosition != null ? _navigationTilt : 0,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _measurePanel();
                      _lastCameraUpdate = null;
                      _updateNavigationCamera();
                    });
                  },
                  padding: EdgeInsets.only(bottom: _panelHeight),
                  myLocationEnabled: _driverPosition != null,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  buildingsEnabled: true,
                  markers: markers,
                  polylines: polylines,
                ),
              );
            },
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'recenter-navigation-map',
                        tooltip: 'Follow my location',
                        onPressed: _recenterMap,
                        backgroundColor: _followDriver
                            ? const Color(0xFF2F6BFF)
                            : null,
                        foregroundColor: _followDriver ? Colors.white : null,
                        child: const Icon(Icons.navigation_rounded),
                      ),
                      if (_roadRoute.length > 1) ...[
                        const SizedBox(height: 10),
                        FloatingActionButton.small(
                          heroTag: 'overview-navigation-map',
                          tooltip: 'Show whole route',
                          onPressed: _showRouteOverview,
                          child: const Icon(Icons.alt_route_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_followDriver)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _panelHeight + 12,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _recenterMap,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2F6BFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: const StadiumBorder(),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text(
                          'Re-center',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    key: _panelKey,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1422),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _navigationState == _NavigationState.headingToPickup
                              ? 'Heading to pickup'
                              : _navigationState == _NavigationState.atPickup
                              ? 'At pickup'
                              : 'Trip in progress',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _targetAddress.isEmpty
                              ? 'Location coordinates supplied'
                              : _targetAddress,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (distance != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${(distance / 1000).toStringAsFixed(1)} km by road',
                              style: const TextStyle(color: Color(0xFF69A8FF)),
                            ),
                          ),
                        if (_routeDuration != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'ETA $_routeDuration',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        if (_loadingRoute)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Finding the best road route...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        if (_locationError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _locationError!,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        PrimaryActionButton(
                          label:
                              _navigationState ==
                                  _NavigationState.headingToPickup
                              ? 'I have arrived'
                              : _navigationState == _NavigationState.atPickup
                              ? 'Start Trip'
                              : 'End Trip',
                          isBusy: _actionBusy,
                          onPressed:
                              _navigationState ==
                                  _NavigationState.headingToPickup
                              ? _markAtPickup
                              : _navigationState == _NavigationState.atPickup
                              ? _startTrip
                              : _endTrip,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
