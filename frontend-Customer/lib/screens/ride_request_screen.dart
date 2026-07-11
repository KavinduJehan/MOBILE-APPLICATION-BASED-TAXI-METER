import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'waiting_for_driver_screen.dart';

// ── Sri Lankan city coordinates (lat, lng) ───────────────────────────────────
const _cities = <String, (double, double)>{
  'Colombo': (6.9271, 79.8612),
  'Galle': (6.0535, 80.2210),
  'Kandy': (7.2906, 80.6337),
  'Matara': (5.9549, 80.5550),
  'Negombo': (7.2096, 79.8378),
  'Jaffna': (9.6615, 80.0255),
  'Trinco': (8.5874, 81.2152),
  'Badulla': (6.9934, 81.0550),
  'Ratnapura': (6.7056, 80.3847),
  'Kurunegala': (7.4867, 80.3647),
};

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

class RideRequestScreen extends StatefulWidget {
  final Map<String, dynamic> driver;
  final double? suggestedRatePerKm;
  final String? initialPickup;
  final double? initialPickupLat;
  final double? initialPickupLng;
  final String? initialDestination;
  final double? initialDestinationLat;
  final double? initialDestinationLng;

  const RideRequestScreen({
    super.key,
    required this.driver,
    this.suggestedRatePerKm,
    this.initialPickup,
    this.initialPickupLat,
    this.initialPickupLng,
    this.initialDestination,
    this.initialDestinationLat,
    this.initialDestinationLng,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  String _pickup = 'Colombo';
  String _dest = 'Galle';
  bool _loading = false;
  String? _error;

  bool get _hasMapSelection =>
      widget.initialPickupLat != null &&
      widget.initialPickupLng != null &&
      widget.initialDestinationLat != null &&
      widget.initialDestinationLng != null;

  @override
  void initState() {
    super.initState();
    final initialPickup = widget.initialPickup?.trim().toLowerCase();
    if (initialPickup != null && initialPickup.isNotEmpty) {
      final matchedPickup = _cities.keys.where(
        (city) => city.toLowerCase() == initialPickup,
      );
      if (matchedPickup.isNotEmpty) {
        _pickup = matchedPickup.first;
      }
    }

    final initialDestination = widget.initialDestination?.trim().toLowerCase();
    if (initialDestination == null || initialDestination.isEmpty) return;

    final matchedCity = _cities.keys.where(
      (city) => city.toLowerCase() == initialDestination,
    );
    if (matchedCity.isNotEmpty) {
      _dest = matchedCity.first;
    }
  }

  double get _rate =>
      widget.suggestedRatePerKm ??
      (widget.driver['ratePerKm'] as num?)?.toDouble() ??
      0.0;

  double get _distanceKm {
    if (_hasMapSelection) {
      return _haversineKm(
            widget.initialPickupLat!,
            widget.initialPickupLng!,
            widget.initialDestinationLat!,
            widget.initialDestinationLng!,
          ) *
          1.25;
    }

    final (lat1, lng1) = _cities[_pickup]!;
    final (lat2, lng2) = _cities[_dest]!;
    return _haversineKm(lat1, lng1, lat2, lng2) * 1.25;
  }

  double get _estimatedFare => _distanceKm * _rate;

  Future<void> _sendRequest() async {
    final sameMapPoint =
        _hasMapSelection &&
        widget.initialPickupLat == widget.initialDestinationLat &&
        widget.initialPickupLng == widget.initialDestinationLng;
    if ((!_hasMapSelection && _pickup == _dest) || sameMapPoint) {
      setState(() => _error = 'Pickup and destination must be different.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (cityPickupLat, cityPickupLng) = _cities[_pickup]!;
      final (cityDestLat, cityDestLng) = _cities[_dest]!;
      final pickupLat = widget.initialPickupLat ?? cityPickupLat;
      final pickupLng = widget.initialPickupLng ?? cityPickupLng;
      final destLat = widget.initialDestinationLat ?? cityDestLat;
      final destLng = widget.initialDestinationLng ?? cityDestLng;
      final pickupAddress = widget.initialPickup ?? _pickup;
      final destAddress = widget.initialDestination ?? _dest;
      final driverId = widget.driver['_id'] as String;

      final resp = await ApiService.createRideRequest({
        'driverId': driverId,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'pickupAddress': pickupAddress,
        'destLat': destLat,
        'destLng': destLng,
        'destAddress': destAddress,
        'estimatedDistanceKm': double.parse(_distanceKm.toStringAsFixed(2)),
        if (widget.suggestedRatePerKm != null)
          'suggestedRatePerKm': widget.suggestedRatePerKm,
      });

      final requestId = resp.data['_id'] as String;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingForDriverScreen(
            requestId: requestId,
            driver: widget.driver,
            distanceKm: _distanceKm,
            ratePerKm: _rate,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityList = _cities.keys.toList();
    final fare = _estimatedFare;
    final dist = _distanceKm;
    final negotiated = widget.suggestedRatePerKm != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hasMapSelection) ...[
              _locationSummary(
                icon: Icons.trip_origin,
                label: 'Pickup Location',
                value: widget.initialPickup ?? 'Pinned pickup',
              ),
              const SizedBox(height: 12),
              _locationSummary(
                icon: Icons.location_on,
                label: 'Destination',
                value: widget.initialDestination ?? 'Pinned destination',
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _pickup,
                decoration: const InputDecoration(
                  labelText: 'Pickup Location',
                  border: OutlineInputBorder(),
                ),
                items: cityList
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _pickup = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _dest,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  border: OutlineInputBorder(),
                ),
                items: cityList
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _dest = v!),
              ),
            ],
            const SizedBox(height: 24),

            // --- Estimates ───────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _estimateRow(
                      'Estimated Distance',
                      '${dist.toStringAsFixed(1)} km',
                    ),
                    _estimateRow(
                      'Rate per km',
                      'Rs. ${_rate.toStringAsFixed(0)}${negotiated ? ' (negotiated)' : ''}',
                    ),
                    const Divider(),
                    _estimateRow(
                      'Estimated Fare',
                      'Rs. ${fare.toStringAsFixed(0)}',
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendRequest,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send Ride Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationSummary({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF333336)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
