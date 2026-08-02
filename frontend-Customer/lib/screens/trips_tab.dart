import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../theme.dart';
import 'main_navigation.dart';
import 'receipt.dart';

enum _TripFilter { completed, pending, ongoing, canceled }

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  final _scrollController = ScrollController();
  _TripFilter _filter = _TripFilter.completed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().load(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 280) {
      context.read<TripProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _FilterBar(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
            ),
            Expanded(child: _tripList()),
          ],
        ),
      ),
    );
  }

  Widget _tripList() => Consumer<TripProvider>(
    builder: (context, provider, _) {
      final pendingSearch = _filter == _TripFilter.pending
          ? provider.pendingSearch
          : null;
      if (provider.loading && provider.trips.isEmpty && pendingSearch == null) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        );
      }
      if (provider.error != null &&
          provider.trips.isEmpty &&
          pendingSearch == null) {
        return _TripsError(
          message: provider.error!,
          onRetry: () => provider.load(refresh: true),
        );
      }
      final trips = provider.trips.where(_matchesFilter).toList()
        ..sort((a, b) => _tripDate(b).compareTo(_tripDate(a)));
      if (provider.trips.isEmpty &&
          pendingSearch == null &&
          _filter == _TripFilter.completed) {
        return const _NoTripsState();
      }
      return RefreshIndicator(
        onRefresh: () => provider.load(refresh: true),
        color: AppTheme.primaryBlue,
        backgroundColor: AppTheme.surface,
        child: trips.isEmpty && pendingSearch == null
            ? _EmptyFilterState(filter: _filter)
            : ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  if (pendingSearch != null) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 10),
                      child: Text(
                        'Driver search',
                        style: TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _PendingSearchCard(
                      search: pendingSearch,
                      onCancel: () => _confirmCancelPending(context, provider),
                    ),
                  ],
                  for (final group in _groupTrips(trips)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Text(
                        _formatDay(group.date),
                        style: const TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final trip in group.trips)
                      _TripCard(
                        trip: trip,
                        onCancel:
                            trip.status.toLowerCase() == 'ongoing' ||
                                trip.status.toLowerCase() == 'pending'
                            ? () => _confirmCancelTrip(context, provider, trip)
                            : null,
                      ),
                  ],
                  if (provider.loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                ],
              ),
      );
    },
  );

  bool _matchesFilter(TripModel trip) {
    final status = trip.status.toLowerCase();
    return switch (_filter) {
      _TripFilter.completed => status == 'completed',
      _TripFilter.pending => status == 'pending',
      _TripFilter.ongoing => status == 'ongoing',
      _TripFilter.canceled => status == 'cancelled' || status == 'canceled',
    };
  }

  Future<void> _confirmCancelPending(
    BuildContext context,
    TripProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cancel driver search?'),
        content: const Text(
          'RideX will stop showing this request as pending.',
          style: TextStyle(color: AppTheme.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Searching'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Cancel Ride',
              style: TextStyle(color: AppTheme.dangerRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.clearPendingSearch();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pending ride canceled')));
  }

  Future<void> _confirmCancelTrip(
    BuildContext context,
    TripProvider provider,
    TripModel trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cancel this trip?'),
        content: Text(
          [trip.pickupLocation, 'to', trip.dropLocation].join(' '),
          style: const TextStyle(color: AppTheme.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Trip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Cancel Ride',
              style: TextStyle(color: AppTheme.dangerRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final canceled = await provider.cancelTrip(trip.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          canceled
              ? 'Trip canceled'
              : provider.error ?? 'Could not cancel trip',
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTheme.border)),
    ),
    child: const Text(
      'My Trips',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final _TripFilter selected;
  final ValueChanged<_TripFilter> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      children: [
        _FilterButton(
          label: 'Completed',
          selected: selected == _TripFilter.completed,
          onTap: () => onSelected(_TripFilter.completed),
        ),
        _FilterButton(
          label: 'Pending',
          selected: selected == _TripFilter.pending,
          onTap: () => onSelected(_TripFilter.pending),
        ),
        _FilterButton(
          label: 'Ongoing',
          selected: selected == _TripFilter.ongoing,
          onTap: () => onSelected(_TripFilter.ongoing),
        ),
        _FilterButton(
          label: 'Canceled',
          selected: selected == _TripFilter.canceled,
          onTap: () => onSelected(_TripFilter.canceled),
        ),
      ],
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.mutedText,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _PendingSearchCard extends StatelessWidget {
  const _PendingSearchCard({required this.search, required this.onCancel});

  final PendingRideSearch search;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finding a driver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Searching near your pickup location',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _LocationRow(
            color: AppTheme.actionBlue,
            location: search.pickupAddress,
            time: _formatTime(search.createdAt),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4.5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 1, height: 12, color: AppTheme.border),
            ),
          ),
          _LocationRow(
            color: AppTheme.accent,
            location: search.destinationAddress,
            time: '--:--',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.dangerRed,
              side: const BorderSide(color: AppTheme.dangerRed),
              minimumSize: const Size(double.infinity, 46),
            ),
            icon: const Icon(Icons.close_rounded, size: 19),
            label: const Text('CANCEL RIDE'),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, this.onCancel});
  final TripModel trip;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(trip: trip)),
      ),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.16),
                  child: Text(
                    _initials(trip.driverName),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${trip.driver?.vehicleType ?? 'Taxi'}  •  ${trip.vehicleNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppTheme.warningOrange,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            (trip.driver?.rating ?? 0).toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppTheme.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LKR ${trip.totalFare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _LocationRow(
              color: AppTheme.successGreen,
              location: trip.pickupLocation,
              time: _formatTime(trip.startTime ?? trip.createdAt),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 1, height: 10, color: AppTheme.border),
              ),
            ),
            _LocationRow(
              color: AppTheme.primary,
              location: trip.dropLocation,
              time: _formatTime(trip.endTime),
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dangerRed,
                  side: const BorderSide(color: AppTheme.dangerRed),
                  minimumSize: const Size(double.infinity, 46),
                ),
                icon: const Icon(Icons.close_rounded, size: 19),
                label: const Text('CANCEL RIDE'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'D';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.color,
    required this.location,
    required this.time,
  });
  final Color color;
  final String location;
  final String time;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          location.isEmpty ? 'Location unavailable' : location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        time,
        style: const TextStyle(color: AppTheme.mutedText, fontSize: 10),
      ),
    ],
  );
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.filter});
  final _TripFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _TripFilter.completed => 'completed',
      _TripFilter.pending => 'pending',
      _TripFilter.ongoing => 'ongoing',
      _TripFilter.canceled => 'canceled',
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 90),
        const Icon(Icons.route_outlined, color: AppTheme.mutedText, size: 64),
        const SizedBox(height: 14),
        Text(
          'No $label trips',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pull down to refresh your trip history.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.mutedText),
        ),
      ],
    );
  }
}

class _NoTripsState extends StatelessWidget {
  const _NoTripsState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.route_outlined, color: AppTheme.mutedText, size: 72),
          const SizedBox(height: 14),
          const Text(
            'No trips yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book a ride to see your trip history here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedText),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigation()),
                (_) => false,
              );
            },
            child: const Text('Book Ride'),
          ),
        ],
      ),
    ),
  );
}

class _TripsError extends StatelessWidget {
  const _TripsError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 56),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => onRetry(),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _TripGroup {
  const _TripGroup(this.date, this.trips);
  final DateTime date;
  final List<TripModel> trips;
}

List<_TripGroup> _groupTrips(List<TripModel> trips) {
  final groups = <String, _TripGroup>{};
  for (final trip in trips) {
    final date = _tripDate(trip).toLocal();
    final day = DateTime(date.year, date.month, date.day);
    final key = '${day.year}-${day.month}-${day.day}';
    final group = groups[key];
    if (group == null) {
      groups[key] = _TripGroup(day, [trip]);
    } else {
      group.trips.add(trip);
    }
  }
  return groups.values.toList();
}

DateTime _tripDate(TripModel trip) =>
    trip.startTime ?? trip.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

String _formatDay(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String _formatTime(DateTime? value) {
  if (value == null) return '--:--';
  final date = value.toLocal();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:$minute $period';
}
