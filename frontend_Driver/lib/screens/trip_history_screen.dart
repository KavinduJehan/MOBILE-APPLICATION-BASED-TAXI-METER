import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'driver_receipt_screen.dart';

enum _Filter { all, completed, ongoing, cancelled }

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  bool _loading = true;
  List<TripRecord> _trips = const [];
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    setState(() => _loading = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Unable to load trips')),
      );
    }
  }

  List<TripRecord> get _filtered {
    switch (_filter) {
      case _Filter.completed: return _trips.where((t) => t.status == 'completed').toList();
      case _Filter.ongoing:   return _trips.where((t) => t.status == 'ongoing').toList();
      case _Filter.cancelled: return _trips.where((t) => t.status == 'cancelled' || t.status == 'canceled').toList();
      case _Filter.all:       return _trips;
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
            const SectionTitle(title: 'Your rides', subtitle: 'Tap any trip to see the full receipt.'),
            const SizedBox(height: 14),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _Filter.values.map((f) {
                  final active = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabel(f)),
                      selected: active,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: const Color(0xFF2F6BFF).withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: active ? const Color(0xFF69A8FF) : Colors.white54,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: active ? const Color(0xFF2F6BFF) : Colors.white12,
                      ),
                      backgroundColor: const Color(0xFF0E1422),
                      checkmarkColor: const Color(0xFF69A8FF),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator()))
            else if (_filtered.isEmpty)
              EmptyStateCard(
                title: _trips.isEmpty ? 'No trips yet' : 'No ${_filterLabel(_filter).toLowerCase()} trips',
                subtitle: _trips.isEmpty
                    ? 'Your completed rides will appear here once the first trip is closed.'
                    : 'Try a different filter.',
                icon: Icons.route_rounded,
              )
            else
              ..._filtered.map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TripCard(
                    trip: trip,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DriverReceiptScreen(trip: trip)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:       return 'All';
      case _Filter.completed: return 'Completed';
      case _Filter.ongoing:   return 'Ongoing';
      case _Filter.cancelled: return 'Cancelled';
    }
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final TripRecord trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        trip.customerName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trip.surgeBreakdown != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C7CFF).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6C7CFF).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF6C7CFF)),
                            const SizedBox(width: 2),
                            Text(
                              '${((trip.surgeBreakdown!['multiplier'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(2)}×',
                              style: const TextStyle(
                                color: Color(0xFF6C7CFF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              StatusPill(
                label: trip.status.toUpperCase(),
                color: trip.status == 'completed'
                    ? const Color(0xFF22C55E)
                    : (trip.status == 'cancelled' || trip.status == 'canceled')
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF69A8FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${trip.startAddress} → ${trip.endAddress}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
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
              Expanded(
                child: _Info(
                  label: 'Receipt',
                  value: trip.receiptNumber?.isNotEmpty == true ? trip.receiptNumber! : 'Tap to view',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
              const SizedBox(width: 2),
              const Text('View receipt', style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ],
      ),
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