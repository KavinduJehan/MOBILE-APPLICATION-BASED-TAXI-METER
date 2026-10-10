import 'package:flutter/material.dart';
import 'package:offline_trip/offline_trip.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/offline_database.dart';
import '../services/sync_service.dart';

class DriverOfflineTripScreen extends StatelessWidget {
  const DriverOfflineTripScreen({
    super.key,
    required this.trip,
    required this.owner,
  });
  final TripSession trip;
  final String owner;
  @override
  Widget build(BuildContext context) => OfflineMeterScreen(
    trip: trip,
    owner: owner,
    driverMode: true,
    onComplete: (trip) async {
      await OfflineDatabase.instance.queueOfflineSnapshot(owner, trip.data);
      if (context.mounted) {
        // Local completion succeeds regardless of network availability.
        SyncService.instance.syncPendingTrips(context.read<AuthProvider>().api);
      }
    },
  );
}
