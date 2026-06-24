import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/driver_model.dart';
import '../providers/nearby_drivers_provider.dart';
import '../theme.dart';
import 'ride_request_screen.dart';

class NearbyDriversScreen extends StatefulWidget {
  final String? area;
  final bool returnSelection;

  const NearbyDriversScreen({
    super.key,
    this.area,
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
      context.read<NearbyDriversProvider>().load(area: widget.area);
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Nearby Drivers')),
      body: Consumer<NearbyDriversProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: provider.refresh,
            color: AppTheme.primaryBlue,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted: provider.setSearch,
                  decoration: InputDecoration(
                    hintText: 'Search driver, vehicle, or area',
                    hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearch('');
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF333336)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (provider.loading && provider.drivers.isEmpty)
                  const _LoadingState()
                else if (provider.error != null && provider.drivers.isEmpty)
                  _ErrorState(
                    message: provider.error!,
                    onRetry: provider.refresh,
                  )
                else if (provider.drivers.isEmpty)
                  const _EmptyState()
                else
                  ...provider.drivers.map(
                    (driver) => _DriverCard(
                      driver: driver,
                      onTap: () => _selectDriver(driver),
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

class _DriverCard extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback onTap;

  const _DriverCard({required this.driver, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = driver.isAvailable
        ? AppTheme.successGreen
        : const Color(0xFF9CA3AF);
    final statusText = driver.isAvailable ? 'Available' : 'Unavailable';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333336)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          backgroundColor: AppTheme.primaryBlue,
          child: Icon(Icons.local_taxi, color: Colors.white),
        ),
        title: Text(
          driver.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${driver.vehicleType} • ${driver.vehicleNumber}',
                style: const TextStyle(color: Color(0xFFB5B5B5)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _Meta(icon: Icons.place, text: driver.area.isEmpty ? '-' : driver.area),
                  _Meta(
                    icon: Icons.route,
                    text: driver.distanceKm == null
                        ? 'Nearby'
                        : '${driver.distanceKm!.toStringAsFixed(1)} km',
                  ),
                  _Meta(
                    icon: Icons.star,
                    text: driver.rating.toStringAsFixed(1),
                  ),
                  _Meta(
                    icon: Icons.circle,
                    text: statusText,
                    color: statusColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Meta({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF9CA3AF),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_taxi_outlined, color: Color(0xFF666666), size: 56),
          SizedBox(height: 12),
          Text(
            'No nearby drivers found',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Pull to refresh or try another area.',
            style: TextStyle(color: Color(0xFF8A8A8A)),
          ),
        ],
      ),
    );
  }
}
