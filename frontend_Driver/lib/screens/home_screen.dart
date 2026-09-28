import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
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
  int _pendingRequestCount = 0;

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
    final freshRequests = requests.where((r) => !_knownRequestIds.contains(r.id)).toList();
    final firstCheck = !_requestSnapshotLoaded;
    _requestSnapshotLoaded = true;
    _knownRequestIds = requests.map((r) => r.id).toSet();
    // Update the badge count live
    if (mounted) setState(() => _pendingRequestCount = requests.length);
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
      bottomNavigationBar: _DriverNavBar(
        selectedIndex: _index,
        pendingRequests: _pendingRequestCount,
        onSelected: (i) {
          if (i == 1) setState(() => _pendingRequestCount = 0);
          setState(() => _index = i);
        },
      ),
    );
  }
}

// ── Custom animated nav bar ──────────────────────────────────────────────────

class _DriverNavBar extends StatelessWidget {
  const _DriverNavBar({
    required this.selectedIndex,
    required this.pendingRequests,
    required this.onSelected,
  });

  final int selectedIndex;
  final int pendingRequests;
  final ValueChanged<int> onSelected;

  static const _labels = ['Home', 'Requests', 'Trips', 'Earnings', 'Settings'];
  static const _icons  = [
    Icons.dashboard_rounded,
    Icons.receipt_long_rounded,
    Icons.route_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        height: 74,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 4)),
            BoxShadow(color: Color(0x4D000000), blurRadius: 4,  offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: List.generate(_labels.length, (i) => _NavItem(
            icon: _icons[i],
            label: _labels[i],
            selected: selectedIndex == i,
            badge: i == 1 ? pendingRequests : 0,
            onTap: () => onSelected(i),
          )),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _NavItem old) {
    super.didUpdateWidget(old);
    if (old.badge != widget.badge) _syncPulse();
  }

  void _syncPulse() {
    if (widget.badge > 0) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: _pressed ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? const Color(0xFF4B5563) : const Color(0xFF374151),
                      border: Border.all(color: active ? AppTheme.primary : Colors.transparent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: active ? 0.24 : 0.14),
                          blurRadius: active ? 6 : 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, size: 20, color: active ? AppTheme.accent : Colors.white38),
                  ),
                  if (widget.badge > 0)
                    Positioned(
                      top: -4, right: -6,
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_pulse),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF040404), width: 1.5),
                          ),
                          child: Text(
                            widget.badge > 9 ? '9+' : widget.badge.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                color: active ? AppTheme.accent : Colors.white38,
                fontSize: 9,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
