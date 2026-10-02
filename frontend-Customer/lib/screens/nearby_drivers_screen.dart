import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/driver_model.dart';
import '../providers/nearby_drivers_provider.dart';
import '../theme.dart';
import '../widgets/app_ui.dart';
import 'ride_request_screen.dart';

class NearbyDriversScreen extends StatefulWidget {
  final String? area;
  final double? pickupLat;
  final double? pickupLng;
  final bool returnSelection;

  const NearbyDriversScreen({
    super.key,
    this.area,
    this.pickupLat,
    this.pickupLng,
    this.returnSelection = false,
  });

  @override
  State<NearbyDriversScreen> createState() => _NearbyDriversScreenState();
}

class _NearbyDriversScreenState extends State<NearbyDriversScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NearbyDriversProvider>().load(
        pickupLat: widget.pickupLat,
        pickupLng: widget.pickupLng,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectDriver(DriverModel driver) {
    if (widget.returnSelection) {
      Navigator.pop(context, driver);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideRequestScreen(driver: driver.toLegacyMap()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby drivers')),
      body: Consumer<NearbyDriversProvider>(
        builder: (context, provider, _) {
          final count = provider.drivers.length;
          return RefreshIndicator(
            onRefresh: provider.refresh,
            color: AppTheme.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                SectionHeader(
                  title: count == 0
                      ? 'Choose a driver'
                      : '$count driver${count == 1 ? '' : 's'} nearby',
                  subtitle: widget.pickupLat == null
                      ? 'Showing verified drivers.'
                      : 'Sorted by distance from your pickup.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Search by driver, vehicle, or area',
                  onSubmitted: provider.setSearch,
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    provider.setSearch('');
                    setState(() {});
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (provider.loading && provider.drivers.isEmpty)
                  const _LoadingDrivers()
                else if (provider.error != null && provider.drivers.isEmpty)
                  AppEmptyState(
                    title: 'We couldn’t load drivers',
                    message: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => provider.refresh(),
                  )
                else if (provider.drivers.isEmpty)
                  AppEmptyState(
                    title: 'No nearby drivers found',
                    message: widget.pickupLat == null
                        ? 'Try refreshing or search by another area.'
                        : 'Try adjusting your pickup location or refresh in a moment.',
                    actionLabel: 'Refresh',
                    onAction: () => provider.refresh(),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Column(
                      children: [
                        for (final driver in provider.drivers)
                          DriverRow(
                            driver: driver,
                            onTap: () => _selectDriver(driver),
                          ),
                        if (provider.loading) ...[
                          const SizedBox(height: AppSpacing.md),
                          const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadingDrivers extends StatelessWidget {
  const _LoadingDrivers();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : AppSpacing.md),
            child: const _LoadingRow(),
          ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 12, width: 140, color: AppTheme.surfaceAlt),
              const SizedBox(height: AppSpacing.xs),
              Container(height: 10, width: 220, color: AppTheme.surfaceAlt),
            ],
          ),
        ),
      ],
    );
  }
}
