import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ridex_driver/offline/offline_trip.dart';
import 'package:provider/provider.dart';
import '../providers/active_trip_provider.dart';
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
    TripStore.syncChanges.addListener(_load);
    _load();
    // Refresh the QR image when online; offline we keep the cached profile.
    final auth = context.read<AuthProvider>();
    Future.microtask(() async {
      try {
        await auth.loadProfile();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    TripStore.syncChanges.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final trips = await TripStore.all(_owner);
    if (!mounted) return;
    setState(() => _trips = trips);
    // Keep Home and the request screens in step with this screen.
    final auth = context.read<AuthProvider>();
    await context.read<ActiveTripProvider>().refresh(auth.api, _owner);
  }

  Future<void> _openTrip(TripSession trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverOfflineTripScreen(trip: trip, owner: _owner),
      ),
    );
    await _load();
  }

  Future<void> _scan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanTripOfferScreen()),
    );
    await _load();
  }

  Uint8List? _decodeQr(String raw) {
    if (raw.isEmpty) return null;
    try {
      return base64Decode(raw.contains(',') ? raw.split(',').last : raw);
    } catch (_) {
      return null;
    }
  }

  void _enlargeQr(Uint8List bytes) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: OfflineUi.panel,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your driver QR',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stepPanel({
    required int number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return OfflinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                child: Text(
                  '$number',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: OfflineUi.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _qrStep() {
    final profile = context.watch<AuthProvider>().profile;
    final bytes = _decodeQr(profile?.qrCode ?? '');
    return _stepPanel(
      number: 1,
      title: 'Passenger scans your QR',
      subtitle: 'They enter their rate and make an offer.',
      child: Column(
        children: [
          GestureDetector(
            onTap: bytes == null ? null : () => _enlargeQr(bytes),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: bytes == null
                  ? const SizedBox(
                      width: 190,
                      height: 190,
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        size: 90,
                        color: Colors.black38,
                      ),
                    )
                  : Image.memory(bytes, width: 190, height: 190),
            ),
          ),
          const SizedBox(height: 10),
          if (bytes == null)
            const OfflineNotice(
              'Your QR isn’t saved on this phone yet. Connect to the internet once to load it.',
              tone: OfflineTone.warning,
            )
          else ...[
            Text(
              [
                profile?.name,
                profile?.vehicleNumber,
              ].where((e) => e != null && e.isNotEmpty).join(' • '),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'Tap the code to enlarge it',
              style: TextStyle(color: OfflineUi.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _trips.where((trip) => !trip.completed).toList();
    final completed = _trips
        .where((trip) => trip.completed && trip.data['serverId'] == null)
        .toList();
    final block = context.watch<ActiveTripProvider>().onlineTrip == null
        ? null
        : 'Finish your current ride before starting an offline trip.';
    return Scaffold(
      appBar: AppBar(title: const Text('Offline trips')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (active.isNotEmpty) ...[
              for (final trip in active)
                OfflineJourneyCard(
                  trip: trip,
                  driverMode: true,
                  onTap: () => _openTrip(trip),
                ),
              const OfflineNotice(
                'Finish your current trip before taking another offline passenger.',
              ),
            ] else ...[
              const OfflineHeader(
                icon: Icons.offline_bolt_rounded,
                title: 'Pick up a passenger',
                subtitle: 'Works without mobile data.',
              ),
              const SizedBox(height: 16),
              if (block != null) ...[
                OfflineNotice(block, tone: OfflineTone.warning),
                const SizedBox(height: 12),
              ],
              _qrStep(),
              const SizedBox(height: 12),
              _stepPanel(
                number: 2,
                title: 'Scan their offer',
                subtitle: 'Then accept and show the confirmation QR.',
                child: FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan passenger offer'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: block != null ? null : _scan,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Waiting to sync',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (completed.isEmpty)
              const OfflinePanel(
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: OfflineUi.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All caught up. Finished trips appear here until they upload.',
                        style: TextStyle(color: OfflineUi.muted),
                      ),
                    ),
                  ],
                ),
              ),
            for (final trip in completed)
              OfflineJourneyCard(
                trip: trip,
                driverMode: true,
                onTap: () => _openTrip(trip),
              ),
          ],
        ),
      ),
    );
  }
}
