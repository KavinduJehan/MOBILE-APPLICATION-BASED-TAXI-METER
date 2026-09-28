import 'package:flutter/material.dart';

import '../models/trip_record.dart';
import '../widgets/app_widgets.dart';
import 'driver_receipt_screen.dart';
import 'home_screen.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key, required this.trip, this.receiptNumber});

  final TripRecord trip;
  final String? receiptNumber;

  @override
  Widget build(BuildContext context) {
    final surge = trip.surgeBreakdown;
    final isSurge = surge != null;

    return AppShellScaffold(
      appBar: AppBar(title: const Text('Trip Summary')),
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
                  Row(
                    children: [
                      const StatusPill(label: 'Completed', color: Color(0xFF22C55E)),
                      if (isSurge) ...[
                        const SizedBox(width: 8),
                        StatusPill(
                          label: '${((surge['multiplier'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(2)}× SURGE',
                          color: const Color(0xFF6C7CFF),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(trip.customerName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  InfoRow(label: 'Route', value: '${trip.startAddress} → ${trip.endAddress}'),
                  InfoRow(label: 'Distance', value: '${trip.distanceKm.toStringAsFixed(1)} km'),
                  InfoRow(label: 'Rate', value: 'Rs. ${trip.ratePerKm.toStringAsFixed(2)} / km'),
                  if (isSurge)
                    InfoRow(
                      label: 'Surge multiplier',
                      value: '${((surge['multiplier'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(2)}×',
                    ),
                  InfoRow(label: 'Total fare', value: 'Rs. ${trip.fare.toStringAsFixed(2)}'),
                  InfoRow(label: 'Receipt', value: receiptNumber?.isNotEmpty == true ? receiptNumber! : 'Generated'),
                ],
              ),
            ),

            if (isSurge) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1422),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C7CFF).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFF6C7CFF), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Surge pricing breakdown',
                          style: TextStyle(
                            color: Color(0xFF6C7CFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _breakdownRow(
                      '🚗',
                      'Demand / supply',
                      '${(surge['availableDrivers'] as num?)?.toInt() ?? 0} drivers · ${(surge['activeRequests'] as num?)?.toInt() ?? 0} req',
                      (surge['demandSupplyFactor'] as num?)?.toDouble() ?? 1.0,
                    ),
                    _breakdownRow(
                      '🕐',
                      'Time of day',
                      '',
                      (surge['timeFactor'] as num?)?.toDouble() ?? 1.0,
                    ),
                    _breakdownRow(
                      '🌦',
                      'Weather',
                      surge['weatherCondition']?.toString() ?? '-',
                      (surge['weatherFactor'] as num?)?.toDouble() ?? 1.0,
                    ),
                    _breakdownRow(
                      '📍',
                      'Area tier',
                      '',
                      (surge['areaFactor'] as num?)?.toDouble() ?? 1.0,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            SecondaryActionButton(
              label: 'View Full Receipt',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DriverReceiptScreen(trip: trip)),
                );
              },
            ),
            const SizedBox(height: 12),
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

  Widget _breakdownRow(String icon, String label, String detail, double factor) {
    final color = factor >= 1.3 ? Colors.orangeAccent : Colors.white60;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (detail.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('($detail)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ],
            ),
          ),
          Text(
            '${factor.toStringAsFixed(2)}×',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}