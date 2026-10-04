import 'dart:async';
import 'package:flutter/material.dart';
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

class _TripProgressScreenState extends State<TripProgressScreen> {
  final _repository = const TripRepository();
  GoogleMapController? _mapController;
  BitmapDescriptor _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  LatLng? _driverPosition;
  List<LatLng> _routePoints = const [];
  bool _loadingRoute = false;
  bool _ending = false;
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
    _loadDriverMarkerIcon();
    _initSocketAndTrip();
    _loadRoadRoute();
  }

  Future<void> _loadDriverMarkerIcon() async {
    final icon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'icons/tuktuk.png',
    );
    if (mounted) setState(() => _driverMarkerIcon = icon);
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
        if (lat != null && lng != null && mounted) {
          setState(() => _driverPosition = LatLng(lat, lng));
        }
      },
      onTripEnded: (data) {
        if (!mounted || _ending) return;
        final tripJson = data['trip'] as Map<String, dynamic>?;
        final receiptJson = data['receipt'] as Map<String, dynamic>?;
        if (tripJson != null && receiptJson != null) {
          final trip = TripModel.fromJson(tripJson);
          final receipt = ReceiptModel.fromJson(receiptJson);
          context.read<TripProvider>().upsertTrip(trip);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TripSummaryScreen(trip: trip, receipt: receipt),
            ),
          );
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
    final allPoints = <LatLng>[_pickup, _destination];
    if (_driverPosition != null) allPoints.add(_driverPosition!);
    if (allPoints.isEmpty) return;

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
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        50,
      ),
    );
  }

  @override
  void dispose() {
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
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ),
    };

    if (_driverPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPosition!,
          icon: _driverMarkerIcon,
          infoWindow: InfoWindow(title: '$driverName ($vehicleNumber)'),
          zIndexInt: 2,
        ),
      );
    }

    final polylines = <Polyline>{};
    if (_routePoints.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          width: 5,
          color: const Color(0xFF2563EB),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip In Progress'),
        actions: [
          IconButton(
            tooltip: 'Fit route',
            icon: const Icon(Icons.crop_free_rounded),
            onPressed: _fitMapBounds,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverPosition ?? _pickup,
              zoom: 13,
            ),
            markers: markers,
            polylines: polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapBounds();
            },
          ),

          if (_loadingRoute)
            Positioned(
              top: 12,
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
                      onPressed: _ending ? null : () => _confirmEndTrip(context),
                      child: _ending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'End Trip',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
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

  Future<void> _endTrip() async {
    setState(() {
      _ending = true;
      _error = null;
    });

    try {
      final (trip, receipt) = await _repository.endTrip(widget.trip!.id);
      if (!mounted) return;
      context.read<TripProvider>().upsertTrip(trip);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TripSummaryScreen(trip: trip, receipt: receipt),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to end trip. Please try again.');
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }
}
