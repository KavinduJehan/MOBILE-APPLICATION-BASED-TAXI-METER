import 'package:flutter/material.dart';
import 'package:offline_trip/offline_trip.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'offline_trip_screen.dart';
import 'scan_trip_offer_screen.dart';

class DriverOfflineTripsScreen extends StatefulWidget {
  const DriverOfflineTripsScreen({super.key});
  @override
  State<DriverOfflineTripsScreen> createState() =>
      _DriverOfflineTripsScreenState();
}

class _DriverOfflineTripsScreenState extends State<DriverOfflineTripsScreen> {
  List<TripSession> _trips = [];
  String get _owner => context.read<AuthProvider>().profile?.id ?? '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await TripStore.all(_owner);
    if (mounted) setState(() => _trips = trips);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline Trips')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan passenger offer'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanTripOfferScreen()),
            );
            await _load();
          },
        ),
        const OfflineTripMap(points: []),
        const SizedBox(height: 16),
        for (final trip in _trips)
          ListTile(
            title: Text(trip.data['customerName']?.toString() ?? 'Passenger'),
            subtitle: Text(
              '${trip.status} • ${trip.distanceKm.toStringAsFixed(2)} km • Rs. ${trip.fare.toStringAsFixed(2)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DriverOfflineTripScreen(trip: trip, owner: _owner),
                ),
              );
              await _load();
            },
          ),
      ],
    ),
  );
}
