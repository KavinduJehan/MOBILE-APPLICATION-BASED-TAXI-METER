import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../theme.dart';
import 'receipt.dart';

class ReceiptsTab extends StatefulWidget {
  const ReceiptsTab({super.key});

  @override
  State<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends State<ReceiptsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().load(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Consumer<TripProvider>(
          builder: (context, provider, _) {
            final completed = provider.trips
                .where((trip) => trip.status == 'completed')
                .toList();

            if (provider.loading && completed.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              );
            }

            if (completed.isEmpty) {
              return const Center(
                child: Text(
                  'No receipts yet',
                  style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 16),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => provider.load(refresh: true),
              color: AppTheme.primaryBlue,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: completed.length,
                itemBuilder: (context, index) {
                  final trip = completed[index];
                  return Container(
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
                              child: Text(
                                '${trip.pickupLocation} -> ${trip.dropLocation}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                        const SizedBox(height: 8),
                        Text(
                          '${trip.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(color: Color(0xFF8A8A8A)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.receipt_long, size: 18),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReceiptScreen(trip: trip),
                                ),
                              );
                            },
                            label: const Text('View Receipt'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
