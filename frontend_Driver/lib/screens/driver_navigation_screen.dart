import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/google_polyline.dart';
import '../widgets/app_widgets.dart';
import 'active_trip_screen.dart';

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
  LatLng? _driverPosition;
  List<LatLng> _roadRoute = const [];
  bool _headingToPickup = true;
  bool _loadingRoute = false;
  String? _locationError;
  double? _routeDistanceMeters;
  final ApiService _api = ApiService();

  LatLng get _pickup => LatLng(widget.request.pickupLatitude, widget.request.pickupLongitude);
  LatLng get _destination => LatLng(widget.request.destinationLatitude, widget.request.destinationLongitude);
  LatLng get _target => _headingToPickup ? _pickup : _destination;
  String get _targetAddress => _headingToPickup ? widget.request.pickupAddress : widget.request.destinationAddress;

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
      setState(() => _locationError = 'Turn on location services to see your live position.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _locationError = 'Location permission is required for navigation.');
      return;
    }
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((position) {
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

      if (_roadRoute.isEmpty && !_loadingRoute) {
        _loadRoadRoute();
      }
    }, onError: (_) {
      if (mounted) setState(() => _locationError = 'Unable to update your location.');
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRoadRoute() async {
    final start = _driverPosition;
    if (start == null || _loadingRoute) return;
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
        final distanceMeters = data['distanceMeters'];
        _routeDistanceMeters = distanceMeters is num ? distanceMeters.toDouble() : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _locationError = 'Road route could not be loaded. Check your internet connection.');
      }
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _roadRoute;
    final distance = _routeDistanceMeters;
    final targetMarker = google_maps.Marker(
      markerId: const google_maps.MarkerId('target'),
      position: google_maps.LatLng(_target.latitude, _target.longitude),
      icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed),
    );
    final markers = <google_maps.Marker>{targetMarker};
    if (_driverPosition != null) {
      markers.add(
        google_maps.Marker(
          markerId: const google_maps.MarkerId('driver'),
          position: google_maps.LatLng(_driverPosition!.latitude, _driverPosition!.longitude),
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueAzure),
        ),
      );
    }
    final polylines = routePoints.length > 1
        ? {
            google_maps.Polyline(
              polylineId: const google_maps.PolylineId('google-route'),
              points: routePoints
                  .map((point) => google_maps.LatLng(point.latitude, point.longitude))
                  .toList(),
              width: 5,
              color: const Color(0xFF69A8FF),
            ),
          }
        : <google_maps.Polyline>{};
    return Scaffold(
      appBar: AppBar(title: Text(_headingToPickup ? 'Navigate to pickup' : 'Navigate to destination')),
      body: Stack(
        children: [
          google_maps.GoogleMap(
            initialCameraPosition: google_maps.CameraPosition(
              target: google_maps.LatLng(_target.latitude, _target.longitude),
              zoom: 14,
            ),
            myLocationEnabled: _driverPosition != null,
            myLocationButtonEnabled: true,
            markers: markers,
            polylines: polylines,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: const Color(0xFF0E1422), borderRadius: BorderRadius.circular(24)),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_headingToPickup ? 'Pick up ${widget.request.customerName}' : 'Take passenger to destination', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_targetAddress.isEmpty ? 'Location coordinates supplied' : _targetAddress, style: const TextStyle(color: Colors.white70)),
                  if (distance != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${(distance / 1000).toStringAsFixed(1)} km by road', style: const TextStyle(color: Color(0xFF69A8FF)))),
                  if (_loadingRoute) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Finding the best road route...', style: TextStyle(color: Colors.white70))),
                  if (_locationError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_locationError!, style: const TextStyle(color: Colors.orangeAccent))),
                  const SizedBox(height: 14),
                  PrimaryActionButton(
                    label: _headingToPickup ? 'Passenger picked up' : 'Start active trip',
                    onPressed: () {
                      if (_headingToPickup) {
                        setState(() {
                          _headingToPickup = false;
                          _roadRoute = const [];
                          _routeDistanceMeters = null;
                        });
                        _loadRoadRoute();
                      } else {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ActiveTripScreen(trip: widget.trip, receiptNumber: widget.receiptNumber)));
                      }
                    },
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
