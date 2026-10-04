import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../models/income_summary.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import '../models/trip_record.dart';
import '../services/offline_database.dart';
import 'active_trip_screen.dart';
import 'earnings_screen.dart';
import 'incoming_requests_screen.dart';
import 'qr_screen.dart';
import 'rate_screen.dart';
import 'scan_trip_offer_screen.dart';
import 'settings_screen.dart';
import 'trip_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.isActive = true, this.onViewEarnings});
  final bool isActive;
  final VoidCallback? onViewEarnings;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  IncomeSummary? _income;
  bool _incomeLoading = false;
  bool _incomeFailed = false;

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

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _loadIncome();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().loadProfile(force: true);
        if (widget.isActive) _loadIncome();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return AppShellScaffold(
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([auth.loadProfile(force: true), _loadIncome()]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${profile?.name.split(' ').first ?? 'Driver'}!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage your rides from one secure dashboard.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const DriverLogo(size: 58),
                ],
              ),
              const SizedBox(height: 20),
              _todayEarningsCard(),
              const SizedBox(height: 20),
              if (profile != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C7CFF).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF6C7CFF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Pricing mode: ${auth.rateMode == 'DRIVER'
                          ? 'Driver-Set'
                          : auth.rateMode == 'AUTO'
                          ? 'Auto Surge'
                          : 'Admin-Controlled'}',
                      style: const TextStyle(
                        color: Color(0xFFAEB8FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (profile != null && !profile.isVerified)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E2F00),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'Your account is pending admin approval. You cannot receive ride requests yet.',
                    style: TextStyle(
                      color: Color(0xFFFFE08A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (profile != null && !profile.isVerified)
                const SizedBox(height: 18),
              const _DriverHomeMap(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0E1422),
                      const Color(0xFF14253D).withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live status',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile?.isVerified == true
                          ? 'Verified and ready for requests'
                          : 'Pending verification',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: auth.rateMode == 'AUTO'
                            ? Colors.amber.withValues(alpha: 0.15)
                            : (auth.rateMode == 'ADMIN'
                                  ? Colors.blueAccent.withValues(alpha: 0.15)
                                  : Colors.green.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: auth.rateMode == 'AUTO'
                              ? Colors.amber
                              : (auth.rateMode == 'ADMIN'
                                    ? Colors.blueAccent
                                    : Colors.green),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            auth.rateMode == 'AUTO'
                                ? Icons.bolt_rounded
                                : (auth.rateMode == 'ADMIN'
                                      ? Icons.lock_rounded
                                      : Icons.person_rounded),
                            size: 16,
                            color: auth.rateMode == 'AUTO'
                                ? Colors.amber
                                : (auth.rateMode == 'ADMIN'
                                      ? Colors.blueAccent
                                      : Colors.green),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            auth.rateMode == 'AUTO'
                                ? 'Active Mode: Auto Surge ⚡'
                                : (auth.rateMode == 'ADMIN'
                                      ? 'Active Mode: Admin Controlled 🔒'
                                      : 'Active Mode: Driver Set 🧑‍✈️'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: auth.rateMode == 'AUTO'
                                  ? Colors.amber
                                  : (auth.rateMode == 'ADMIN'
                                        ? Colors.blueAccent
                                        : Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        StatCard(
                          label: auth.rateMode == 'AUTO'
                              ? 'Pricing Mode'
                              : (auth.rateMode == 'ADMIN'
                                    ? 'Admin Rate'
                                    : 'Rate per km'),
                          value: auth.rateMode == 'AUTO'
                              ? 'Auto Surge'
                              : 'Rs. ${profile?.ratePerKm.toStringAsFixed(2) ?? '0.00'}',
                          icon: auth.rateMode == 'AUTO'
                              ? Icons.bolt_rounded
                              : (auth.rateMode == 'ADMIN'
                                    ? Icons.lock_clock_rounded
                                    : Icons.payments_rounded),
                        ),
                        StatCard(
                          label: 'GPS Range',
                          value: '10 km',
                          icon: Icons.radar_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Quick Actions',
                subtitle: 'Jump straight to the tasks you use every day.',
              ),
              const SizedBox(height: 14),
              ActionCard(
                title: 'Incoming Requests',
                subtitle: 'Review pending ride requests and respond.',
                icon: Icons.receipt_long_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const IncomingRequestsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'My QR Code',
                subtitle: 'Show riders your verification QR.',
                icon: Icons.qr_code_rounded,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const QrScreen())),
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'Scan Trip Offer QR',
                subtitle:
                    'Scan passenger offer QR to start offline or agreed-rate ride.',
                icon: Icons.qr_code_scanner_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScanTripOfferScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'Start Taxi Meter (Street Hail)',
                subtitle:
                    'Start live digital taxi meter directly with real-time GPS tracking.',
                icon: Icons.speed_rounded,
                onTap: () => _showStartStreetMeterModal(context, auth),
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'Pricing',
                subtitle: auth.rateMode == 'DRIVER'
                    ? 'View and update your driver-set rate.'
                    : 'View your current rate and pricing mode.',
                icon: Icons.price_change_rounded,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const RateScreen())),
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'Trip History',
                subtitle: 'Check completed rides and receipts.',
                icon: Icons.route_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
                ),
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'Earnings',
                subtitle: 'Track daily income and completed trips.',
                icon: Icons.bar_chart_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EarningsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'Settings',
                subtitle: 'Review profile and sign out.',
                icon: Icons.settings_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              if (auth.busy) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayEarningsCard() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final today = _income?.daysForPeriod(1, now).single;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap:
            widget.onViewEarnings ??
            () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const EarningsScreen()));
              if (mounted) _loadIncome();
            },
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF173967), Color(0xFF101826)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF69A8FF).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF69A8FF),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Today's earnings",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_incomeLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                today == null
                    ? (_incomeLoading ? 'Loading...' : 'Unavailable')
                    : 'Rs. ${today.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  if (today?.trips != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: Color(0xFF34D399),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${today!.trips} completed ${today.trips == 1 ? 'trip' : 'trips'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  const Text(
                    'View earnings',
                    style: TextStyle(
                      color: Color(0xFF69A8FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_incomeFailed) ...[
                const SizedBox(height: 10),
                Text(
                  _income == null
                      ? 'Pull down to retry.'
                      : 'Showing last loaded earnings. Pull down to refresh.',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showStartStreetMeterModal(BuildContext context, AuthProvider auth) {
    final defaultRate = auth.profile?.ratePerKm ?? 100.0;
    final nameController = TextEditingController(text: 'Street Passenger');
    final rateController = TextEditingController(text: defaultRate.toStringAsFixed(0));

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
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.payments, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start Meter Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final rate = double.tryParse(rateController.text.trim()) ?? defaultRate;
                  Navigator.pop(bottomSheetContext);

                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final localId = 'offline-$timestamp';
                  final offlineReceipt = 'REC-OFFLINE-${timestamp.toRadixString(36).toUpperCase()}';

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

class _DriverHomeMap extends StatefulWidget {
  const _DriverHomeMap();

  @override
  State<_DriverHomeMap> createState() => _DriverHomeMapState();
}

class _DriverHomeMapState extends State<_DriverHomeMap> {
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
    _loadLocation();
    _loadRequests();
    _requestTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadRequests(),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _requestTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _locationMessage = 'Turn on location services to view your map.';
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
          _locationMessage =
              'Location permission is required to view your map.';
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
        _locationMessage = null;
      });
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
          _locationMessage = 'Unable to determine your current location.';
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final position = _driverPosition;
    if (position == null) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF0E1422),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: _loadingLocation
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _locationMessage ?? 'Map location unavailable.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
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
              top: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'driver-home-recenter',
                onPressed: _recenter,
                tooltip: 'Recenter map',
                child: const Icon(Icons.my_location),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xDD0E1422),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    '${_requests.where(_hasCoordinates).length} request${_requests.where(_hasCoordinates).length == 1 ? '' : 's'} nearby',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
