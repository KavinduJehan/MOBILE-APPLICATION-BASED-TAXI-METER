// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'driver_verification.dart';

class QRScan extends StatelessWidget {
  const QRScan({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Driver QR")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 120,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text("Align QR code inside the frame"),
            const SizedBox(height: 30),
            ElevatedButton(
              child: const Text("Simulate QR Scan"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverVerificationScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}