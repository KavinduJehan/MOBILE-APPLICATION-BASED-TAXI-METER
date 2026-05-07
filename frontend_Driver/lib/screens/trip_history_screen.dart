import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  bool _loading = true;
  List<TripRecord> _trips = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    try {
      final trips = await auth.api.getMyTrips();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Unable to load trips')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Trip History')),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            const SectionTitle(title: 'Completed rides', subtitle: 'Review past trips, fares, and statuses.'),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator()))
            else if (_trips.isEmpty)
              const EmptyStateCard(
                title: 'No trips yet',
                subtitle: 'Your completed rides will appear here once the first trip is closed.',
                icon: Icons.route_rounded,
              )
            else
              ..._trips.map((trip) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _TripCard(trip: trip))),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripRecord trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1422),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(trip.customerName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              StatusPill(label: trip.status.toUpperCase(), color: const Color(0xFF69A8FF)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${trip.startAddress} -> ${trip.endAddress}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Info(label: 'Date', value: _formatDate(trip.date))),
              Expanded(child: _Info(label: 'Distance', value: '${trip.distanceKm.toStringAsFixed(1)} km')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Info(label: 'Fare', value: 'Rs. ${trip.fare.toStringAsFixed(2)}')),
              Expanded(child: _Info(label: 'Receipt', value: trip.receiptNumber?.isNotEmpty == true ? trip.receiptNumber! : '-')),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white54)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}