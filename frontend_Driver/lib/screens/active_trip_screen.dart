import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../services/offline_database.dart';
import '../widgets/app_widgets.dart';
import 'trip_summary_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key, required this.trip, this.receiptNumber});

  final TripRecord trip;
  final String? receiptNumber;

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  late final DateTime _startTime;
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = widget.trip.date ?? DateTime.now();
    // Update every second so the timer is live
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startTime));
    });
    _elapsed = DateTime.now().difference(_startTime);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trip = widget.trip;
    // Live estimated fare = distance * rate (static trip info — fare is fixed at creation,
    // but we show elapsed time so the driver knows how long the ride is taking)
    final estimatedFare = trip.estimatedFare;

    return AppShellScaffold(
      appBar: AppBar(title: const Text('Active Trip')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live timer banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF102742), Color(0xFF0C1929)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2F6BFF).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Trip in progress',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _elapsedLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Elapsed time', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trip details
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
                  Text(
                    trip.customerName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  InfoRow(label: 'Route',          value: '${trip.startAddress} → ${trip.endAddress}'),
                  InfoRow(label: 'Distance',        value: '${trip.distanceKm.toStringAsFixed(1)} km'),
                  InfoRow(label: 'Rate',            value: 'Rs. ${trip.ratePerKm.toStringAsFixed(2)} / km'),
                  if (trip.surgeBreakdown != null)
                    InfoRow(
                      label: 'Surge',
                      value: '${(trip.surgeBreakdown!['multiplier'] as num?)?.toStringAsFixed(2) ?? '1.00'}×',
                    ),
                  InfoRow(label: 'Estimated fare',  value: 'Rs. ${estimatedFare.toStringAsFixed(2)}'),
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
                      FilledButton(onPressed:  () => Navigator.pop(dialogContext, true),  child: const Text('End Trip')),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  final result = await auth.api.endTrip(trip.id);
                  // Cache to local SQLite so trip history works offline
                  await OfflineDatabase.instance.cacheServerTrip(result.trip);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => TripSummaryScreen(
                        trip: result.trip,
                        receiptNumber: result.receiptNumber ?? widget.receiptNumber,
                      ),
                    ),
                  );
                } catch (error) {
                  // Offline fallback: Save trip locally to SQLite & generate offline receipt
                  final offlineReceipt = 'REC-OFFLINE-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
                  final localId = 'offline-${DateTime.now().millisecondsSinceEpoch}';
                  final offlineTrip = TripRecord(
                    id: localId,
                    customerName: trip.customerName.isNotEmpty ? trip.customerName : 'Passenger',
                    startAddress: trip.startAddress,
                    endAddress: trip.endAddress,
                    distanceKm: trip.distanceKm,
                    ratePerKm: trip.ratePerKm,
                    fare: estimatedFare,
                    status: 'completed',
                    date: DateTime.now(),
                    receiptNumber: offlineReceipt,
                    surgeBreakdown: trip.surgeBreakdown,
                  );

                  await OfflineDatabase.instance.insertOfflineTrip(
                    localId: localId,
                    customerName: offlineTrip.customerName,
                    startAddress: offlineTrip.startAddress,
                    endAddress: offlineTrip.endAddress,
                    distanceKm: offlineTrip.distanceKm,
                    ratePerKm: offlineTrip.ratePerKm,
                    fare: offlineTrip.fare,
                    receiptNumber: offlineReceipt,
                    surgeBreakdown: offlineTrip.surgeBreakdown,
                    date: offlineTrip.date,
                  );

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offline mode: Trip saved locally. Will sync when online.'),
                      backgroundColor: Color(0xFFEAB308),
                    ),
                  );

                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => TripSummaryScreen(
                        trip: offlineTrip,
                        receiptNumber: offlineReceipt,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
