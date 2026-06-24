import 'package:flutter/material.dart';

import '../models/receipt_model.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../theme.dart';
import 'main_navigation.dart';

class ReceiptScreen extends StatefulWidget {
  final TripModel trip;
  final ReceiptModel? initialReceipt;

  const ReceiptScreen({
    super.key,
    required this.trip,
    this.initialReceipt,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _repository = const TripRepository();
  late Future<ReceiptModel> _receiptFuture;

  @override
  void initState() {
    super.initState();
    _receiptFuture = _loadReceipt();
  }

  Future<ReceiptModel> _loadReceipt() async {
    if (widget.initialReceipt != null) return widget.initialReceipt!;
    try {
      return await _repository.getReceiptByTripId(widget.trip.id);
    } catch (_) {
      return ReceiptModel.fromTrip(widget.trip);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Receipt')),
      body: FutureBuilder<ReceiptModel>(
        future: _receiptFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(
              onRetry: () {
                setState(() => _receiptFuture = _loadReceipt());
              },
            );
          }

          final receipt = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 60),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Trip Completed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _receiptRow('Receipt No', receipt.receiptNumber),
              _receiptRow('Trip ID', receipt.tripId),
              _receiptRow('Driver', receipt.driverName),
              _receiptRow('Vehicle', receipt.vehicleNumber),
              _receiptRow('Pickup', receipt.pickupLocation),
              _receiptRow('Drop', receipt.dropLocation),
              _receiptRow('Distance', '${receipt.distanceKm.toStringAsFixed(1)} km'),
              _receiptRow(
                'Duration',
                receipt.durationMinutes == 0
                    ? '-'
                    : '${receipt.durationMinutes.toStringAsFixed(0)} min',
              ),
              _receiptRow('Base fare', _money(receipt.baseFare)),
              _receiptRow('Additional charges', _money(receipt.additionalCharges)),
              _receiptRow('Payment method', receipt.paymentMethod),
              _receiptRow('Date/time', _formatDate(receipt.issuedAt)),
              const Divider(color: Color(0xFF333336)),
              _receiptRow('Total fare', _money(receipt.totalFare), bold: true),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainNavigation()),
                  (_) => false,
                ),
                child: const Text('Back to Home'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF222222))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF))),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _money(double value) => 'Rs. ${value.toStringAsFixed(2)}';

  static String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

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
            const Text(
              'Failed to load receipt',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
