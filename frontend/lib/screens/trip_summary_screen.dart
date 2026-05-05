import 'package:flutter/material.dart';
import 'receipt.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trip Summary")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            summaryRow("Total Distance", "5.0 km"),
            summaryRow("Rate per km", "Rs. 150"),
            summaryRow("Total Fare", "Rs. 750"),
            summaryRow("Driver", "Kasun Perera"),
            summaryRow("Vehicle", "WP CAB 1234"),
            const Spacer(),
            ElevatedButton(
              child: const Text("Generate Receipt"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReceiptScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget summaryRow(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value),
      ),
    );
  }
}