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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Allow location')),
        ],
      ),
    );
    if (allow != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    await auth.startLocationUpdates();
    if (mounted && auth.locationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.locationError!)));
    }
  }

  void _startRequestNotifications() {
    if (_requestCheckStarted) return;
    _requestCheckStarted = true;
    _checkForRequests();
    _requestTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkForRequests());
  }

  Future<void> _checkForRequests() async {
    late final List<RideRequest> requests;
    try {
      requests = await context.read<AuthProvider>().api.getIncomingRequests();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final freshRequests = requests.where((request) => !_knownRequestIds.contains(request.id)).toList();
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
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Color(0xFF69A8FF)),
            SizedBox(width: 10),
            Text('New ride request'),
          ],
        ),
        content: Text('${request.customerName} is requesting a ride.\n\n${request.pickupAddress} -> ${request.destinationAddress}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(this.context).push(MaterialPageRoute(builder: (_) => RequestDetailScreen(request: request)));
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
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.route_rounded), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}