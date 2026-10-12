import 'package:flutter/material.dart';
import 'package:customer_app/offline/offline_trip.dart';
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
  bool _identityReady = false;
  bool _preparing = false;
  bool _refreshing = false;
  String get _owner => context.read<AuthProvider>().customer?.id ?? '';
  @override
  void initState() {
    super.initState();
    TripStore.syncChanges.addListener(_load);
    _load();
    _prepare();
  }

  Future<void> _prepare() async {
    if (_preparing) return;
    setState(() => _preparing = true);
    final saved = await OfflineIdentityService.cached(_owner);
    if (mounted) setState(() => _identityReady = saved != null);
    try {
      await OfflineIdentityService.prepare(_owner);
      if (mounted) setState(() => _identityReady = true);
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
              ? 'Connect once and tap Prepare account to link trips to your account. Local trips still work without it.'
              : 'Using your saved offline identity.',
        );
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  void dispose() {
    TripStore.syncChanges.removeListener(_load);
    super.dispose();
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
    if (_refreshing) return;
    setState(() => _refreshing = true);
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
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openTrip(TripSession trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OfflineMeterScreen(trip: trip, owner: _owner, driverMode: false),
      ),
    );
    await _load();
  }

  Future<void> _resumeOffer() async {
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
          agreedRatePerKm: (offer['agreedRatePerKm'] as num).toDouble(),
          isOffline: true,
        ),
      ),
    );
    await _load();
  }

  Future<void> _start() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScan(offlineOnly: true)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _trips.where((trip) => !trip.completed).toList();
    final completed = _trips
        .where((trip) => trip.completed && trip.data['serverId'] == null)
        .toList();
    final busy = active.isNotEmpty || _pendingOffer != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline trips')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final trip in active)
              OfflineJourneyCard(
                trip: trip,
                driverMode: false,
                onTap: () => _openTrip(trip),
              ),
            if (_pendingOffer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OfflinePanel(
                  highlight: true,
                  onTap: _resumeOffer,
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Continue your trip offer',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Show it to ${_pendingOffer!['driverName']}, then scan their confirmation.',
                              style: const TextStyle(
                                color: OfflineUi.muted,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: OfflineUi.muted,
                      ),
                    ],
                  ),
                ),
              ),
            if (!busy) ...[
              const OfflineHeader(
                icon: Icons.offline_bolt_rounded,
                title: 'Ride without mobile data',
                subtitle: 'Scan your driver’s QR to agree a fare.',
              ),
              const OfflineHandshakeSteps(),
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start offline trip'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _start,
              ),
            ] else
              const OfflineNotice(
                'Finish or discard your current trip before starting another.',
              ),
            const SizedBox(height: 12),
            if (!_identityReady)
              OfflineNotice(
                _message ??
                    'Prepare your account while online so trips link to you when the driver syncs.',
                tone: OfflineTone.warning,
                action: _preparing ? 'Preparing…' : 'Prepare',
                onAction: _preparing ? null : _prepare,
              )
            else if (_message != null)
              OfflineNotice(
                _message!,
                tone: _message!.startsWith('Could not')
                    ? OfflineTone.warning
                    : OfflineTone.success,
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saved on this phone',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh synced trips',
                  onPressed: _refreshing ? null : _refreshCloud,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (completed.isEmpty)
              const OfflinePanel(
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: OfflineUi.muted),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No offline trips yet. Finished trips show up here.',
                        style: TextStyle(color: OfflineUi.muted),
                      ),
                    ),
                  ],
                ),
              ),
            for (final trip in completed)
              OfflineJourneyCard(
                trip: trip,
                driverMode: false,
                onTap: () => _openTrip(trip),
              ),
          ],
        ),
      ),
    );
  }
}
