import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../services/counter_offer_tracker.dart';
import '../services/ride_alert_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'dashboard_screen.dart';
import 'driver_navigation_screen.dart';
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
  StreamSubscription<RideRequest>? _alertTaps;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _startRequestNotifications();
      await _showLocationExplanation();
      await _setUpRideAlerts();
    });
  }

  @override
  void dispose() {
    _requestTimer?.cancel();
    _alertTaps?.cancel();
    DriverSocketService.instance.disconnect();
    super.dispose();
  }

  Future<void> _showLocationExplanation() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    // Already granted: start updates silently instead of asking again every
    // time the home screen is opened (app start, login, after each trip).
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await auth.startLocationUpdates();
      return;
    }
    // Permanently denied: Android won't show its prompt again, so don't nag.
    if (permission == LocationPermission.deniedForever) return;

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

    // Connect to WebSocket for instant real-time dispatch
    final profile = context.read<AuthProvider>().profile;
    if (profile != null && profile.id.isNotEmpty) {
      DriverSocketService.instance.init(
        driverId: profile.id,
        onNewRequest: (request) {
          if (!mounted) return;
          if (!_knownRequestIds.contains(request.id)) {
            _knownRequestIds.add(request.id);
            setState(() => _pendingRequestCount += 1);
            _announceRequest(request);
          }
        },
      );
    }

    // Silent background polling fallback every 3s
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
        .where((r) => !_knownRequestIds.contains(r.id))
        .toList();
    final firstCheck = !_requestSnapshotLoaded;
    _requestSnapshotLoaded = true;
    _knownRequestIds = requests.map((r) => r.id).toSet();
    // Update the badge count live
    if (mounted) setState(() => _pendingRequestCount = requests.length);
    unawaited(_checkCounterOffers());
    if (firstCheck || freshRequests.isEmpty || !mounted) return;
    _announceRequest(freshRequests.first);
  }

  /// Picks up the customer's answer to counter-offers the driver sent and then
  /// walked away from (the request screen watches the one it is showing).
  Future<void> _checkCounterOffers() async {
    final tracker = CounterOfferTracker.instance;
    final waiting = tracker.waitingElsewhere;
    if (waiting.isEmpty) return;
    final api = context.read<AuthProvider>().api;
    final messenger = ScaffoldMessenger.of(context);
    for (final request in waiting) {
      late final Map<String, dynamic> data;
      try {
        data = await api.getRequestStatus(request.id);
      } catch (_) {
        continue;
      }
      if (!mounted) return;
      final status = data['status']?.toString() ?? 'pending';
      if (status == 'pending') continue;
      tracker.remove(request.id);
      final trip = data['trip'];
      if (status == 'accepted' && trip is Map) {
        await _showOfferAccepted(
          request,
          TripRecord.fromJson(Map<String, dynamic>.from(trip)),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${request.customerName} declined your fare offer.'),
          ),
        );
      }
    }
  }

  Future<void> _showOfferAccepted(RideRequest request, TripRecord trip) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Offer accepted',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${request.customerName} agreed to Rs. ${trip.ratePerKm.toStringAsFixed(2)} / km '
          '(fare Rs. ${trip.fare.toStringAsFixed(2)}). The trip is ready to start.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Start navigation'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverNavigationScreen(trip: trip, request: request),
      ),
    );
  }

  /// Sets up the ringing alert used while the app is in the background, and
  /// opens any request the driver tapped an alert for.
  Future<void> _setUpRideAlerts() async {
    if (!mounted) return;
    final alerts = RideAlertService.instance;
    await alerts.requestPermission();
    _alertTaps ??= alerts.openedRequests.listen(_openRequestFromAlert);
    final launchedFrom = alerts.takePendingOpen();
    if (launchedFrom != null) await _openRequestFromAlert(launchedFrom);
  }

  /// In the app: the in-app popup. In the background: the ringing alert.
  void _announceRequest(RideRequest request) {
    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (inForeground) {
      RideAlertService.instance.cancelFor(request.id);
      _showNewRequestDialog(request);
    } else {
      RideAlertService.instance.showIncomingRequest(request);
    }
  }

  Future<void> _openRequestFromAlert(RideRequest alerted) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var request = alerted;
    try {
      // The alert may be stale: only open requests still waiting for a driver.
      final pending = await context
          .read<AuthProvider>()
          .api
          .getIncomingRequests();
      final match = pending.where((r) => r.id == alerted.id);
      if (match.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('This ride request is no longer available.'),
          ),
        );
        return;
      }
      request = match.first;
    } catch (_) {
      // Offline: fall back to the details carried by the alert.
    }
    if (!mounted) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => RequestDetailScreen(request: request)),
    );
  }

  Future<void> _showNewRequestDialog(RideRequest request) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          'New ride request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RequestStat(
                      icon: Icons.straighten_rounded,
                      label: 'Distance',
                      value:
                          '${request.estimatedDistanceKm.toStringAsFixed(1)} km',
                    ),
                  ),
                  Container(width: 1, height: 34, color: Colors.white24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RequestStat(
                      icon: Icons.payments_outlined,
                      label: 'Rate',
                      value:
                          'Rs. ${request.driverRatePerKm.toStringAsFixed(2)} / km',
                    ),
                  ),
                ],
              ),
            ),
            if (request.suggestedRatePerKm != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22FBBF24),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x66FBBF24)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_outlined,
                      size: 18,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer offers Rs. ${request.suggestedRatePerKm!.toStringAsFixed(2)} / km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
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

  void _goHomeTab() {
    if (_index != 0) setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    // On any tab other than Home, back (arrow or Android system back) returns
    // to the Home tab; on Home it leaves the app as usual.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHomeTab();
      },
      child: Scaffold(
        body: HomeTabScope(
          goHome: _goHomeTab,
          child: IndexedStack(
            index: _index,
            children: [
              DashboardScreen(
                isActive: _index == 0,
                onViewEarnings: () => setState(() => _index = 3),
              ),
              _pages[1],
              _pages[2],
              EarningsScreen(isActive: _index == 3),
              _pages[4],
            ],
          ),
        ),
        bottomNavigationBar: _DriverNavBar(
          selectedIndex: _index,
          pendingRequests: _pendingRequestCount,
          onSelected: (i) {
            if (i == 1) setState(() => _pendingRequestCount = 0);
            setState(() => _index = i);
          },
        ),
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
  static const _icons = [
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
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(
            _labels.length,
            (i) => _NavItem(
              icon: _icons[i],
              label: _labels[i],
              selected: selectedIndex == i,
              badge: i == 1 ? pendingRequests : 0,
              onTap: () => onSelected(i),
            ),
          ),
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

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
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
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
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
                      color: active
                          ? const Color(0xFF4B5563)
                          : const Color(0xFF374151),
                      border: Border.all(
                        color: active ? AppTheme.primary : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: active ? 0.24 : 0.14,
                          ),
                          blurRadius: active ? 6 : 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: active ? AppTheme.accent : Colors.white38,
                    ),
                  ),
                  if (widget.badge > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: FadeTransition(
                        opacity: Tween<double>(
                          begin: 0.4,
                          end: 1.0,
                        ).animate(_pulse),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF040404),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            widget.badge > 9 ? '9+' : widget.badge.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
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
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Not specified' : value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestStat extends StatelessWidget {
  const _RequestStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
