import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import '../utils/google_polyline.dart';
import '../widgets/app_widgets.dart';
import 'earnings_screen.dart';
import 'incoming_requests_screen.dart';
import 'qr_screen.dart';
import 'rate_screen.dart';
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
              title: 'Update Rate',
              subtitle: 'Keep your per-km rate current.',
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
  Timer? _routeTimer;
  LatLng? _driverPosition;
  List<RideRequest> _requests = const [];
  List<LatLng> _routePoints = const [];
  String? _routeMessage;
  String? _routeRequestId;
  LatLng? _lastRouteOrigin;
  bool _loadingRoute = false;
  bool _hasFittedRoute = false;
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
    _routeTimer?.cancel();
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
            _scheduleRouteRefresh();
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
      setState(() {
        _requests = requests;
        if (_routeRequestId != _routeRequest?.id) {
          _routePoints = const [];
          _routeMessage = null;
          _hasFittedRoute = false;
        }
      });
      _scheduleRouteRefresh();
    } catch (_) {
      // The map remains usable when request polling is temporarily unavailable.
    }
  }

  RideRequest? get _routeRequest {
    for (final request in _requests) {
      if (_hasCoordinates(request)) {
        return request;
      }
    }
    return null;
  }

  bool _hasDestinationCoordinates(RideRequest request) {
    return request.destinationLatitude.abs() <= 90 &&
        request.destinationLongitude.abs() <= 180 &&
        (request.destinationLatitude != 0 || request.destinationLongitude != 0);
  }

  void _scheduleRouteRefresh() {
    final request = _routeRequest;
    if (request == null || _loadingRoute || _driverPosition == null) return;
    
    final lastOrigin = _lastRouteOrigin;
    if (_routeRequestId == request.id && lastOrigin != null) {
      final distance = Geolocator.distanceBetween(
        lastOrigin.latitude,
        lastOrigin.longitude,
        _driverPosition!.latitude,
        _driverPosition!.longitude,
      );
      if (distance < 50 && _routePoints.length > 1) {
        return;
      }
    }

    _routeTimer?.cancel();
    _routeTimer = Timer(const Duration(milliseconds: 400), () {
      _routeTimer = null;
      _loadRequestRoute(request);
    });
  }

  Future<void> _loadRequestRoute(RideRequest request) async {
    final start = _driverPosition;
    if (start == null || _loadingRoute) return;
    
    setState(() {
      _loadingRoute = true;
      _routeMessage = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.getDrivingRoute(
        pickupLatitude: start.latitude,
        pickupLongitude: start.longitude,
        destinationLatitude: request.pickupLatitude,
        destinationLongitude: request.pickupLongitude,
      );
      final decodedPoints = decodeGooglePolyline(
        data['encodedPolyline']?.toString() ?? '',
      );
      if (decodedPoints.length < 2) {
        throw const FormatException('Route contains no map path');
      }
      final points = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeRequestId = request.id;
        _lastRouteOrigin = start;
        _routeMessage = null;
        _loadingRoute = false;
        _hasFittedRoute = false;
      });
      _fitRoute(request);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRoute = false;
        _routeMessage = 'Unable to load the customer route.';
      });
    }
  }

  void _fitRoute(RideRequest request) {
    final controller = _mapController;
    if (controller == null || _routePoints.length < 2 || _hasFittedRoute) {
      return;
    }
    final points = [
      ..._routePoints,
      if (_driverPosition != null) _driverPosition!,
      if (_hasDestinationCoordinates(request))
        LatLng(request.destinationLatitude, request.destinationLongitude),
    ];
    final latitudes = points.map((point) => point.latitude).toList();
    final longitudes = points.map((point) => point.longitude).toList();
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            latitudes.reduce((a, b) => a < b ? a : b),
            longitudes.reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            latitudes.reduce((a, b) => a > b ? a : b),
            longitudes.reduce((a, b) => a > b ? a : b),
          ),
        ),
        56,
      ),
    );
    _hasFittedRoute = true;
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

    final routeRequest = _routeRequest;
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
    if (routeRequest != null && _hasDestinationCoordinates(routeRequest)) {
      markers.add(
        Marker(
          markerId: MarkerId('destination-${routeRequest.id}'),
          position: LatLng(
            routeRequest.destinationLatitude,
            routeRequest.destinationLongitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: routeRequest.destinationAddress,
          ),
        ),
      );
    }
    final polylines = _routePoints.length > 1
        ? {
            Polyline(
              polylineId: const PolylineId('request-route'),
              points: _routePoints,
              color: const Color(0xFF69A8FF),
              width: 5,
            ),
          }
        : <Polyline>{};

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: position, zoom: 14),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_routeRequest != null) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _fitRoute(_routeRequest!),
                  );
                }
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: markers,
              polylines: polylines,
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
            if (_loadingRoute || _routeMessage != null)
              Positioned(
                right: 12,
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
                      _loadingRoute ? 'Loading route...' : _routeMessage!,
                      style: const TextStyle(color: Colors.white70),
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
