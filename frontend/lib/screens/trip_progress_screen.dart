import 'package:flutter/material.dart';
import 'trip_summary_screen.dart';

class TripProgressScreen extends StatelessWidget {
  const TripProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trip In Progress")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Card(
              child: ListTile(
                title: Text("Trip Started"),
                subtitle: Text("Enjoy your ride"),
              ),
            ),
            const Card(
              child: ListTile(
                title: Text("Distance"),
                trailing: Text("2.3 km"),
              ),
            ),
            const Card(
              child: ListTile(
                title: Text("Current Fare"),
                trailing: Text("Rs. 345"),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("End Trip"),
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