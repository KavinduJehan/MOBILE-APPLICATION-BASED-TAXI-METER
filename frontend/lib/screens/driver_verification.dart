import 'package:flutter/material.dart';
import 'rate_comparison.dart';
import 'negotiate_screen.dart';
import 'ride_request_screen.dart';

class DriverVerificationScreen extends StatelessWidget {
  const DriverVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 35,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Kasun Perera",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Verified Driver",
                    style: TextStyle(color: Colors.green),
                  ),
                ),
                const Divider(height: 30),

                infoRow(Icons.directions_car, "Vehicle No", "WP CAB 1234"),
                infoRow(Icons.badge, "Driver ID", "DRV20240056"),
                infoRow(Icons.location_on, "Area", "Galle"),
                infoRow(Icons.payments, "Rate per km", "Rs. 150 / km"),

                const SizedBox(height: 20),

                ElevatedButton(
                  child: const Text("Compare Rate"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RateComparison(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                ElevatedButton(
                  child: const Text("Negotiate Rate"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NegotiateScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Start Ride"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RideRequestScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}