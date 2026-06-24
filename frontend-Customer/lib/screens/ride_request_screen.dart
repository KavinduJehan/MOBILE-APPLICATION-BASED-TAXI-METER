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

  const RideRequestScreen({
    super.key,
    required this.driver,
    this.suggestedRatePerKm,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  String _pickup = 'Colombo';
  String _dest = 'Galle';
  bool _loading = false;
  String? _error;

  double get _rate =>
      widget.suggestedRatePerKm ??
      (widget.driver['ratePerKm'] as num?)?.toDouble() ??
      0.0;

  double get _distanceKm {
    final (lat1, lng1) = _cities[_pickup]!;
    final (lat2, lng2) = _cities[_dest]!;
    return _haversineKm(lat1, lng1, lat2, lng2) * 1.25;
  }

  double get _estimatedFare => _distanceKm * _rate;

  Future<void> _sendRequest() async {
    if (_pickup == _dest) {
      setState(() => _error = 'Pickup and destination must be different.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (pLat, pLng) = _cities[_pickup]!;
      final (dLat, dLng) = _cities[_dest]!;
      final driverId = widget.driver['_id'] as String;

      final resp = await ApiService.createRideRequest({
        'driverId': driverId,
        'pickupLat': pLat,
        'pickupLng': pLng,
        'pickupAddress': _pickup,
        'destLat': dLat,
        'destLng': dLng,
        'destAddress': _dest,
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
            // ── Pickup ──────────────────────────────────────────────────────
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

            // ── Destination ─────────────────────────────────────────────────
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
            const SizedBox(height: 24),

            // ── Estimates ───────────────────────────────────────────────────
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
