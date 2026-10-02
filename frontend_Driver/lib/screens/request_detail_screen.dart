import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/google_polyline.dart';
import '../widgets/app_widgets.dart';
import 'driver_navigation_screen.dart';

const _pickupColor = Color(0xFF34D399);
const _destinationColor = Color(0xFFF87171);

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.request});

  final RideRequest request;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _acceptSuggestedRate = false;
  bool _rejecting = false;
  GoogleMapController? _mapController;

  LatLng? _driverPosition;
  bool _locatingDriver = true;

  // Driver -> customer pickup
  List<LatLng> _approachRoute = const [];
  double? _approachDistanceKm;
  String? _approachDuration;

  // Customer pickup -> destination
  List<LatLng> _tripRoute = const [];
  String? _tripDuration;

  RideRequest get _request => widget.request;
  LatLng get _pickup => LatLng(_request.pickupLatitude, _request.pickupLongitude);
  LatLng get _destination =>
      LatLng(_request.destinationLatitude, _request.destinationLongitude);
  bool get _hasPickup => _isValid(_pickup);
  bool get _hasDestination => _isValid(_destination);

  static bool _isValid(LatLng p) => p.latitude != 0 || p.longitude != 0;

  @override
  void initState() {
    super.initState();
    _loadTripRoute();
    _locateDriver();
  }

  Future<void> _locateDriver() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
      if (!mounted) return;
      final driver = LatLng(position.latitude, position.longitude);
      setState(() {
        _driverPosition = driver;
        if (_hasPickup) {
          _approachDistanceKm = Geolocator.distanceBetween(
                driver.latitude,
                driver.longitude,
                _pickup.latitude,
                _pickup.longitude,
              ) /
              1000;
        }
      });
      _fitMap();
      _loadApproachRoute(driver);
    } catch (_) {
      // Map still works without the driver's position.
    } finally {
      if (mounted) setState(() => _locatingDriver = false);
    }
  }

  Future<void> _loadApproachRoute(LatLng driver) async {
    if (!_hasPickup) return;
    try {
      final data = await context.read<AuthProvider>().api.getDrivingRoute(
            pickupLatitude: driver.latitude,
            pickupLongitude: driver.longitude,
            destinationLatitude: _pickup.latitude,
            destinationLongitude: _pickup.longitude,
          );
      if (!mounted) return;
      final meters = data['distanceMeters'];
      setState(() {
        _approachRoute = _decode(data['encodedPolyline']);
        if (meters is num) _approachDistanceKm = meters / 1000;
        _approachDuration = _formatDuration(data['duration']);
      });
      _fitMap();
    } catch (_) {
      // Fall back to the straight-line distance already shown.
    }
  }

  Future<void> _loadTripRoute() async {
    if (!_hasPickup || !_hasDestination) return;
    try {
      final data = await context.read<AuthProvider>().api.getDrivingRoute(
            pickupLatitude: _pickup.latitude,
            pickupLongitude: _pickup.longitude,
            destinationLatitude: _destination.latitude,
            destinationLongitude: _destination.longitude,
          );
      if (!mounted) return;
      setState(() {
        _tripRoute = _decode(data['encodedPolyline']);
        _tripDuration = _formatDuration(data['duration']);
      });
      _fitMap();
    } catch (_) {
      // Straight markers are still shown without the road route.
    }
  }

  List<LatLng> _decode(Object? encoded) {
    try {
      return decodeGooglePolyline(encoded?.toString() ?? '')
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String? _formatDuration(Object? value) {
    final seconds = int.tryParse(value?.toString().replaceFirst('s', '') ?? '');
    if (seconds == null) return null;
    final minutes = (seconds / 60).round();
    if (minutes < 1) return '< 1 min';
    return minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  void _fitMap() {
    final controller = _mapController;
    if (controller == null) return;
    final points = <LatLng>[
      ?_driverPosition,
      if (_hasPickup) _pickup,
      if (_hasDestination) _destination,
      ..._approachRoute,
      ..._tripRoute,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        56,
      ),
    );
  }

  Future<void> _accept(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final response = await auth.api.respondToRequest(
        requestId: _request.id,
        action: 'accept',
        agreedRatePerKm:
            _acceptSuggestedRate ? _request.suggestedRatePerKm : null,
      );
      final trip = TripRecord.fromJson(_readTrip(response));
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => DriverNavigationScreen(
            trip: trip,
            request: _request,
            receiptNumber: _readReceipt(response),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Unable to accept request')),
      );
    }
  }

  Future<void> _reject(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _rejecting = true);
    try {
      await auth.api.respondToRequest(requestId: _request.id, action: 'reject');
      if (!mounted) return;
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Unable to reject request')),
      );
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mapHeight = MediaQuery.sizeOf(context).height * 0.38;
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Ride Request')),
      child: Column(
        children: [
          SizedBox(height: mapHeight, child: _buildMap()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCustomerCard(),
                  const SizedBox(height: 12),
                  _buildRouteCard(),
                  const SizedBox(height: 12),
                  _buildFareCard(),
                ],
              ),
            ),
          ),
          _buildActionBar(auth),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>{
      if (_driverPosition != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      if (_hasPickup)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Pickup · ${_request.customerName}',
            snippet: _request.pickupAddress,
          ),
        ),
      if (_hasDestination)
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _request.destinationAddress,
          ),
        ),
    };

    final approach = _approachRoute.length > 1
        ? _approachRoute
        : [
            if (_driverPosition != null && _hasPickup) ...[
              _driverPosition!,
              _pickup,
            ],
          ];
    final trip = _tripRoute.length > 1
        ? _tripRoute
        : [if (_hasPickup && _hasDestination) ...[_pickup, _destination]];

    final polylines = <Polyline>{
      if (approach.length > 1)
        Polyline(
          polylineId: const PolylineId('approach'),
          points: approach,
          color: AppTheme.accent,
          width: 4,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ),
      if (trip.length > 1)
        Polyline(
          polylineId: const PolylineId('trip'),
          points: trip,
          color: _pickupColor,
          width: 5,
        ),
    };

    final initialTarget = _hasPickup
        ? _pickup
        : (_hasDestination ? _destination : const LatLng(6.9271, 79.8612));

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: 13),
          onMapCreated: (controller) {
            _mapController = controller;
            Future.delayed(const Duration(milliseconds: 300), _fitMap);
          },
          markers: markers,
          polylines: polylines,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _MapLegend(showDriver: _driverPosition != null),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'request-fit-map',
            backgroundColor: AppTheme.surfaceAlt,
            foregroundColor: Colors.white,
            onPressed: _fitMap,
            tooltip: 'Show full route',
            child: const Icon(Icons.zoom_out_map_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard() {
    final String awayText;
    if (_approachDistanceKm != null) {
      awayText = _approachDuration == null
          ? '${_approachDistanceKm!.toStringAsFixed(1)} km away'
          : '${_approachDistanceKm!.toStringAsFixed(1)} km · $_approachDuration away';
    } else if (_locatingDriver) {
      awayText = 'Finding your location…';
    } else {
      awayText = 'Distance to customer unavailable';
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.accent.withValues(alpha: 0.18),
                child: Text(
                  _request.customerName.isEmpty
                      ? '?'
                      : _request.customerName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _request.customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Waiting for a driver',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, color: AppTheme.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer is',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      Text(
                        awayText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_locatingDriver)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Trip route'),
          const SizedBox(height: 12),
          _RouteStop(
            color: _pickupColor,
            icon: Icons.radio_button_checked,
            label: 'PICKUP',
            address: _request.pickupAddress,
            showLine: true,
          ),
          _RouteStop(
            color: _destinationColor,
            icon: Icons.location_on_rounded,
            label: 'DROP-OFF',
            address: _request.destinationAddress,
            showLine: false,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.straighten_rounded,
                  label: 'Trip distance',
                  value: '${_request.estimatedDistanceKm.toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Trip time',
                  value: _tripDuration ?? '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    final suggestedRate = _request.suggestedRatePerKm;
    final useSuggested = _acceptSuggestedRate && suggestedRate != null;
    final activeRate = useSuggested ? suggestedRate : _request.driverRatePerKm;
    final fare = _request.fareAt(activeRate);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Estimated fare'),
          const SizedBox(height: 8),
          Text(
            'Rs. ${fare.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${_request.estimatedDistanceKm.toStringAsFixed(1)} km × Rs. ${activeRate.toStringAsFixed(2)} / km'
            '${useSuggested ? '  (customer rate)' : '  (your rate)'}',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          if (suggestedRate != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RateOption(
                    title: 'Your rate',
                    rate: _request.driverRatePerKm,
                    fare: _request.fareAt(_request.driverRatePerKm),
                    selected: !_acceptSuggestedRate,
                    onTap: () => setState(() => _acceptSuggestedRate = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RateOption(
                    title: 'Customer offer',
                    rate: suggestedRate,
                    fare: _request.fareAt(suggestedRate),
                    selected: _acceptSuggestedRate,
                    onTap: () => setState(() => _acceptSuggestedRate = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the rate you want to accept this ride with.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar(AuthProvider auth) {
    final busy = auth.busy || _rejecting;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _reject(auth),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _destinationColor,
                  side: BorderSide(
                    color: _destinationColor.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _rejecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close_rounded),
                label: const Text(
                  'Reject',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: busy ? null : () => _accept(auth),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: auth.busy && !_rejecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text(
                  'Accept ride',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _readTrip(Map<String, dynamic> response) {
    final trip = response['trip'];
    if (trip is Map<String, dynamic>) return trip;
    if (trip is Map) return Map<String, dynamic>.from(trip);
    return response;
  }

  String? _readReceipt(Map<String, dynamic> response) {
    final receipt = response['receipt'];
    if (receipt is String && receipt.isNotEmpty) return receipt;
    final receiptNumber = response['receiptNumber'];
    if (receiptNumber is String && receiptNumber.isNotEmpty) {
      return receiptNumber;
    }
    if (receiptNumber != null) return receiptNumber.toString();
    return null;
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.color,
    required this.icon,
    required this.label,
    required this.address,
    required this.showLine,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String address;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.white24,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 16 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.isEmpty ? 'Not specified' : address,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateOption extends StatelessWidget {
  const _RateOption({
    required this.title,
    required this.rate,
    required this.fare,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final double rate;
  final double fare;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.18)
              : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.accent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? AppTheme.accent : Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Rs. ${rate.toStringAsFixed(2)} / km',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Fare Rs. ${fare.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.showDriver});

  final bool showDriver;

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xDD0E1422),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDriver) item(AppTheme.accent, 'You'),
          item(_pickupColor, 'Customer pickup'),
          item(_destinationColor, 'Drop-off'),
        ],
      ),
    );
  }
}
