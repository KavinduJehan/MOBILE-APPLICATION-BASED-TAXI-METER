import 'package:flutter/material.dart';

import '../models/trip_record.dart';
import '../theme/app_theme.dart';
import '../utils/trip_place_label.dart';
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
    final receipt = receiptNumber?.trim().isNotEmpty == true
        ? receiptNumber!.trim()
        : trip.receiptNumber;
    final date = trip.date?.toLocal();

    return AppShellScaffold(
      appBar: AppBar(
        title: const Text('Trip summary'),
        automaticallyImplyLeading: false,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _panel(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14332D), Color(0xFF101826)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF34D399,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF34D399),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Trip completed',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your trip summary is ready',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'TOTAL FARE',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs. ${trip.fare.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppTheme.surfaceAlt,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PASSENGER',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trip.customerName.trim().isEmpty
                                      ? 'Customer'
                                      : trip.customerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Divider(height: 1, color: Colors.white10),
                      ),
                      _routePoint(
                        Icons.radio_button_checked,
                        AppTheme.accent,
                        'PICKUP',
                        trip.startAddress,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 9, top: 4, bottom: 4),
                        child: SizedBox(
                          height: 20,
                          child: VerticalDivider(
                            width: 1,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                      _routePoint(
                        Icons.location_on_rounded,
                        const Color(0xFF34D399),
                        'DESTINATION',
                        trip.endAddress,
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          '${date.day}/${date.month}/${date.year} at '
                          '${date.hour.toString().padLeft(2, '0')}:'
                          '${date.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _panel(
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 20,
                    children: [
                      _stat(
                        Icons.route_rounded,
                        'Distance',
                        '${trip.distanceKm.toStringAsFixed(2)} km',
                      ),
                      _stat(
                        Icons.payments_outlined,
                        'Rate per km',
                        'Rs. ${trip.ratePerKm.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                if (surge != null) ...[
                  const SizedBox(height: 16),
                  _panel(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.accent,
                      ),
                      title: const Text(
                        'Pricing details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${_factor(surge, 'multiplier')}x multiplier',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      children: [
                        _pricingRow(
                          'Demand / supply',
                          _factor(surge, 'demandSupplyFactor'),
                          '${surge['availableDrivers'] ?? 0} drivers, ${surge['activeRequests'] ?? 0} requests',
                        ),
                        _pricingRow(
                          'Time of day',
                          _factor(surge, 'timeFactor'),
                        ),
                        _pricingRow(
                          'Weather',
                          _factor(surge, 'weatherFactor'),
                          surge['weatherCondition']?.toString() ?? '',
                        ),
                        _pricingRow('Area tier', _factor(surge, 'areaFactor')),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryActionButton(
                  label: 'Back to Home',
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
                    (route) => false,
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryActionButton(
                  label: 'View Receipt',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DriverReceiptScreen(
                        trip: trip,
                        receiptNumber: receipt,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _factor(Map<String, dynamic> values, String key) =>
      (num.tryParse('${values[key]}') ?? 1).toStringAsFixed(2);

  Widget _panel({
    required Widget child,
    Gradient? gradient,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
    ),
    child: child,
  );

  Widget _routePoint(
    IconData icon,
    Color color,
    String label,
    String address,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              tripPlaceLabel(address),
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _stat(IconData icon, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppTheme.accent),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );

  Widget _pricingRow(String label, String factor, [String detail = '']) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13)),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${factor}x',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}
