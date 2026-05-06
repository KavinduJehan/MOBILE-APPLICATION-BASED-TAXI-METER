import 'package:flutter/material.dart';
import 'trip_summary_screen.dart';

class TripProgressScreen extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> driver;
  final double distanceKm;
  final double ratePerKm;

  const TripProgressScreen({
    super.key,
    required this.requestId,
    required this.driver,
    required this.distanceKm,
    required this.ratePerKm,
  });

  @override
  Widget build(BuildContext context) {
    final driverName = driver['name'] as String? ?? 'Driver';
    final fare = distanceKm * ratePerKm;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip In Progress')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text('Trip with $driverName'),
                subtitle: const Text('Enjoy your ride'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Distance'),
                trailing: Text('${distanceKm.toStringAsFixed(1)} km'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Estimated Fare'),
                trailing: Text('Rs. ${fare.toStringAsFixed(0)}'),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('End Trip'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TripSummaryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
