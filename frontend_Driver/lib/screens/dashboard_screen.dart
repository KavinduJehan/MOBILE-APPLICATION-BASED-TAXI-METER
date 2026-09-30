import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'earnings_screen.dart';
import 'incoming_requests_screen.dart';
import 'qr_screen.dart';
import 'rate_screen.dart';
import 'scan_trip_offer_screen.dart';
import 'settings_screen.dart';
import 'trip_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    Future.microtask(auth.loadProfile);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return AppShellScaffold(
      child: SingleChildScrollView(
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
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const DriverLogo(size: 58),
              ],
            ),
            const SizedBox(height: 20),
            if (profile != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C7CFF).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF6C7CFF).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Pricing mode: ${auth.rateMode == 'DRIVER' ? 'Driver-Set' : auth.rateMode == 'AUTO' ? 'Auto Surge' : 'Admin-Controlled'}',
                    style: const TextStyle(color: Color(0xFFAEB8FF), fontWeight: FontWeight.w700),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      StatCard(
                        label: 'Rate per km',
                        value:
                            'Rs. ${profile?.ratePerKm.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.payments_rounded,
                      ),
                      StatCard(
                        label: 'Area',
                        value: profile?.area.isNotEmpty == true
                            ? profile!.area
                            : 'Unknown',
                        icon: Icons.place_rounded,
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
              subtitle: 'Scan passenger offer QR to start offline or agreed-rate ride.',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ScanTripOfferScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Pricing',
              subtitle: auth.rateMode == 'DRIVER' ? 'View and update your driver-set rate.' : 'View your current rate and pricing mode.',
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
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const EarningsScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Settings',
              subtitle: 'Review profile and sign out.',
              icon: Icons.settings_rounded,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            if (auth.busy) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
        ),
      ),
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

