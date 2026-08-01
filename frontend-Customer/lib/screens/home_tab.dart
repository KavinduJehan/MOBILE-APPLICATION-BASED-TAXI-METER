import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/driver_model.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/brand_logo.dart';
import 'location_picker_screen.dart';
import 'nearby_drivers_screen.dart';
import 'qr_scan.dart';
import 'ride_request_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _startBooking(BuildContext context) async {
    final selection = await Navigator.push<LocationSelectionResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (!context.mounted || selection == null) return;

    final driver = await Navigator.push<DriverModel>(
      context,
      MaterialPageRoute(
        builder: (_) => NearbyDriversScreen(
          pickupLat: selection.pickupLat,
          pickupLng: selection.pickupLng,
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
          initialPickup: selection.pickupAddress,
          initialPickupLat: selection.pickupLat,
          initialPickupLng: selection.pickupLng,
          initialDestination: selection.destinationAddress,
          initialDestinationLat: selection.destinationLat,
          initialDestinationLng: selection.destinationLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = auth.customer?.name ?? 'Guest';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good day, $displayName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Book a metered ride with a verified driver.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const RideXLogo(size: 44, textSize: 14),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _OfferTicket(onTap: () => _startBooking(context)),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              button: true,
              label: 'Choose pickup and destination',
              child: AppCard(
                onTap: () => _startBooking(context),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Where to?',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Set pickup and drop-off on the map',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.mutedText),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.mutedText),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Today',
                    subtitle: 'Useful ride tools',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ActionRow(
                    title: 'Scan driver QR',
                    subtitle: 'Start with a verified taxi meter',
                    icon: Icons.qr_code_scanner,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QRScan()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _ActionRow(
                    title: 'Find nearby drivers',
                    subtitle: 'Browse available drivers around you',
                    icon: Icons.local_taxi_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NearbyDriversScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: 'Why RideX',
              subtitle: 'Clear fares and verified drivers before every trip.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _TrustList(),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppTheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTheme.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustList extends StatelessWidget {
  const _TrustList();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: const [
          _TrustRow(
            title: 'Verified drivers',
            subtitle: 'Driver details are checked before they appear.',
          ),
          Divider(height: 24),
          _TrustRow(
            title: 'Transparent estimates',
            subtitle: 'Distance and fare are shown before sending a request.',
          ),
          Divider(height: 24),
          _TrustRow(
            title: 'Request status',
            subtitle: 'You can see when the driver accepts or declines.',
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: AppTheme.successGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferTicket extends StatelessWidget {
  const _OfferTicket({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Limited offer: 20 percent off your next ride. Use code RIDEX20.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A2233), Color(0xFF111722)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: _TicketGridPainter()),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.local_taxi_rounded,
                                      color: AppTheme.accent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'RIDEX REWARDS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppTheme.accent,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Text(
                                      'LIMITED OFFER',
                                      style: TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                '20% OFF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 7),
                              const Text(
                                'Your next metered ride is on us — almost.',
                                style: TextStyle(
                                  color: AppTheme.mutedText,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Row(
                                children: [
                                  Expanded(
                                    child: _OfferDetail(
                                      label: 'PROMO CODE',
                                      value: 'RIDEX20',
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: _OfferDetail(
                                      label: 'SAVE UP TO',
                                      value: 'Rs. 500',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _TicketPerforation(),
                  Container(
                    color: AppTheme.surfaceAlt,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 88,
                          height: 34,
                          child: CustomPaint(painter: _BarcodePainter()),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'ONE RIDE\nPER ACCOUNT',
                            style: TextStyle(
                              color: AppTheme.mutedText,
                              fontSize: 9,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'BOOK NOW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferDetail extends StatelessWidget {
  const _OfferDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.mutedText,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TicketPerforation extends StatelessWidget {
  const _TicketPerforation();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      color: AppTheme.surfaceAlt,
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-9, 0),
            child: const CircleAvatar(
              radius: 9,
              backgroundColor: AppTheme.background,
            ),
          ),
          const Expanded(
            child: SizedBox(
              height: 2,
              child: CustomPaint(painter: _DashedLinePainter()),
            ),
          ),
          Transform.translate(
            offset: const Offset(9, 0),
            child: const CircleAvatar(
              radius: 9,
              backgroundColor: AppTheme.background,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketGridPainter extends CustomPainter {
  const _TicketGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    const spacing = 24.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.5;
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (double x = 0; x < size.width; x += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  static const _bars = <double>[
    2,
    1,
    3,
    1,
    2,
    4,
    1,
    3,
    2,
    1,
    4,
    2,
    1,
    3,
    1,
    2,
    3,
    1,
    4,
    2,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.78);
    var x = 0.0;
    var drawBar = true;
    for (final unit in _bars) {
      final width = unit * 1.6;
      if (drawBar) {
        canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
      }
      x += width;
      drawBar = !drawBar;
      if (x >= size.width) break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
