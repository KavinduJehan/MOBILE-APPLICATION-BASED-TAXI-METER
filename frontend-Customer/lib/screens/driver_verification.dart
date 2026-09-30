import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'rate_comparison.dart';
import 'negotiate_screen.dart';
import 'ride_request_screen.dart';
import 'trip_offer_screen.dart';

class DriverVerificationScreen extends StatefulWidget {
  /// Full driver document returned by GET /api/drivers/qr/:qrToken or decoded from QR
  final Map<String, dynamic> driver;
  final bool offlineMode;

  const DriverVerificationScreen({
    super.key,
    required this.driver,
    this.offlineMode = false,
  });

  @override
  State<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  double? _customRate;

  double get _effectiveRate =>
      _customRate ??
      (widget.driver['ratePerKm'] as num?)?.toDouble() ??
      0.0;

  void _showOfferQrModal(BuildContext context, {required bool isOffline}) {
    final auth = context.read<AuthProvider>();
    final defaultName = auth.customer?.name ?? 'Passenger';
    final nameController = TextEditingController(text: defaultName);
    final rateController =
        TextEditingController(text: _effectiveRate.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isOffline ? 'Offline Trip Handshake' : 'Generate Trip Offer QR',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a QR code with your agreed rate. The driver scans it with their Driver App to start the meter.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
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
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.payments, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.qr_code),
                label: const Text(
                  'Display QR Code for Driver',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final enteredName = nameController.text.trim();
                  final enteredRate = double.tryParse(rateController.text.trim()) ?? _effectiveRate;

                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripOfferScreen(
                        driver: widget.driver,
                        customerName: enteredName.isNotEmpty ? enteredName : 'Passenger',
                        customerPhone: auth.customer?.phone,
                        agreedRatePerKm: enteredRate,
                        isOffline: isOffline,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final name = driver['name'] as String? ?? '—';
    final vehicleNumber = driver['vehicleNumber'] as String? ?? '—';
    final licenseNumber = driver['licenseNumber'] as String? ?? '—';
    final area = driver['area'] as String?;
    final displayArea = area ?? '—';
    final rate = _effectiveRate;
    final isVerified = driver['isVerified'] as bool? ?? false;
    final isOffline = widget.offlineMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOffline ? 'Driver Details (Offline)' : 'Driver Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOffline) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.amber, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No internet connection. Driver details loaded from QR payload. Generate a Trip Offer QR to start offline.',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const CircleAvatar(
                  radius: 35,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isOffline
                        ? const Color(0xFFFEF3C7)
                        : (isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOffline
                        ? 'Direct QR Handshake'
                        : (isVerified ? 'Verified Driver' : 'Unverified'),
                    style: TextStyle(
                      color: isOffline
                          ? Colors.orange.shade900
                          : (isVerified ? Colors.green : Colors.red),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 30),

                _infoRow(Icons.directions_car, 'Vehicle No', vehicleNumber),
                _infoRow(Icons.badge, 'License No', licenseNumber),
                _infoRow(Icons.location_on, 'Area', displayArea),
                _infoRow(
                  Icons.payments,
                  'Rate per km',
                  'Rs. ${rate.toStringAsFixed(0)} / km',
                ),

                const SizedBox(height: 20),

                if (!isOffline) ...[
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RateComparison(area: area, driverRate: rate),
                      ),
                    ),
                    child: const Text('Compare Rate'),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: isVerified
                        ? () async {
                            final suggestedRate = await Navigator.push<double>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NegotiateScreen(driver: driver),
                              ),
                            );
                            if (!context.mounted) return;
                            if (suggestedRate != null) {
                              setState(() => _customRate = suggestedRate);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RideRequestScreen(
                                    driver: driver,
                                    suggestedRatePerKm: suggestedRate,
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    child: const Text('Negotiate Rate (Online)'),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                    ),
                    onPressed: isVerified
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RideRequestScreen(
                                driver: driver,
                                suggestedRatePerKm: _customRate,
                              ),
                            ),
                          )
                        : null,
                    child: const Text('Start Online Ride'),
                  ),
                  const SizedBox(height: 10),
                ],

                // Offer QR Button (Available both offline and online for direct street hailing)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOffline ? Colors.green.shade700 : const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(
                    isOffline
                        ? 'Generate Trip Offer QR (Offline)'
                        : 'Generate Trip Offer QR (Direct Tuk Handoff)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showOfferQrModal(context, isOffline: isOffline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
