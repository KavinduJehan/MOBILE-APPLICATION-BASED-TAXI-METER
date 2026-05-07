import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'earnings_screen.dart';
import 'incoming_requests_screen.dart';
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