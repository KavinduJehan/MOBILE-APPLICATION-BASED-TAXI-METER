import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
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

  LatLng get _pickup => LatLng(widget.request.pickupLatitude, widget.request.pickupLongitude);
  LatLng get _destination => LatLng(widget.request.destinationLatitude, widget.request.destinationLongitude);
  LatLng get _target => _headingToPickup ? _pickup : _destination;
  String get _targetAddress => _headingToPickup ? widget.request.pickupAddress : widget.request.destinationAddress;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
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
      // OSRM returns a route constrained to roads for the driving profile.
      final response = await Dio().get<dynamic>(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${_target.longitude},${_target.latitude}',
        queryParameters: const {
          'overview': 'full',
          'geometries': 'geojson',
          'alternatives': 'false',
        },
      );
      final data = response.data;
      final routes = data is Map ? data['routes'] : null;
      final route = routes is List && routes.isNotEmpty ? routes.first : null;
      final geometry = route is Map ? route['geometry'] : null;
      final coordinates = geometry is Map ? geometry['coordinates'] : null;
      final points = coordinates is List
          ? coordinates
              .whereType<List>()
              .where((point) => point.length >= 2 && point[0] is num && point[1] is num)
              .map((point) => LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()))
              .toList()
          : const <LatLng>[];
      if (!mounted) return;
      setState(() => _roadRoute = points);
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
    final distance = _driverPosition == null ? null : Geolocator.distanceBetween(
      _driverPosition!.latitude, _driverPosition!.longitude, _target.latitude, _target.longitude,
    );
    return Scaffold(
      appBar: AppBar(title: Text(_headingToPickup ? 'Navigate to pickup' : 'Navigate to destination')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: _target, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ridex.driver',
              ),
              if (routePoints.length > 1)
                PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5, color: const Color(0xFF69A8FF))]),
              MarkerLayer(markers: [
                Marker(point: _target, width: 48, height: 48, child: Icon(_headingToPickup ? Icons.person_pin_circle_rounded : Icons.location_on_rounded, color: Colors.redAccent, size: 44)),
                if (_driverPosition != null) Marker(point: _driverPosition!, width: 48, height: 48, child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF69A8FF), size: 40)),
              ]),
            ],
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
                  if (distance != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${(distance / 1000).toStringAsFixed(1)} km away', style: const TextStyle(color: Color(0xFF69A8FF)))),
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
