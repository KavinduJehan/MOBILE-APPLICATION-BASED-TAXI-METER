import 'package:flutter/material.dart';

class RateComparison extends StatelessWidget {
  const RateComparison({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate Comparison")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            Card(
              child: ListTile(
                title: Text("Driver Rate"),
                trailing: Text("Rs. 150 / km"),
              ),
            ),
            Card(
              child: ListTile(
                title: Text("Average Rate in Galle"),
                trailing: Text("Rs. 130 / km"),
              ),
            ),
            Card(
              child: ListTile(
                title: Text("Status"),
                trailing: Text(
                  "Normal Rate",
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}