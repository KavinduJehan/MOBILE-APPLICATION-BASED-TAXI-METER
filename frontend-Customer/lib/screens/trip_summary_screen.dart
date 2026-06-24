import 'package:flutter/material.dart';

import '../models/receipt_model.dart';
import '../models/trip_model.dart';
import '../theme.dart';
import 'receipt.dart';

class TripSummaryScreen extends StatelessWidget {
  final TripModel trip;
  final ReceiptModel? receipt;

  const TripSummaryScreen({
    super.key,
    required this.trip,
    this.receipt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Trip Summary')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppTheme.successGreen,
              size: 64,
            ),
            const SizedBox(height: 12),
            const Text(
              'Trip Completed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _summaryRow('Driver', trip.driverName),
            _summaryRow('Vehicle', trip.vehicleNumber),
            _summaryRow('Pickup', trip.pickupLocation),
            _summaryRow('Drop', trip.dropLocation),
            _summaryRow('Total distance', '${trip.distanceKm.toStringAsFixed(1)} km'),
            _summaryRow('Rate per km', 'Rs. ${trip.ratePerKm.toStringAsFixed(2)}'),
            const Divider(color: Color(0xFF333336)),
            _summaryRow(
              'Total fare',
              'Rs. ${trip.totalFare.toStringAsFixed(2)}',
              bold: true,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptScreen(
                    trip: trip,
                    initialReceipt: receipt,
                  ),
                ),
              ),
              child: const Text('View Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF))),
      trailing: Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
