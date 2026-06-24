// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/driver_model.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import 'nearby_drivers_screen.dart';
import 'qr_scan.dart';
import 'ride_request_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = auth.customer?.name ?? 'Guest';
    final promoWidth = MediaQuery.of(context).size.width - 48;
    final promoHeight = (promoWidth * 9 / 16).clamp(168.0, 220.0).toDouble();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hello, $displayName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const RideXLogo(size: 58, textSize: 18),
                  ],
                ),
                const SizedBox(height: 24),

                // Where are you going search bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333336)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppTheme.primaryBlue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final destination = await showModalBottomSheet<String>(
                              context: context,
                              builder: (context) => const _SearchDestinationSheet(),
                              backgroundColor: const Color(0xFF0A0A0A),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                            );
                            if (!context.mounted || destination == null) return;
                            final driver = await Navigator.push<DriverModel>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NearbyDriversScreen(
                                  area: destination,
                                  returnSelection: true,
                                ),
                              ),
                            );
                            if (!context.mounted || driver == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RideRequestScreen(
                                  driver: driver.toLegacyMap(),
                                  initialDestination: destination,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Where are you going?',
                            style: TextStyle(
                              color: Color(0xFF8A8A8A),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: promoHeight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: promoWidth,
                            child: _AdBanner(
                              imagePath: 'assets/ads/fare_calculator.png',
                              semanticLabel: 'Fare calculator advertisement',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NearbyDriversScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: promoWidth,
                            child: _AdBanner(
                              imagePath: 'assets/ads/easy_trip_tracking.png',
                              semanticLabel: 'Easy trip tracking advertisement',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NearbyDriversScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: promoWidth,
                          child: _AdBanner(
                            imagePath: 'assets/ads/driver_earnings.png',
                            semanticLabel: 'Driver earnings advertisement',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NearbyDriversScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: const [
                    Expanded(
                      child: _MiniOffer(
                        icon: Icons.verified_user_outlined,
                        label: 'Verified drivers',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _MiniOffer(
                        icon: Icons.payments_outlined,
                        label: 'Clear fare rates',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Quick actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                // Scan QR button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QRScan()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, color: AppTheme.primaryBlue, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Scan Driver QR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Quick ride with verified driver',
                                style: TextStyle(
                                  color: Color(0xFF8A8A8A),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Color(0xFF666666), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NearbyDriversScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333336)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppTheme.primaryBlue, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Find Nearby Drivers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Browse available drivers around you',
                                style: TextStyle(
                                  color: Color(0xFF8A8A8A),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Color(0xFF666666), size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdBanner extends StatelessWidget {
  final String imagePath;
  final String semanticLabel;
  final VoidCallback onTap;

  const _AdBanner({
    super.key,
    required this.imagePath,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.expand(
          child: Image.asset(
            imagePath,
            semanticLabel: semanticLabel,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppTheme.surface,
                alignment: Alignment.center,
                child: Text(
                  semanticLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniOffer extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniOffer({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333336)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchDestinationSheet extends StatefulWidget {
  const _SearchDestinationSheet({super.key});

  @override
  State<_SearchDestinationSheet> createState() => _SearchDestinationSheetState();
}

class _SearchDestinationSheetState extends State<_SearchDestinationSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Where are you going?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter destination',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333336)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryBlue),
              ),
              prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _controller.text.trim().isNotEmpty
                ? () => Navigator.pop(context, _controller.text.trim())
                : null,
            child: const Text(
              'Continue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
