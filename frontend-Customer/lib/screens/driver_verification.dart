import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'rate_comparison.dart';
import 'negotiate_screen.dart';
import 'ride_request_screen.dart';
import 'package:customer_app/offline/offline_trip.dart' show OfflineUi, OfflinePanel, OfflineNotice, OfflineTone;
import 'offline_trip_offer_screen.dart';

class DriverVerificationScreen extends StatefulWidget {
  /// Full driver document returned by GET /api/drivers/qr/:qrToken or decoded from QR
  final Map<String, dynamic> driver;
  final bool offlineMode;

  /// Whether the phone can actually reach the server (checked by the caller).
  final bool hasInternet;

  const DriverVerificationScreen({
    super.key,
    required this.driver,
    this.offlineMode = false,
    this.hasInternet = false,
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
                  if (!enteredRate.isFinite || enteredRate <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a positive agreed rate.')));
                    return;
                  }

                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OfflineTripOfferScreen(
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
    final rate = _effectiveRate;
    final isVerified = driver['isVerified'] as bool? ?? false;
    final isOffline = widget.offlineMode;
    final primary = Theme.of(context).colorScheme.primary;

    final badgeColor = isOffline
        ? OfflineUi.warning
        : (isVerified ? OfflineUi.success : OfflineUi.danger);
    final badgeIcon = isOffline
        ? Icons.handshake_rounded
        : (isVerified ? Icons.verified_rounded : Icons.error_outline_rounded);
    final badgeText = isOffline
        ? 'Direct QR Handshake'
        : (isVerified ? 'Verified Driver' : 'Unverified');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOffline && !widget.hasInternet
              ? 'Driver Details (Offline)'
              : 'Driver Details',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOffline) ...[
                widget.hasInternet
                    ? const OfflineNotice(
                        'Offline trip mode. Driver details were read from their QR. Generate a Trip Offer QR to start.',
                        icon: Icons.offline_bolt_rounded,
                      )
                    : const OfflineNotice(
                        'No internet connection. Driver details loaded from QR payload. Generate a Trip Offer QR to start offline.',
                        tone: OfflineTone.warning,
                        icon: Icons.cloud_off_rounded,
                      ),
                const SizedBox(height: 14),
              ],
              OfflinePanel(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primary, OfflineUi.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.4),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 16, color: badgeColor),
                          const SizedBox(width: 6),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _infoRow(
                      Icons.directions_car_rounded,
                      'Vehicle No',
                      vehicleNumber,
                      const Color(0xFF60A5FA),
                    ),
                    _infoRow(
                      Icons.badge_rounded,
                      'License No',
                      licenseNumber,
                      const Color(0xFFA78BFA),
                    ),
                    _infoRow(
                      Icons.payments_rounded,
                      'Rate per km',
                      'Rs. ${rate.toStringAsFixed(0)} / km',
                      OfflineUi.success,
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!isOffline) ...[
                _action(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Compare Rate',
                  tonal: true,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RateComparison(area: area, driverRate: rate),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _action(
                  icon: Icons.handshake_outlined,
                  label: 'Negotiate Rate (Online)',
                  tonal: true,
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
                ),
                const SizedBox(height: 10),
                _action(
                  icon: Icons.local_taxi_rounded,
                  label: 'Start Online Ride',
                  color: OfflineUi.success,
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
                ),
                const SizedBox(height: 10),
              ],
              // Available offline and online for direct street hailing.
              _action(
                icon: Icons.qr_code_2_rounded,
                label: isOffline
                    ? 'Generate Trip Offer QR (Offline)'
                    : 'Generate Trip Offer QR (Direct Tuk Handoff)',
                color: isOffline ? OfflineUi.success : primary,
                onPressed: () => _showOfferQrModal(context, isOffline: isOffline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
    bool tonal = false,
  }) {
    final style = (tonal ? FilledButton.styleFrom() : FilledButton.styleFrom(backgroundColor: color))
        .copyWith(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(54)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
    final child = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    return tonal
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: child,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: child,
          );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: OfflineUi.muted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: highlight ? 17 : 15,
                color: highlight ? const Color(0xFF4ADE80) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
