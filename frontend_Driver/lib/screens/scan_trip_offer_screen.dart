import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ridex_driver/offline/offline_trip.dart';
import 'package:provider/provider.dart';
import '../providers/active_trip_provider.dart';
import '../providers/auth_provider.dart';
import 'offline_trip_screen.dart';

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
  Map<String, dynamic>? _offer;

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

      final onlineTrip = context.read<ActiveTripProvider>().onlineTrip;
      if (onlineTrip != null) {
        throw 'Finish your current ride before starting an offline trip.';
      }
      final profile = context.read<AuthProvider>().profile;
      if (profile == null || profile.id.isEmpty || profile.qrToken.isEmpty) {
        throw 'Connect once to refresh your driver profile before using offline trips.';
      }
      if (data['version'] != 1 || data['driverToken'] != profile.qrToken) {
        throw 'This offer is not addressed to your driver QR. Ask the passenger to scan your current QR.';
      }
      final time = DateTime.tryParse(data['timestamp']?.toString() ?? '');
      if (time == null ||
          DateTime.now().difference(time).abs() > const Duration(minutes: 30)) {
        throw 'This offer has expired. Ask the passenger to generate a new one.';
      }
      final id = data['localId']?.toString() ?? '';
      if (!RegExp(r'^offline-[a-f0-9]{32}$').hasMatch(id)) {
        throw 'Invalid trip offer ID.';
      }
      if (data['destination'] != null &&
          (OfflineDestination.fromJson(data['destination']) == null ||
              !['car', 'tuk'].contains(data['navigationProfile']))) {
        throw 'Invalid offline destination or vehicle profile.';
      }
      final trips = await TripStore.all(profile.id);
      if (trips.any((trip) => trip.id == id)) {
        throw 'This offer has already been accepted. Open it in Offline Trips.';
      }
      if (trips.any((trip) => !trip.completed)) {
        throw 'Finish your current offline trip first.';
      }
      _offer = data;

      await _controller.stop();
      if (!mounted) return;

      final customerName = data['customerName'] as String? ?? 'Passenger';
      final customerPhone = data['customerPhone'] as String?;
      final agreedRate = (data['agreedRatePerKm'] as num?)?.toDouble() ?? 0.0;

      if (!agreedRate.isFinite || agreedRate <= 0) {
        throw 'Trip offer does not contain a valid rate.';
      }

      _showOfferConfirmation(
        customerName: customerName,
        customerPhone: customerPhone,
        agreedRate: agreedRate,
      );
    } catch (e) {
      if (!mounted) return;
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
      backgroundColor: OfflineUi.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const OfflineHeader(
                  icon: Icons.handshake_rounded,
                  title: 'Trip offer received',
                  subtitle: 'Check the details, then accept to start the meter.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OfflineUi.stroke),
                  ),
                  child: Column(
                    children: [
                      OfflineInfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Passenger',
                        value: customerName,
                      ),
                      if (_offer?['destination'] is Map)
                        OfflineInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Destination',
                          value: (_offer!['destination'] as Map)['name']
                              .toString(),
                        ),
                      if (customerPhone != null && customerPhone.isNotEmpty)
                        OfflineInfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Contact',
                          value: customerPhone,
                        ),
                      OfflineInfoRow(
                        icon: Icons.payments_outlined,
                        label: 'Agreed rate',
                        value: 'Rs. ${agreedRate.toStringAsFixed(0)} / km',
                        highlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: OfflineUi.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () async {
                    Navigator.pop(bottomSheetContext);
                    await _startOfflineTrip(
                      customerName: customerName,
                      agreedRate: agreedRate,
                    );
                  },
                  label: const Text(
                    'Accept & start trip',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    setState(() => _processing = false);
                    _controller.start();
                  },
                  child: const Text(
                    'Not now — scan again',
                    style: TextStyle(color: OfflineUi.muted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startOfflineTrip({
    required String customerName,
    required double agreedRate,
  }) async {
    try {
      final profile = context.read<AuthProvider>().profile!;
      final offer = _offer!;
      final trip = TripSession({
        'version': 1,
        'localId': offer['localId'],
        'driverId': profile.id,
        'driverToken': profile.qrToken,
        'driverName': profile.name,
        'vehicleNumber': profile.vehicleNumber,
        'customerName': customerName,
        'customerId': offer['customerId'],
        'customerIdentity': offer['customerIdentity'],
        'ratePerKm': agreedRate,
        'distanceKm': 0.0,
        'status': 'ongoing',
        'startTime': DateTime.now().toUtc().toIso8601String(),
        'offerTimestamp': offer['timestamp'],
        if (offer['destination'] != null) 'destination': offer['destination'],
        // Retain a legacy wire value so a saved offer can still be confirmed.
        // Navigation itself always uses car access in the shared package.
        'navigationProfile': offer['navigationProfile'] ?? 'car',
      });
      await TripStore.save(profile.id, trip);
      if (!mounted) return;
      await showTripQr(
        context,
        'Passenger trip confirmation',
        trip.qr('TRIP_ACCEPTED'),
        hint: 'Ask the passenger to scan this to start their trip.',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DriverOfflineTripScreen(trip: trip, owner: profile.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not start trip: $e';
          _processing = false;
        });
      }
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Scan passenger offer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) => IconButton(
              tooltip: 'Torch',
              onPressed: _controller.toggleTorch,
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          OfflineScannerOverlay(
            hint: 'Align the passenger’s QR inside the frame',
            busy: _processing && _error == null,
            hasError: _error != null,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
              child: Column(
                children: [
                  const OfflineNotice(
                    'No internet needed. Scan the offer QR on the passenger’s phone to lock in the agreed fare.',
                    icon: Icons.offline_bolt_rounded,
                  ),
                  const Spacer(),
                  if (_error != null)
                    OfflineNotice(
                      _error!,
                      tone: OfflineTone.danger,
                      action: 'Dismiss',
                      onAction: () => setState(() => _error = null),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
