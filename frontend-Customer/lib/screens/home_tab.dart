import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/driver_model.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import 'location_picker_screen.dart';
import 'nearby_drivers_screen.dart';
import 'ride_request_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _startBooking(BuildContext context) async {
    final selection = await Navigator.push<LocationSelectionResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (!context.mounted || selection == null) return;

    await context.read<TripProvider>().startDriverSearch(
      pickupAddress: selection.pickupAddress,
      pickupLat: selection.pickupLat,
      pickupLng: selection.pickupLng,
      destinationAddress: selection.destinationAddress,
      destinationLat: selection.destinationLat,
      destinationLng: selection.destinationLng,
    );
    if (!context.mounted) return;

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
    if (!context.mounted) return;
    if (driver == null) return;
    await context.read<TripProvider>().clearPendingSearch();
    if (!context.mounted) return;

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
    final displayName = context.watch<AuthProvider>().customer?.name ?? 'Guest';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _HomeIdentity(displayName: displayName),
            const SizedBox(height: 22),
            _MapHero(onSearchTap: () => _startBooking(context)),
            const SizedBox(height: 28),
            const Text(
              'RideX highlights',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Swipe to explore offers and discover RideX',
              style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 14),
            const _AdvertisementCarousel(),
          ],
        ),
      ),
    );
  }
}

class _HomeIdentity extends StatelessWidget {
  const _HomeIdentity({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good day, $displayName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const Align(
          alignment: Alignment.centerRight,
          child: RideXLogo(size: 48, textSize: 17),
        ),
      ],
    );
  }
}

class _MapHero extends StatelessWidget {
  const _MapHero({required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF080C13),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MapLinePainter())),
          Positioned(
            top: 105,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppTheme.actionBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.actionBlue,
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Semantics(
              button: true,
              label: 'Where to go? Choose pickup and destination',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSearchTap,
                  borderRadius: BorderRadius.circular(99),
                  child: Ink(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111927),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.near_me_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Text(
                            'Where to go?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertisementCarousel extends StatefulWidget {
  const _AdvertisementCarousel();

  @override
  State<_AdvertisementCarousel> createState() => _AdvertisementCarouselState();
}

class _AdvertisementCarouselState extends State<_AdvertisementCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  static const _cards = [
    _HighlightDetails(
      background: Color(0xFFFFF480),
      foreground: Colors.black,
      icon: Icons.local_offer_rounded,
      label: 'RIDEX OFFERS',
      title: 'More rides, more savings.',
      footer: 'VIEW OFFERS',
      detail: 'Save up to 20%',
    ),
    _HighlightDetails(
      background: Color(0xFF3156D9),
      foreground: Colors.white,
      icon: Icons.explore_rounded,
      label: 'DISCOVER RIDEX',
      title: 'Made for easier everyday travel.',
      footer: 'LEARN MORE',
      detail: 'Safe. Simple. Reliable.',
    ),
    _HighlightDetails(
      background: Color(0xFF121826),
      foreground: Colors.white,
      icon: Icons.route_rounded,
      label: 'CLEAR FARES',
      title: 'Know more before you start moving.',
      footer: 'FARE DETAILS',
      detail: 'Transparent estimates',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 225,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: _cards.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) => AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              scale: _currentPage == index ? 1 : 0.94,
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _HighlightCard(details: _cards[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _cards.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: _currentPage == index ? 22 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppTheme.primary
                    : AppTheme.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightDetails {
  const _HighlightDetails({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.title,
    required this.footer,
    required this.detail,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;
  final String title;
  final String footer;
  final String detail;
}

class _HighlightCard extends StatefulWidget {
  const _HighlightCard({required this.details});

  final _HighlightDetails details;

  @override
  State<_HighlightCard> createState() => _HighlightCardState();
}

class _HighlightCardState extends State<_HighlightCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        scale: _pressed ? 0.92 : 1,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: details.background,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: details.foreground.withValues(alpha: 0.14),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: _pressed ? 1.08 : 1,
                  child: Icon(
                    details.icon,
                    color: details.foreground.withValues(alpha: 0.2),
                    size: 76,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          details.label,
                          style: TextStyle(
                            color: details.foreground,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: details.foreground,
                        size: 20,
                      ),
                    ],
                  ),
                  Text(
                    details.title,
                    style: TextStyle(
                      color: details.foreground,
                      fontSize: 24,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          details.footer,
                          style: TextStyle(
                            color: details.foreground,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      Text(
                        details.detail,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: details.foreground.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLinePainter extends CustomPainter {
  const _MapLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final minorRoad = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final mainRoad = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final roads = <Path>[
      Path()
        ..moveTo(-20, size.height * 0.43)
        ..cubicTo(
          size.width * 0.24,
          size.height * 0.32,
          size.width * 0.55,
          size.height * 0.62,
          size.width + 24,
          size.height * 0.43,
        ),
      Path()
        ..moveTo(size.width * 0.18, -20)
        ..lineTo(size.width * 0.36, size.height * 0.34)
        ..lineTo(size.width * 0.27, size.height + 20),
      Path()
        ..moveTo(size.width * 0.72, -10)
        ..lineTo(size.width * 0.62, size.height * 0.35)
        ..lineTo(size.width * 0.82, size.height + 10),
      Path()
        ..moveTo(-10, size.height * 0.67)
        ..lineTo(size.width * 0.32, size.height * 0.54)
        ..lineTo(size.width * 0.58, size.height * 0.73)
        ..lineTo(size.width + 10, size.height * 0.61),
      Path()
        ..moveTo(-10, size.height * 0.18)
        ..lineTo(size.width * 0.31, size.height * 0.24)
        ..lineTo(size.width * 0.49, size.height * 0.08)
        ..lineTo(size.width * 0.8, size.height * 0.2),
    ];
    for (var i = 0; i < roads.length; i++) {
      canvas.drawPath(roads[i], i == 0 ? mainRoad : minorRoad);
    }

    final blockPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    const blocks = [
      Rect.fromLTWH(18, 82, 48, 30),
      Rect.fromLTWH(86, 126, 58, 40),
      Rect.fromLTWH(218, 72, 62, 42),
      Rect.fromLTWH(250, 174, 72, 38),
      Rect.fromLTWH(18, 218, 70, 42),
      Rect.fromLTWH(110, 238, 55, 34),
    ];
    for (final block in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, const Radius.circular(4)),
        blockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
