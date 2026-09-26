import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
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
            _scheduleRouteRefresh();
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
      setState(
        () => _driverPosition = LatLng(position.latitude, position.longitude),
      );
      await _loadRoadRoute();
      _fitMapToRoute();
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
      _fitMapToRoute();
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

  void _recenterMap() {
    if (_roadRoute.length > 1) {
      _fitMapToRoute();
      return;
    }
    final controller = _mapController;
    if (controller == null) return;
    controller.animateCamera(
      google_maps.CameraUpdate.newLatLngZoom(
        google_maps.LatLng(_target.latitude, _target.longitude),
        15,
      ),
    );
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
          google_maps.GoogleMap(
            initialCameraPosition: google_maps.CameraPosition(
              target: google_maps.LatLng(_target.latitude, _target.longitude),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _fitMapToRoute(),
              );
            },
            myLocationEnabled: _driverPosition != null,
            myLocationButtonEnabled: true,
            markers: markers,
            polylines: polylines,
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter-navigation-map',
                    onPressed: _recenterMap,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
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
