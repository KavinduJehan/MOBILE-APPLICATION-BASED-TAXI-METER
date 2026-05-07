import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'active_trip_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.request});

  final RideRequest request;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _acceptSuggestedRate = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final auth = context.watch<AuthProvider>();
    final suggestedRate = request.suggestedRatePerKm;
    final estimatedFareAtDriverRate = request.fareAt(request.driverRatePerKm);
    final estimatedFareAtSuggestedRate = suggestedRate == null ? null : request.fareAt(suggestedRate);
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Request Details')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.customerName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  InfoRow(label: 'Pickup', value: request.pickupAddress),
                  InfoRow(label: 'Destination', value: request.destinationAddress),
                  InfoRow(label: 'Distance', value: '${request.estimatedDistanceKm.toStringAsFixed(1)} km'),
                  InfoRow(label: 'Your rate', value: 'Rs. ${request.driverRatePerKm.toStringAsFixed(2)} / km'),
                  if (suggestedRate != null)
                    InfoRow(label: 'Suggested rate', value: 'Rs. ${suggestedRate.toStringAsFixed(2)} / km'),
                  InfoRow(label: 'Fare at your rate', value: 'Rs. ${estimatedFareAtDriverRate.toStringAsFixed(2)}'),
                  if (estimatedFareAtSuggestedRate != null)
                    InfoRow(label: 'Fare at suggested rate', value: 'Rs. ${estimatedFareAtSuggestedRate.toStringAsFixed(2)}'),
                  if (suggestedRate != null) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _acceptSuggestedRate,
                      onChanged: (value) => setState(() => _acceptSuggestedRate = value ?? false),
                      title: const Text('Agree to suggested rate'),
                      subtitle: const Text('Include the customer suggested rate when you accept this request.'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'Accept',
              isBusy: auth.busy,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                try {
                  final response = await auth.api.respondToRequest(
                    requestId: request.id,
                    action: 'accept',
                    agreedRatePerKm: _acceptSuggestedRate ? suggestedRate : null,
                  );
                  final trip = TripRecord.fromJson(_readTrip(response));
                  if (!mounted) return;
                  navigator.pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ActiveTripScreen(
                        trip: trip,
                        receiptNumber: _readReceipt(response),
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Unable to accept request')));
                }
              },
            ),
            const SizedBox(height: 12),
            SecondaryActionButton(
              label: 'Reject',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                try {
                  await auth.api.respondToRequest(requestId: request.id, action: 'reject');
                  if (!mounted) return;
                  navigator.pop();
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Unable to reject request')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _readTrip(Map<String, dynamic> response) {
    final trip = response['trip'];
    if (trip is Map<String, dynamic>) return trip;
    if (trip is Map) return Map<String, dynamic>.from(trip);
    return response;
  }

  String? _readReceipt(Map<String, dynamic> response) {
    final receipt = response['receipt'];
    if (receipt is String && receipt.isNotEmpty) return receipt;
    final receiptNumber = response['receiptNumber'];
    if (receiptNumber is String && receiptNumber.isNotEmpty) return receiptNumber;
    if (receiptNumber != null) return receiptNumber.toString();
    return null;
  }
}