import 'package:flutter/material.dart';
import 'home.dart';

class ReceiptScreen extends StatelessWidget {
  final String driverName;
  final String vehicleNumber;
  final double distanceKm;
  final double ratePerKm;
  final double totalFare;

  const ReceiptScreen({
    super.key,
    required this.driverName,
    required this.vehicleNumber,
    required this.distanceKm,
    required this.ratePerKm,
    required this.totalFare,
  });

  /// Generate a local receipt number from current timestamp (e.g. RCP-A3F9)
  String get _receiptNumber {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'RCP-${ts.toRadixString(16).substring(6).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 8),
            const Text(
              'Trip Completed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _receiptRow('Receipt No', _receiptNumber),
            _receiptRow('Driver', driverName),
            _receiptRow('Vehicle', vehicleNumber),
            _receiptRow('Distance', '${distanceKm.toStringAsFixed(1)} km'),
            _receiptRow('Rate', 'Rs. ${ratePerKm.toStringAsFixed(0)} / km'),
            const Divider(),
            _receiptRow(
              'Total Fare',
              'Rs. ${totalFare.toStringAsFixed(0)}',
              bold: true,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const Home()),
                  (_) => false,
                ),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
