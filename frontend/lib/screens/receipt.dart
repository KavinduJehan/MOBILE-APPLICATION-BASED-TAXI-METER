import 'package:flutter/material.dart';
import 'home.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Receipt")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const Text(
              "Payment Completed",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            receiptRow("Receipt ID", "#RCP123456"),
            receiptRow("Driver", "Kasun Perera"),
            receiptRow("Vehicle", "WP CAB 1234"),
            receiptRow("Distance", "5.0 km"),
            receiptRow("Rate", "Rs. 150"),
            receiptRow("Total Fare", "Rs. 750"),
            const Spacer(),
            ElevatedButton(
              child: const Text("Back to Home"),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const Home()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget receiptRow(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(value),
    );
  }
}