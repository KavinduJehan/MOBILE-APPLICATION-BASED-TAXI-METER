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
