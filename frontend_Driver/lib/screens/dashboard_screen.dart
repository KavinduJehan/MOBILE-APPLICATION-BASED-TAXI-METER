import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ridex_driver/offline/offline_trip.dart';

import '../models/income_summary.dart';
import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../providers/active_trip_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/trip_place_label.dart';
import '../widgets/app_widgets.dart';
import '../services/offline_database.dart';
import 'active_trip_screen.dart';
import 'driver_navigation_screen.dart';
import 'earnings_screen.dart';
import 'incoming_requests_screen.dart';
import 'offline_trip_screen.dart';
import 'offline_trips_screen.dart';
import 'qr_screen.dart';
import 'rate_screen.dart';

// Status colours. Bright blue is kept for primary actions and selected states,
// so availability uses green / amber / violet / red instead.
const _available = Color(0xFF22C55E);
const _busyOnline = Color(0xFFF59E0B);
const _busyOffline = Color(0xFFA78BFA);
const _unavailable = Color(0xFFEF4444);
const _muted = Color(0xFF9CA3AF);
const _cardRadius = 18.0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.isActive = true,
    this.onViewEarnings,
    this.onOpenRequests,
  });
  final bool isActive;
  final VoidCallback? onViewEarnings;

  /// Switches to the Requests tab. Falls back to pushing the screen.
  final VoidCallback? onOpenRequests;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  IncomeSummary? _income;
  bool _incomeLoading = false;
  bool _incomeFailed = false;
  Timer? _activityTimer;

  /// Pending requests, reported by the map's polling.
  final ValueNotifier<int> _requestCount = ValueNotifier(0);

  /// Null while GPS is fine, otherwise the reason it is not.
  final ValueNotifier<String?> _gpsIssue = ValueNotifier(null);

  Future<void> _loadIncome() async {
    if (_incomeLoading || !mounted) return;
    setState(() {
      _incomeLoading = true;
      _incomeFailed = false;
    });
    try {
      final income = await context.read<AuthProvider>().api.getIncomeSummary();
      if (mounted) setState(() => _income = income);
    } catch (_) {
      if (mounted) setState(() => _incomeFailed = true);
    } finally {
      if (mounted) setState(() => _incomeLoading = false);
    }
  }

  Future<void> _refreshActivity() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await context.read<ActiveTripProvider>().refresh(
      auth.api,
      auth.profile?.id ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadIncome();
      _refreshActivity();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.loadProfile(force: true);
      if (!mounted) return;
      _refreshActivity();
      if (widget.isActive) _loadIncome();
    });
    // Keep the active-trip state fresh while Home is on screen.
    _activityTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (widget.isActive) _refreshActivity();
    });
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    _requestCount.dispose();
    _gpsIssue.dispose();
    super.dispose();
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    _refreshActivity();
    _loadIncome();
  }

  void _openRequests() {
    final open = widget.onOpenRequests;
    if (open != null) {
      open();
    } else {
      _push(const IncomingRequestsScreen());
    }
  }

  void _resume(ActiveTripProvider active, AuthProvider auth) {
    final online = active.onlineTrip;
    final offline = active.offlineTrip;
    if (online != null) {
      _push(
        online.canResumeNavigation
            ? DriverNavigationScreen(
                trip: online,
                request: online.toResumeRequest(),
              )
            : ActiveTripScreen(trip: online),
      );
    } else if (offline != null) {
      _push(
        DriverOfflineTripScreen(trip: offline, owner: auth.profile?.id ?? ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final active = context.watch<ActiveTripProvider>();
    final profile = auth.profile;
    final busy = active.hasActive;
    return AppShellScaffold(
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            auth.loadProfile(force: true),
            _loadIncome(),
            _refreshActivity(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(profile?.name, profile?.vehicleNumber),
              const SizedBox(height: 14),
              ValueListenableBuilder<int>(
                valueListenable: _requestCount,
                builder: (context, requests, _) =>
                    ValueListenableBuilder<String?>(
                      valueListenable: _gpsIssue,
                      builder: (context, gps, _) =>
                          _availabilityCard(auth, active, requests, gps),
                    ),
              ),
              if (profile != null && !profile.isVerified) ...[
                const SizedBox(height: 10),
                const OfflineNotice(
                  'Your account is pending admin approval. You cannot receive ride requests yet.',
                  tone: OfflineTone.warning,
                ),
              ],
              if (busy) ...[
                const SizedBox(height: 12),
                _activeTripCard(active, auth),
              ],
              const SizedBox(height: 12),
              _todayEarningsCard(),
              const SizedBox(height: 12),
              _DriverHomeMap(
                height: busy ? 170 : 220,
                showRequests: !busy,
                onRequests: (count) {
                  if (_requestCount.value != count) _requestCount.value = count;
                },
                onGpsIssue: (issue) {
                  if (_gpsIssue.value != issue) _gpsIssue.value = issue;
                },
                onOpenRequests: _openRequests,
              ),
              if (active.loaded && !busy) ...[
                const SizedBox(height: 12),
                ActionCard(
                  title: 'Start Taxi Meter (Street Hail)',
                  subtitle: 'Start a live GPS meter at an agreed rate.',
                  icon: Icons.speed_rounded,
                  onTap: () => _showStartStreetMeterModal(context, auth),
                ),
              ],
              const SizedBox(height: 18),
              if (!active.loaded)
                const _QuickActionsSkeleton()
              else if (busy)
                const _PausedNote()
              else
                _quickActions(auth),
              if (auth.busy) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header(String? name, String? vehicle) {
    final first = name?.trim().split(' ').first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${first == null || first.isEmpty ? 'Driver' : first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              if (vehicle != null && vehicle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    vehicle,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF3C7BFF), Color(0xFF1C4FD6)],
                  ),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'RideX',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Availability ─────────────────────────────────────────────────────────

  Widget _availabilityCard(
    AuthProvider auth,
    ActiveTripProvider active,
    int requests,
    String? gpsIssue,
  ) {
    final profile = auth.profile;
    final locationIssue = gpsIssue ?? auth.locationError;
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;
    if (active.onlineTrip != null) {
      color = _busyOnline;
      icon = Icons.directions_car_rounded;
      title = 'Busy • online trip';
      subtitle = 'New requests are paused until this ride ends.';
    } else if (active.offlineTrip != null) {
      color = _busyOffline;
      icon = Icons.offline_bolt_rounded;
      title = 'Busy • offline trip';
      subtitle = 'New trips are paused until this one is finished.';
    } else if (profile == null || !active.loaded) {
      color = _muted;
      icon = Icons.sync_rounded;
      title = 'Checking status…';
      subtitle = 'Just a moment.';
    } else if (!profile.isVerified) {
      color = _unavailable;
      icon = Icons.hourglass_top_rounded;
      title = 'Unavailable';
      subtitle = 'Waiting for admin approval.';
    } else if (locationIssue != null) {
      color = _unavailable;
      icon = Icons.location_off_rounded;
      title = 'Unavailable';
      subtitle = locationIssue;
    } else {
      color = _available;
      icon = Icons.check_circle_rounded;
      title = 'Available';
      subtitle = requests > 0
          ? '$requests ${requests == 1 ? 'request' : 'requests'} waiting'
          : 'Ready for ride requests';
    }
    final rate = switch (auth.rateMode) {
      'AUTO' => 'Auto surge',
      'ADMIN' =>
        'Admin • Rs. ${profile?.ratePerKm.toStringAsFixed(0) ?? '0'}/km',
      _ => 'Rs. ${profile?.ratePerKm.toStringAsFixed(0) ?? '0'}/km',
    };
    return Semantics(
      container: true,
      label: 'Driver status: $title. $subtitle',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _push(const RateScreen()),
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rate,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Pricing',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active trip ──────────────────────────────────────────────────────────

  Widget _activeTripCard(ActiveTripProvider active, AuthProvider auth) {
    final online = active.onlineTrip;
    final offline = active.offlineTrip;
    final isOnline = online != null;
    final color = isOnline ? _busyOnline : _busyOffline;
    String stage;
    String passenger;
    String route;
    final stats = <(IconData, String)>[];
    if (online != null) {
      stage = _onlineStage(online);
      passenger = online.customerName;
      route =
          '${tripPlaceLabel(online.startAddress)} → ${tripPlaceLabel(online.endAddress)}';
      stats.add((
        Icons.payments_outlined,
        'Rs. ${online.ratePerKm.toStringAsFixed(0)}/km',
      ));
      final started = online.startedAt?.toLocal();
      if (started != null) {
        stats.add((
          Icons.schedule_rounded,
          'Since ${TimeOfDay.fromDateTime(started).format(context)}',
        ));
      }
    } else {
      final trip = offline!;
      final destination = trip.data['destination'];
      stage = 'Offline trip in progress';
      passenger = trip.data['customerName']?.toString() ?? 'Passenger';
      route = destination is Map
          ? 'To ${destination['name']}'
          : 'No destination set';
      stats
        ..add((Icons.route_rounded, '${trip.distanceKm.toStringAsFixed(2)} km'))
        ..add((Icons.payments_outlined, 'Rs. ${trip.fare.toStringAsFixed(2)}'));
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OfflineStatusPill(
                stage,
                tone: OfflineTone.warning,
                icon: isOnline
                    ? Icons.directions_car_rounded
                    : Icons.offline_bolt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            passenger,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            route,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.3),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final (icon, text) in stats)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: _muted),
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _resume(active, auth),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              online != null && online.canResumeNavigation
                  ? Icons.navigation_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              online != null
                  ? (online.canResumeNavigation
                        ? 'Resume navigation'
                        : 'Open active trip')
                  : 'Resume trip',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _onlineStage(TripRecord trip) => trip.pickedUpAt != null
      ? 'Trip in progress'
      : trip.arrivedAt != null
      ? 'Waiting at pickup'
      : 'Heading to pickup';

  // ── Quick actions ────────────────────────────────────────────────────────

  Widget _quickActions(AuthProvider auth) {
    final profile = auth.profile;
    final rate = auth.rateMode == 'AUTO'
        ? 'Auto surge'
        : 'Rs. ${profile?.ratePerKm.toStringAsFixed(0) ?? '0'} / km';
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(_cardRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
            onTap: () => _push(const DriverOfflineTripsScreen()),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline trips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Show your QR, scan an offer, run a trip',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.qr_code_2_rounded,
                label: 'My QR',
                caption: 'Show to riders',
                onTap: () => _push(const QrScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.price_change_rounded,
                label: 'Pricing',
                caption: rate,
                onTap: () => _push(const RateScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Earnings ─────────────────────────────────────────────────────────────

  Widget _todayEarningsCard() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final today = _income?.daysForPeriod(1, now).single;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: widget.onViewEarnings ?? () => _push(const EarningsScreen()),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF173967), Color(0xFF101826)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: const Color(0xFF69A8FF).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's earnings",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      today == null
                          ? (_incomeLoading ? 'Loading…' : 'Unavailable')
                          : 'Rs. ${today.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (_incomeFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _income == null
                              ? 'Pull down to retry.'
                              : 'Showing last loaded earnings.',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (today?.trips != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${today!.trips}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        today.trips == 1 ? 'trip' : 'trips',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              if (_incomeLoading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  void _showStartStreetMeterModal(BuildContext context, AuthProvider auth) {
    final defaultRate = auth.profile?.ratePerKm ?? 100.0;
    final nameController = TextEditingController(text: 'Street Passenger');
    final rateController = TextEditingController(
      text: defaultRate.toStringAsFixed(0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.speed_rounded, color: Color(0xFF22C55E), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Start Digital Taxi Meter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Tracks real-world distance via GPS and calculates fare offline.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Passenger Name (Optional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF161F33),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Rate per km (Rs.)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF161F33),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.payments, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Start Meter Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final rate =
                      double.tryParse(rateController.text.trim()) ??
                      defaultRate;
                  Navigator.pop(bottomSheetContext);

                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final localId = 'offline-$timestamp';
                  final offlineReceipt =
                      'REC-OFFLINE-${timestamp.toRadixString(36).toUpperCase()}';

                  final trip = TripRecord(
                    id: localId,
                    customerName: name.isNotEmpty ? name : 'Street Passenger',
                    startAddress: 'Street Pickup',
                    endAddress: 'Meter Destination',
                    distanceKm: 0.0,
                    ratePerKm: rate > 0 ? rate : 100.0,
                    fare: 0.0,
                    status: 'in_progress',
                    date: DateTime.now(),
                    receiptNumber: offlineReceipt,
                  );

                  await OfflineDatabase.instance.insertOfflineTrip(
                    owner: auth.profile?.id,
                    localId: localId,
                    customerName: trip.customerName,
                    startAddress: trip.startAddress,
                    endAddress: trip.endAddress,
                    distanceKm: trip.distanceKm,
                    ratePerKm: trip.ratePerKm,
                    fare: trip.fare,
                    receiptNumber: offlineReceipt,
                    status: 'in_progress',
                    date: trip.date,
                  );

                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActiveTripScreen(
                        trip: trip,
                        receiptNumber: offlineReceipt,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surface,
    borderRadius: BorderRadius.circular(_cardRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(_cardRadius),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PausedNote extends StatelessWidget {
  const _PausedNote();
  @override
  Widget build(BuildContext context) => const OfflineNotice(
    'Quick actions are hidden while a trip is active. Finish it to take another.',
  );
}

class _QuickActionsSkeleton extends StatelessWidget {
  const _QuickActionsSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
  );
}

// ── Map ──────────────────────────────────────────────────────────────────────

class _DriverHomeMap extends StatefulWidget {
  const _DriverHomeMap({
    required this.height,
    required this.showRequests,
    required this.onRequests,
    required this.onGpsIssue,
    required this.onOpenRequests,
  });
  final double height;
  final bool showRequests;
  final ValueChanged<int> onRequests;
  final ValueChanged<String?> onGpsIssue;
  final VoidCallback onOpenRequests;

  @override
  State<_DriverHomeMap> createState() => _DriverHomeMapState();
}

class _DriverHomeMapState extends State<_DriverHomeMap>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _requestTimer;
  LatLng? _driverPosition;
  List<RideRequest> _requests = const [];
  String? _locationMessage;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocation();
    _loadRequests();
    _requestTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadRequests(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _requestTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the settings screen: try again if GPS was the problem.
    if (state == AppLifecycleState.resumed && _driverPosition == null) {
      _loadLocation();
    }
  }

  void _setIssue(String? message) {
    _locationMessage = message;
    widget.onGpsIssue(message);
  }

  Future<void> _loadLocation() async {
    if (mounted) setState(() => _loadingLocation = true);
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _setIssue('Location services are off.');
        });
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _setIssue('Location permission is needed.');
        });
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _driverPosition = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
        _setIssue(null);
      });
      await _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 20,
            ),
          ).listen((position) {
            if (!mounted) return;
            setState(() {
              _driverPosition = LatLng(position.latitude, position.longitude);
            });
          });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _setIssue('Unable to find your location.');
        });
      }
    }
  }

  /// Opens the right system screen for whatever is blocking GPS.
  Future<void> _fixLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      } else if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
        await _loadLocation();
      } else if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      } else {
        await _loadLocation();
      }
    } catch (_) {
      await _loadLocation();
    }
  }

  Future<void> _loadRequests() async {
    try {
      final requests = await context
          .read<AuthProvider>()
          .api
          .getIncomingRequests();
      if (!mounted) return;
      setState(() => _requests = requests);
      widget.onRequests(requests.length);
    } catch (_) {
      // The map remains usable when request polling is temporarily unavailable.
    }
  }

  void _recenter() {
    final position = _driverPosition;
    if (position == null) return;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 14));
  }

  bool _hasCoordinates(RideRequest request) {
    return request.pickupLatitude.abs() <= 90 &&
        request.pickupLongitude.abs() <= 180 &&
        (request.pickupLatitude != 0 || request.pickupLongitude != 0);
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) => Material(
    color: const Color(0xE60E1422),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final position = _driverPosition;
    if (position == null) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Center(
          child: _loadingLocation
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 12),
                    Text(
                      'Finding your location…',
                      style: TextStyle(color: _muted),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        size: 30,
                        color: _unavailable,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _locationMessage ?? 'Map location unavailable.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _fixLocation,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                        label: const Text('Turn on location'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver-current-location'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your location'),
      ),
      ..._requests
          .where(_hasCoordinates)
          .map(
            (request) => Marker(
              markerId: MarkerId('request-${request.id}'),
              position: LatLng(request.pickupLatitude, request.pickupLongitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(
                title: request.customerName,
                snippet: request.pickupAddress.isEmpty
                    ? 'Incoming pickup request'
                    : request.pickupAddress,
              ),
            ),
          ),
    };
    final count = _requests.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_cardRadius),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: position, zoom: 14),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: markers,
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _chip(
                icon: Icons.gps_fixed_rounded,
                label: 'GPS active',
                color: _available,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: const Color(0xE60E1422),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: _recenter,
                  tooltip: 'Recenter map',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ),
            ),
            if (widget.showRequests)
              Positioned(
                left: 10,
                bottom: 10,
                child: _chip(
                  icon: count > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  label: count == 0
                      ? 'No requests'
                      : '$count ${count == 1 ? 'request' : 'requests'}',
                  color: count > 0 ? _busyOnline : _muted,
                  onTap: widget.onOpenRequests,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
