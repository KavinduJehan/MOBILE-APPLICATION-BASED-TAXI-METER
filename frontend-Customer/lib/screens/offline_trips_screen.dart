import 'package:flutter/material.dart';
import 'package:offline_trip/offline_trip.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/offline_identity_service.dart';
import '../services/api_service.dart';
import 'qr_scan.dart';
import 'offline_trip_offer_screen.dart';

class CustomerOfflineTripsScreen extends StatefulWidget {
  const CustomerOfflineTripsScreen({super.key});
  @override
  State<CustomerOfflineTripsScreen> createState() =>
      _CustomerOfflineTripsScreenState();
}

class _CustomerOfflineTripsScreenState
    extends State<CustomerOfflineTripsScreen> {
  List<TripSession> _trips = [];
  Map<String, dynamic>? _pendingOffer;
  String? _message;
  String get _owner => context.read<AuthProvider>().customer?.id ?? '';
  @override
  void initState() {
    super.initState();
    _load();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await OfflineIdentityService.prepare(_owner);
      if (mounted) {
        setState(
          () => _message =
              'Ready to link future offline trips to your account when the driver syncs.',
        );
      }
    } catch (_) {
      final cached = await OfflineIdentityService.cached(_owner);
      if (mounted) {
        setState(
          () => _message = cached == null
              ? 'Connect once and tap Prepare for offline to link trips to your account. Local trips still work without it.'
              : 'Using your saved offline identity.',
        );
      }
    }
  }

  Future<void> _load() async {
    final trips = await TripStore.all(_owner);
    var offer = await TripStore.pendingOffer(_owner);
    if (offer != null && trips.any((trip) => trip.id == offer!['localId'])) {
      await TripStore.clearOffer(_owner);
      offer = null;
    }
    if (mounted) {
      setState(() {
        _trips = trips;
        _pendingOffer = offer;
      });
    }
  }

  Future<void> _refreshCloud() async {
    try {
      final response = await ApiService.dio.get('/trips/my');
      final items = response.data as List;
      for (final item in items) {
        final data = Map<String, dynamic>.from(item as Map);
        final localId = data['offlineLocalId'];
        if (localId is! String) continue;
        final trip = await TripStore.find(_owner, localId);
        if (trip == null) continue;
        trip.data.addAll({
          'serverId': data['_id'],
          'distanceKm': data['distanceKm'],
          'totalFare': data['totalFare'],
          'status': data['status'],
          'endTime': data['endTime'],
        });
        await TripStore.save(_owner, trip);
      }
      await _load();
      if (mounted) {
        setState(
          () => _message = 'Offline trip history refreshed from the server.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not refresh. Your local trips are still available.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline Trips')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan driver QR for offline trip'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const QRScan(offlineOnly: true),
              ),
            );
            await _load();
          },
        ),
        const Text(
          '1. Scan driver QR. 2. Show your offer. 3. Scan the driver’s acceptance to open your offline meter.',
        ),
        TextButton(
          onPressed: _prepare,
          child: const Text('Prepare for offline (while online)'),
        ),
        TextButton(
          onPressed: _refreshCloud,
          child: const Text('Refresh synced offline trips'),
        ),
        if (_message != null) Text(_message!),
        const OfflineTripMap(points: []),
        if (_pendingOffer != null)
          ListTile(
            title: const Text('Resume passenger offer / scan acceptance'),
            subtitle: Text(_pendingOffer!['driverName'].toString()),
            trailing: const Icon(Icons.qr_code),
            onTap: () async {
              final offer = _pendingOffer!;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfflineTripOfferScreen(
                    existingOffer: offer,
                    driver: {
                      'token': offer['driverToken'],
                      'name': offer['driverName'],
                      'vehicleNumber': offer['vehicleNumber'],
                    },
                    customerName: offer['customerName'] as String,
                    customerPhone: offer['customerPhone'] as String?,
                    agreedRatePerKm: (offer['agreedRatePerKm'] as num)
                        .toDouble(),
                    isOffline: true,
                  ),
                ),
              );
              await _load();
            },
          ),
        for (final trip in _trips)
          ListTile(
            title: Text(trip.data['driverName']?.toString() ?? 'Driver'),
            subtitle: Text(
              '${trip.status} • ${trip.distanceKm.toStringAsFixed(2)} km • Rs. ${trip.fare.toStringAsFixed(2)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfflineMeterScreen(
                    trip: trip,
                    owner: _owner,
                    driverMode: false,
                  ),
                ),
              );
              await _load();
            },
          ),
      ],
    ),
  );
}
