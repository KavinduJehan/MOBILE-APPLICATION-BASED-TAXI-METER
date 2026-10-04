import 'package:flutter/material.dart';

import '../models/trip_record.dart';
import '../theme/app_theme.dart';
import '../utils/trip_place_label.dart';
import '../widgets/app_widgets.dart';
import 'home_screen.dart';

class DriverReceiptScreen extends StatelessWidget {
  const DriverReceiptScreen({
    super.key,
    required this.trip,
    this.receiptNumber,
  });

  final TripRecord trip;
  final String? receiptNumber;

  @override
  Widget build(BuildContext context) {
    final date = trip.date?.toLocal();
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Receipt')),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF34D399),
                    size: 60,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Trip Completed',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'RideX',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'TRIP RECEIPT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _row('Passenger', trip.customerName),
                        _row('Pickup', tripPlaceLabel(trip.startAddress)),
                        _row('Destination', tripPlaceLabel(trip.endAddress)),
                        _row(
                          'Distance',
                          '${trip.distanceKm.toStringAsFixed(2)} km',
                        ),
                        _row(
                          'Rate per km',
                          'Rs. ${trip.ratePerKm.toStringAsFixed(2)}',
                        ),
                        _row('Payment method', 'Cash'),
                        if (date != null)
                          _row(
                            'Date / time',
                            '${date.day}/${date.month}/${date.year} '
                                '${date.hour.toString().padLeft(2, '0')}:'
                                '${date.minute.toString().padLeft(2, '0')}',
                          ),
                        const SizedBox(height: 12),
                        _row(
                          'Total fare',
                          'Rs. ${trip.fare.toStringAsFixed(2)}',
                          total: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryActionButton(
                    label: 'Back to Home',
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const DriverHomeScreen(),
                      ),
                      (_) => false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool total = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white10)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: total ? Colors.white : Colors.white54,
              fontSize: total ? 16 : 13,
              fontWeight: total ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: total ? const Color(0xFF34D399) : Colors.white,
              height: 1.4,
              fontSize: total ? 20 : 14,
              fontWeight: total ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
