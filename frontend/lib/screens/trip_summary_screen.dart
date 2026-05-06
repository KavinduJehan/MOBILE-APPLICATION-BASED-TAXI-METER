import 'package:flutter/material.dart';
import 'receipt.dart';

class TripSummaryScreen extends StatelessWidget {
  final String driverName;
  final String vehicleNumber;
  final double distanceKm;
  final double ratePerKm;
  final double totalFare;

  const TripSummaryScreen({
    super.key,
    required this.driverName,
    required this.vehicleNumber,
    required this.distanceKm,
    required this.ratePerKm,
    required this.totalFare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Summary')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 12),
            const Text(
              'Trip Completed',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _summaryRow('Driver', driverName),
            _summaryRow('Vehicle', vehicleNumber),
            _summaryRow(
              'Total Distance',
              '${distanceKm.toStringAsFixed(1)} km',
            ),
            _summaryRow('Rate per km', 'Rs. ${ratePerKm.toStringAsFixed(0)}'),
            const Divider(),
            _summaryRow(
              'Total Fare',
              'Rs. ${totalFare.toStringAsFixed(0)}',
              bold: true,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiptScreen(
                      driverName: driverName,
                      vehicleNumber: vehicleNumber,
                      distanceKm: distanceKm,
                      ratePerKm: ratePerKm,
                      totalFare: totalFare,
                    ),
                  ),
                ),
                child: const Text('View Receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
