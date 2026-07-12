import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'trip_summary_screen.dart';

class ActiveTripScreen extends StatelessWidget {
  const ActiveTripScreen({super.key, required this.trip, this.receiptNumber});

  final TripRecord trip;
  final String? receiptNumber;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Active Trip')),
      child: SingleChildScrollView(
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
                  Text(trip.customerName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  InfoRow(label: 'Route', value: '${trip.startAddress} -> ${trip.endAddress}'),
                  InfoRow(label: 'Distance', value: '${trip.distanceKm.toStringAsFixed(1)} km'),
                  InfoRow(label: 'Rate', value: 'Rs. ${trip.ratePerKm.toStringAsFixed(2)} / km'),
                  InfoRow(label: 'Estimated fare', value: 'Rs. ${trip.estimatedFare.toStringAsFixed(2)}'),
                ],
              ), 
            ),
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'End Trip',
              isBusy: auth.busy,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('End trip?'),
                    content: const Text('This will close the trip and generate the receipt.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('End Trip')),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  final result = await auth.api.endTrip(trip.id);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => TripSummaryScreen(trip: result.trip, receiptNumber: result.receiptNumber ?? receiptNumber),
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Unable to end trip')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}