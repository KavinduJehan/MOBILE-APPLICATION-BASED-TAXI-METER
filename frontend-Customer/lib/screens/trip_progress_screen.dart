import 'package:flutter/material.dart';

import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import 'trip_summary_screen.dart';

class TripProgressScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> driver;
  final TripModel? trip;
  final double distanceKm;
  final double ratePerKm;
  final double totalFare;

  const TripProgressScreen({
    super.key,
    required this.requestId,
    required this.driver,
    this.trip,
    required this.distanceKm,
    required this.ratePerKm,
    required this.totalFare,
  });

  @override
  State<TripProgressScreen> createState() => _TripProgressScreenState();
}

class _TripProgressScreenState extends State<TripProgressScreen> {
  final _repository = const TripRepository();
  bool _ending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final driverName =
        widget.trip?.driverName ?? (widget.driver['name'] as String?) ?? 'Driver';
    final vehicleNumber = widget.trip?.vehicleNumber ??
        (widget.driver['vehicleNumber'] as String?) ??
        '-';
    final distanceKm = widget.trip?.distanceKm ?? widget.distanceKm;
    final ratePerKm = widget.trip?.ratePerKm ?? widget.ratePerKm;
    final totalFare = widget.trip?.totalFare ?? widget.totalFare;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip In Progress')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text('Trip with $driverName'),
                subtitle: Text(vehicleNumber),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.route),
                title: const Text('Distance'),
                trailing: Text('${distanceKm.toStringAsFixed(1)} km'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Rate per km'),
                trailing: Text('Rs. ${ratePerKm.toStringAsFixed(0)}'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments),
                title: const Text('Total Fare'),
                trailing: Text(
                  'Rs. ${totalFare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _ending ? null : () => _confirmEndTrip(context),
                child: _ending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('End Trip'),
              ),
            ),
          ],
        ),
      ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
