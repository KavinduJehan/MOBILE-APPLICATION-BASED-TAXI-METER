import 'package:flutter/material.dart';
import 'trip_summary_screen.dart';

class TripProgressScreen extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> driver;
  final double distanceKm;
  final double ratePerKm;
  final double totalFare;

  const TripProgressScreen({
    super.key,
    required this.requestId,
    required this.driver,
    required this.distanceKm,
    required this.ratePerKm,
    required this.totalFare,
  });

  @override
  Widget build(BuildContext context) {
    final driverName = driver['name'] as String? ?? 'Driver';
    final vehicleNumber = driver['vehicleNumber'] as String? ?? '—';

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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => _confirmEndTrip(context),
                child: const Text('End Trip'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmEndTrip(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip?'),
        content: const Text(
          'Are you sure you want to end the trip? The driver will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TripSummaryScreen(
                    driverName: driver['name'] as String? ?? '—',
                    vehicleNumber: driver['vehicleNumber'] as String? ?? '—',
                    distanceKm: distanceKm,
                    ratePerKm: ratePerKm,
                    totalFare: totalFare,
                  ),
                ),
              );
            },
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
  }
}
