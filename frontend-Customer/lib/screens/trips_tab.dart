import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../theme.dart';
import 'main_navigation.dart';
import 'receipt.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().load(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 280) {
      context.read<TripProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Consumer<TripProvider>(
          builder: (context, provider, _) {
            if (provider.loading && provider.trips.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              );
            }

            if (provider.error != null && provider.trips.isEmpty) {
              return _TripsError(
                message: provider.error!,
                onRetry: () => provider.load(refresh: true),
              );
            }

            if (provider.trips.isEmpty) {
              return const _NoTripsState();
            }

            return RefreshIndicator(
              onRefresh: () => provider.load(refresh: true),
              color: AppTheme.primaryBlue,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: provider.trips.length + (provider.loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= provider.trips.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                      ),
                    );
                  }
                  return _TripCard(trip: provider.trips[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (trip.status) {
      'completed' => AppTheme.successGreen,
      'cancelled' => AppTheme.dangerRed,
      'ongoing' => Colors.orangeAccent,
      _ => const Color(0xFF9CA3AF),
    };

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptScreen(trip: trip),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333336)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.driverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(trip.startTime ?? trip.createdAt),
                        style: const TextStyle(color: Color(0xFF8A8A8A)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    trip.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${trip.pickupLocation} -> ${trip.dropLocation}',
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${trip.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(color: Color(0xFF8A8A8A)),
                ),
                Text(
                  'Rs. ${trip.totalFare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final date = value.toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _NoTripsState extends StatelessWidget {
  const _NoTripsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.route_outlined, color: Color(0xFF666666), size: 72),
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
              style: TextStyle(color: Color(0xFF8A8A8A)),
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
}

class _TripsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _TripsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
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
}
