import 'package:flutter/material.dart';
import 'package:ridex_driver/offline/offline_trip.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../providers/active_trip_provider.dart';
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
      try {
        await OfflineDatabase.instance.queueOfflineSnapshot(owner, trip.data);
      } on DatabaseException catch (error, stack) {
        // The meter has already persisted the completed journal. SyncService
        // reconstructs the queue from that journal on its next retry.
        debugPrint('Offline trip queue failed: $error\n$stack');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip saved. Cloud sync will retry later.'),
            ),
          );
        }
      }
      if (context.mounted) {
        // Local completion succeeds regardless of network availability.
        final auth = context.read<AuthProvider>();
        SyncService.instance.syncPendingTrips(auth.api);
        // The trip is finished: let Home and the request screens know.
        context.read<ActiveTripProvider>().refresh(auth.api, owner);
      }
    },
  );
}
