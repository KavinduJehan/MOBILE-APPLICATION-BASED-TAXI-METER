import 'package:flutter/material.dart';

import '../models/trip_record.dart';
import '../widgets/app_widgets.dart';
import 'home_screen.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key, required this.trip, this.receiptNumber});

  final TripRecord trip;
  final String? receiptNumber;

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Trip Summary')),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StatusPill(label: 'Completed', color: Color(0xFF22C55E)),
                  const SizedBox(height: 16),
                  Text(trip.customerName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  InfoRow(label: 'Route', value: '${trip.startAddress} -> ${trip.endAddress}'),
                  InfoRow(label: 'Distance', value: '${trip.distanceKm.toStringAsFixed(1)} km'),
                  InfoRow(label: 'Rate', value: 'Rs. ${trip.ratePerKm.toStringAsFixed(2)} / km'),
                  InfoRow(label: 'Total fare', value: 'Rs. ${trip.fare.toStringAsFixed(2)}'),
                  InfoRow(label: 'Receipt', value: receiptNumber?.isNotEmpty == true ? receiptNumber! : 'Not provided'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'Back to Home',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}