import 'package:flutter/material.dart';
import 'trip_progress_screen.dart';

class RideRequestScreen extends StatelessWidget {
  const RideRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pickupController = TextEditingController();
    final destinationController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text("Ride Request")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: pickupController,
              decoration: const InputDecoration(
                labelText: "Pickup Location",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: "Destination",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            const Text("Estimated Distance: 5.0 km"),
            const Text("Estimated Fare: Rs. 750"),
            const SizedBox(height: 25),
            ElevatedButton(
              child: const Text("Send Ride Request"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TripProgressScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}