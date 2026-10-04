import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/trip_record.dart';
import '../services/offline_database.dart';
import 'active_trip_screen.dart';

/// Screen where the driver scans a customer's Trip Offer QR code.
/// Allows direct street hailing and offline ride negotiation with zero internet needed.
class ScanTripOfferScreen extends StatefulWidget {
  const ScanTripOfferScreen({super.key});

  @override
  State<ScanTripOfferScreen> createState() => _ScanTripOfferScreenState();
}

class _ScanTripOfferScreenState extends State<ScanTripOfferScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;

      if (data['type'] != 'TRIP_OFFER') {
        throw 'Invalid QR code. Please scan a Passenger Trip Offer QR.';
      }

      await _controller.stop();
      if (!mounted) return;

      final customerName = data['customerName'] as String? ?? 'Passenger';
      final customerPhone = data['customerPhone'] as String?;
      final agreedRate = (data['agreedRatePerKm'] as num?)?.toDouble() ?? 0.0;

      if (agreedRate <= 0) {
        throw 'Trip offer does not contain a valid rate.';
      }

      _showOfferConfirmation(
        customerName: customerName,
        customerPhone: customerPhone,
        agreedRate: agreedRate,
      );
    } catch (e) {
      setState(() {
        _error = e is String ? e : 'Failed to parse Trip Offer QR.';
        _processing = false;
      });
      await _controller.start();
    }
  }

  void _showOfferConfirmation({
    required String customerName,
    String? customerPhone,
    required double agreedRate,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF0E1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Offer Received',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Offline handshake detected',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Offer details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _infoRow('Passenger', customerName, icon: Icons.person),
                    if (customerPhone != null && customerPhone.isNotEmpty) ...[
                      const Divider(color: Colors.white10, height: 18),
                      _infoRow('Contact', customerPhone, icon: Icons.phone),
                    ],
                    const Divider(color: Colors.white10, height: 18),
                    _infoRow(
                      'Agreed Rate',
                      'Rs. ${agreedRate.toStringAsFixed(0)} / km',
                      icon: Icons.payments,
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  Navigator.pop(bottomSheetContext);
                  await _startOfflineTrip(
                    customerName: customerName,
                    agreedRate: agreedRate,
                  );
                },
                child: const Text(
                  'Accept & Start Trip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  setState(() => _processing = false);
                  _controller.start();
                },
                child: const Text('Decline / Cancel', style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startOfflineTrip({
    required String customerName,
    required double agreedRate,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final localId = 'offline-$timestamp';
    final offlineReceipt = 'REC-OFFLINE-${timestamp.toRadixString(36).toUpperCase()}';

    final trip = TripRecord(
      id: localId,
      customerName: customerName,
      startAddress: 'Street Pickup',
      endAddress: 'Meter Destination',
      distanceKm: 0.0,
      ratePerKm: agreedRate,
      fare: 0.0,
      status: 'in_progress',
      date: DateTime.now(),
      receiptNumber: offlineReceipt,
    );

    // Save initial record to local SQLite
    await OfflineDatabase.instance.insertOfflineTrip(
      localId: localId,
      customerName: trip.customerName,
      startAddress: trip.startAddress,
      endAddress: trip.endAddress,
      distanceKm: trip.distanceKm,
      ratePerKm: trip.ratePerKm,
      fare: trip.fare,
      receiptNumber: offlineReceipt,
      status: 'in_progress',
      date: trip.date,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(
          trip: trip,
          receiptNumber: offlineReceipt,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {IconData? icon, bool highlight = false}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Colors.white60),
          const SizedBox(width: 8),
        ],
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFF4ADE80) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: highlight ? 16 : 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Passenger Offer QR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scanner Framing reticle
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF22C55E), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // Top Info Card
          Positioned(
            top: 20,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.offline_bolt_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline Capable: Scan the QR generated on the passenger\'s phone to lock agreed fare.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Prompt
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_processing && _error == null)
                  const CircularProgressIndicator(color: Color(0xFF22C55E)),
                if (_error != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_processing) ...[
                  const Text(
                    'Align passenger QR inside the frame',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Enter Agreed Rate Manually', style: TextStyle(fontSize: 13)),
                    onPressed: _showManualOfferModal,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualOfferModal() {
    final nameController = TextEditingController(text: 'Passenger');
    final rateController = TextEditingController(text: '100');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Manual Street Meter',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Start live digital taxi meter with negotiated or standard rate.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Passenger Name (Optional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF161F33),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Agreed Rate per km (Rs.)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF161F33),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.payments, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.speed_rounded),
                label: const Text('Start Meter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final name = nameController.text.trim();
                  final rate = double.tryParse(rateController.text.trim()) ?? 100.0;
                  Navigator.pop(bottomSheetContext);
                  _startOfflineTrip(
                    customerName: name.isNotEmpty ? name : 'Passenger',
                    agreedRate: rate > 0 ? rate : 100.0,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
