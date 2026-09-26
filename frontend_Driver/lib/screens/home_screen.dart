import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'earnings_screen.dart';
import 'incoming_requests_screen.dart';
import 'request_detail_screen.dart';
import 'settings_screen.dart';
import 'trip_history_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  late int _index;
  Timer? _requestTimer;
  Set<String> _knownRequestIds = <String>{};
  bool _requestCheckStarted = false;
  bool _requestSnapshotLoaded = false;

  final _pages = const [
    DashboardScreen(),
    IncomingRequestsScreen(),
    TripHistoryScreen(),
    EarningsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationExplanation();
      _startRequestNotifications();
    });
  }

  @override
  void dispose() {
    _requestTimer?.cancel();
    super.dispose();
  }

  Future<void> _showLocationExplanation() async {
    if (!mounted) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow location access?'),
        content: const Text(
          'RideX uses your location to show passengers nearby drivers and to keep your position updated during a trip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow location'),
          ),
        ],
      ),
    );
    if (allow != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    await auth.startLocationUpdates();
    if (mounted && auth.locationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.locationError!)));
    }
  }

  void _startRequestNotifications() {
    if (_requestCheckStarted) return;
    _requestCheckStarted = true;
    _checkForRequests();
    _requestTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkForRequests(),
    );
  }

  Future<void> _checkForRequests() async {
    late final List<RideRequest> requests;
    try {
      requests = await context.read<AuthProvider>().api.getIncomingRequests();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final freshRequests = requests
        .where((request) => !_knownRequestIds.contains(request.id))
        .toList();
    final firstCheck = !_requestSnapshotLoaded;
    _requestSnapshotLoaded = true;
    _knownRequestIds = requests.map((request) => request.id).toSet();
    if (firstCheck || freshRequests.isEmpty || !mounted) return;
    _showNewRequestDialog(freshRequests.first);
  }

  Future<void> _showNewRequestDialog(RideRequest request) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New ride request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x2269A8FF),
                  child: Icon(Icons.person_outline, color: Color(0xFF69A8FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _RequestStopRow(
              icon: Icons.radio_button_checked,
              label: 'Pickup',
              value: request.pickupAddress,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 12),
            _RequestStopRow(
              icon: Icons.location_on_outlined,
              label: 'Destination',
              value: request.destinationAddress,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              '${request.estimatedDistanceKm.toStringAsFixed(1)} km  •  Rs. ${request.driverRatePerKm.toStringAsFixed(2)} / km',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(this.context).push(
                MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(request: request),
                ),
              );
            },
            child: const Text('Review request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_rounded),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _RequestStopRow extends StatelessWidget {
  const _RequestStopRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Address unavailable' : value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
