import 'package:flutter/material.dart';
import 'rate_comparison.dart';
import 'negotiate_screen.dart';
import 'ride_request_screen.dart';

class DriverVerificationScreen extends StatelessWidget {
  /// Full driver document returned by GET /api/drivers/qr/:qrToken
  final Map<String, dynamic> driver;

  const DriverVerificationScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final name = driver['name'] as String? ?? '—';
    final vehicleNumber = driver['vehicleNumber'] as String? ?? '—';
    final licenseNumber = driver['licenseNumber'] as String? ?? '—';
    final area = driver['area'] as String?;
    final displayArea = area ?? '—';
    final rate = (driver['ratePerKm'] as num?)?.toDouble() ?? 0.0;
    final isVerified = driver['isVerified'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Details')),
      body: Padding(
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
                    color: isVerified
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isVerified ? 'Verified Driver' : 'Unverified',
                    style: TextStyle(
                      color: isVerified ? Colors.green : Colors.red,
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

                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RateComparison(area: area, driverRate: rate),
                    ),
                  ),
                  child: const Text('Compare Rate'),
                ),
                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: isVerified
                      ? () async {
                          // NegotiateScreen returns the suggested rate the user entered
                          final suggestedRate = await Navigator.push<double>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NegotiateScreen(driver: driver),
                            ),
                          );
                          if (!context.mounted) return;
                          if (suggestedRate != null) {
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
                  child: const Text('Negotiate Rate'),
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
                            builder: (_) => RideRequestScreen(driver: driver),
                          ),
                        )
                      : null,
                  child: const Text('Start Ride'),
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
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
