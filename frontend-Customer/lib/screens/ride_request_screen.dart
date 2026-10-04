import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/google_polyline.dart';
import 'waiting_for_driver_screen.dart';

const _districts = <String, (double, double)>{
  'Ampara': (7.2975, 81.6820),
  'Anuradhapura': (8.3114, 80.4037),
  'Badulla': (6.9934, 81.0550),
  'Batticaloa': (7.7102, 81.6924),
  'Colombo': (6.9271, 79.8612),
  'Galle': (6.0535, 80.2210),
  'Gampaha': (7.0917, 79.9997),
  'Hambantota': (6.1241, 81.1185),
  'Jaffna': (9.6615, 80.0255),
  'Kalutara': (6.5854, 79.9607),
  'Kandy': (7.2906, 80.6337),
  'Kegalle': (7.2513, 80.3464),
  'Kilinochchi': (9.3803, 80.4093),
  'Kurunegala': (7.4867, 80.3647),
  'Mannar': (8.9770, 79.9044),
  'Matale': (7.4675, 80.6234),
  'Matara': (5.9549, 80.5550),
  'Monaragala': (6.8728, 81.3507),
  'Mullaitivu': (9.2671, 80.8142),
  'Nuwara Eliya': (6.9497, 80.7891),
  'Polonnaruwa': (7.9403, 81.0188),
  'Puttalam': (8.0362, 79.8283),
  'Ratnapura': (6.7056, 80.3847),
  'Trincomalee': (8.5874, 81.2152),
  'Vavuniya': (8.7514, 80.4971),
};

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

class RideRequestScreen extends StatefulWidget {
  final Map<String, dynamic> driver;
  final double? suggestedRatePerKm;
  final String? initialPickup;
  final double? initialPickupLat;
  final double? initialPickupLng;
  final String? initialDestination;
  final double? initialDestinationLat;
  final double? initialDestinationLng;

  const RideRequestScreen({
    super.key,
    required this.driver,
    this.suggestedRatePerKm,
    this.initialPickup,
    this.initialPickupLat,
    this.initialPickupLng,
    this.initialDestination,
    this.initialDestinationLat,
    this.initialDestinationLng,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  String _pickup = 'Colombo';
  String _dest = 'Galle';
  bool _loading = false;
  String? _error;

  /// The customer's own per-km offer; null means the listed rate applies.
  late double? _offerRate = widget.suggestedRatePerKm;

  /// The admin can switch negotiation off system-wide.
  bool _negotiationEnabled = true;
  List<LatLng> _routePoints = const [];
  bool _loadingRoute = false;
  String? _routeError;
  double? _routeDistanceKm;

  bool get _hasMapSelection =>
      widget.initialPickupLat != null &&
      widget.initialPickupLng != null &&
      widget.initialDestinationLat != null &&
      widget.initialDestinationLng != null;

  @override
  void initState() {
    super.initState();
    final initialPickup = widget.initialPickup?.trim().toLowerCase();
    if (initialPickup != null && initialPickup.isNotEmpty) {
      final matchedPickup = _districts.keys.where(
        (city) => city.toLowerCase() == initialPickup,
      );
      if (matchedPickup.isNotEmpty) _pickup = matchedPickup.first;
    }

    final initialDestination = widget.initialDestination?.trim().toLowerCase();
    if (initialDestination != null && initialDestination.isNotEmpty) {
      final matchedCity = _districts.keys.where(
        (city) => city.toLowerCase() == initialDestination,
      );
      if (matchedCity.isNotEmpty) _dest = matchedCity.first;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoadRoute());
    _loadNegotiationSetting();
  }

  Future<void> _loadNegotiationSetting() async {
    try {
      final resp = await ApiService.getPublicConfig();
      final enabled = (resp.data as Map?)?['negotiationEnabled'];
      if (!mounted || enabled is! bool) return;
      setState(() {
        _negotiationEnabled = enabled;
        if (!enabled) _offerRate = null;
      });
    } catch (_) {
      // Keep the default: the server still ignores offers when it is off.
    }
  }

  double get _listedRate =>
      (widget.driver['ratePerKm'] as num?)?.toDouble() ?? 0.0;

  double get _rate => _offerRate ?? _listedRate;

  Future<void> _negotiateFare() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NegotiateFareSheet(
        listedRate: _listedRate,
        distanceKm: _distanceKm,
        initialOffer: _offerRate,
      ),
    );
    if (result == null || !mounted) return;
    // A non-positive result means "remove my offer".
    setState(() => _offerRate = result > 0 ? result : null);
  }

  double get _distanceKm {
    final routeDistanceKm = _routeDistanceKm;
    if (routeDistanceKm != null) return routeDistanceKm;

    if (_hasMapSelection) {
      return _haversineKm(
            widget.initialPickupLat!,
            widget.initialPickupLng!,
            widget.initialDestinationLat!,
            widget.initialDestinationLng!,
          ) *
          1.25;
    }

    final (lat1, lng1) = _districts[_pickup]!;
    final (lat2, lng2) = _districts[_dest]!;
    return _haversineKm(lat1, lng1, lat2, lng2) * 1.25;
  }

  double get _estimatedFare => _distanceKm * _rate;

  LatLng get _pickupPoint {
    final (cityLat, cityLng) = _districts[_pickup]!;
    return LatLng(
      widget.initialPickupLat ?? cityLat,
      widget.initialPickupLng ?? cityLng,
    );
  }

  LatLng get _destinationPoint {
    final (cityLat, cityLng) = _districts[_dest]!;
    return LatLng(
      widget.initialDestinationLat ?? cityLat,
      widget.initialDestinationLng ?? cityLng,
    );
  }

  Future<void> _loadRoadRoute() async {
    final pickup = _pickupPoint;
    final destination = _destinationPoint;
    if (pickup.latitude == destination.latitude &&
        pickup.longitude == destination.longitude) {
      return;
    }

    setState(() {
      _loadingRoute = true;
      _routeError = null;
      _routePoints = const [];
    });
    try {
      final response = await ApiService.getDrivingRoute(
        pickupLatitude: pickup.latitude,
        pickupLongitude: pickup.longitude,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final points = decodeGooglePolyline(
        data['encodedPolyline']?.toString() ?? '',
      );
      if (points.length < 2) {
        throw const FormatException('The route contains no map path');
      }
      final distanceMeters = data['distanceMeters'];
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeDistanceKm = distanceMeters is num
            ? distanceMeters.toDouble() / 1000
            : null;
        _loadingRoute = false;
        _routeError = null;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRoute = false;
        _routeError =
            error.error?.toString() ?? 'Could not load the road route';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRoute = false;
        _routeError = 'Could not load the road route';
      });
    }
  }

  Future<void> _sendRequest() async {
    if (context.read<TripProvider>().hasOngoingTrip) {
      setState(() {
        _error =
            'You already have an active ride. Complete or cancel it before booking another ride.';
      });
      return;
    }

    final sameMapPoint =
        _hasMapSelection &&
        widget.initialPickupLat == widget.initialDestinationLat &&
        widget.initialPickupLng == widget.initialDestinationLng;
    if ((!_hasMapSelection && _pickup == _dest) || sameMapPoint) {
      setState(() => _error = 'Pickup and destination must be different.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (cityPickupLat, cityPickupLng) = _districts[_pickup]!;
      final (cityDestLat, cityDestLng) = _districts[_dest]!;
      final pickupLat = widget.initialPickupLat ?? cityPickupLat;
      final pickupLng = widget.initialPickupLng ?? cityPickupLng;
      final destLat = widget.initialDestinationLat ?? cityDestLat;
      final destLng = widget.initialDestinationLng ?? cityDestLng;
      final pickupAddress = widget.initialPickup ?? _pickup;
      final destAddress = widget.initialDestination ?? _dest;
      final driverId = widget.driver['_id'] as String;

      final resp = await ApiService.createRideRequest({
        'driverId': driverId,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'pickupAddress': pickupAddress,
        'destLat': destLat,
        'destLng': destLng,
        'destAddress': destAddress,
        'estimatedDistanceKm': double.parse(_distanceKm.toStringAsFixed(2)),
        if (_offerRate != null) 'suggestedRatePerKm': _offerRate,
      });

      final requestId = resp.data['_id'] as String;
      // The server's quote is what will be charged: carry it forward rather
      // than the rate this screen was opened with.
      final quotedRate =
          (resp.data['driverRatePerKm'] as num?)?.toDouble() ?? _listedRate;
      final sentOffer = (resp.data['suggestedRatePerKm'] as num?)?.toDouble();
      if (!mounted) return;
      if (_offerRate != null && sentOffer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your offer was not applied. The request was sent at the current rate of Rs. ${quotedRate.toStringAsFixed(0)} / km.',
            ),
          ),
        );
      }
      await context.read<TripProvider>().startDriverSearch(
        pickupAddress: pickupAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        destinationAddress: destAddress,
        destinationLat: destLat,
        destinationLng: destLng,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingForDriverScreen(
            requestId: requestId,
            driver: widget.driver,
            distanceKm: _distanceKm,
            ratePerKm: sentOffer ?? quotedRate,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            destLat: destLat,
            destLng: destLng,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fare = _estimatedFare;
    final dist = _distanceKm;
    final driverName = widget.driver['name'] as String? ?? 'Selected driver';
    final vehicle = widget.driver['vehicleNumber'] as String? ?? 'Taxi';
    final vehicleType = widget.driver['vehicleType'] as String? ?? 'Taxi';
    final pickupAddress = widget.initialPickup ?? _pickup;
    final destinationAddress = widget.initialDestination ?? _dest;
    final pickupPoint = _pickupPoint;
    final destinationPoint = _destinationPoint;
    final center = LatLng(
      (pickupPoint.latitude + destinationPoint.latitude) / 2,
      (pickupPoint.longitude + destinationPoint.longitude) / 2,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 13),
            markers: {
              Marker(
                markerId: const MarkerId('pickup'),
                position: pickupPoint,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
              Marker(
                markerId: const MarkerId('destination'),
                position: destinationPoint,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
              Marker(
                markerId: const MarkerId('driver'),
                position: center,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
              ),
            },
            polylines: _routePoints.length < 2
                ? const <Polyline>{}
                : {
                    Polyline(
                      polylineId: const PolylineId('ride-preview'),
                      points: _routePoints,
                      width: 5,
                      color: AppTheme.primary,
                      jointType: JointType.round,
                      startCap: Cap.roundCap,
                      endCap: Cap.roundCap,
                    ),
                  },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _FloatingMapButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                  const _MapPill(label: 'Cash ride'),
                ],
              ),
            ),
          ),
          if (_loadingRoute || _routeError != null)
            Positioned(
              top: 78,
              left: 16,
              right: 16,
              child: _MapPill(
                label: _loadingRoute
                    ? 'Calculating road route...'
                    : _routeError!,
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: _RideArrivalPanel(
                driverName: driverName,
                vehicle: vehicle,
                vehicleType: vehicleType,
                pickupAddress: pickupAddress,
                destinationAddress: destinationAddress,
                distance: '${dist.toStringAsFixed(1)} km',
                rate: 'Rs. ${_rate.toStringAsFixed(0)} / km',
                fare: 'Rs. ${fare.toStringAsFixed(0)}',
                error: _error,
                loading: _loading,
                onSendRequest: _sendRequest,
                canNegotiate: _negotiationEnabled && _listedRate > 0,
                hasOffer: _offerRate != null,
                listedFare:
                    'Rs. ${(dist * _listedRate).toStringAsFixed(0)}',
                onNegotiate: _negotiateFare,
                onShareTrip: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Trip sharing will be available after the driver accepts.',
                      ),
                    ),
                  );
                },
                onCallDriver: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Driver phone will be available after acceptance.',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppTheme.background),
        tooltip: tooltip,
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  const _MapPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RideArrivalPanel extends StatelessWidget {
  const _RideArrivalPanel({
    required this.driverName,
    required this.vehicle,
    required this.vehicleType,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.distance,
    required this.rate,
    required this.fare,
    required this.loading,
    required this.onSendRequest,
    required this.onShareTrip,
    required this.onCallDriver,
    required this.canNegotiate,
    required this.hasOffer,
    required this.listedFare,
    required this.onNegotiate,
    this.error,
  });

  final String driverName;
  final String vehicle;
  final String vehicleType;
  final String pickupAddress;
  final String destinationAddress;
  final String distance;
  final String rate;
  final String fare;
  final bool loading;
  final String? error;
  final VoidCallback onSendRequest;
  final VoidCallback onShareTrip;
  final VoidCallback onCallDriver;
  final bool canNegotiate;
  final bool hasOffer;
  final String listedFare;
  final VoidCallback onNegotiate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      // Keeps the panel usable on short screens now that it holds more rows.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Review your ride',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.16),
                  child: Text(
                    driverName.trim().isEmpty
                        ? 'D'
                        : driverName.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$vehicleType - $vehicle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.mutedText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: AppTheme.primary, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '4.8',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RouteStop(
              icon: Icons.trip_origin,
              color: AppTheme.successGreen,
              label: 'Pickup',
              value: pickupAddress,
            ),
            const SizedBox(height: 10),
            _RouteStop(
              icon: Icons.location_on,
              color: AppTheme.dangerRed,
              label: 'Drop off',
              value: destinationAddress,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(label: 'Distance', value: distance),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: hasOffer ? 'Your offer' : 'Rate',
                    value: rate,
                  ),
                ),
                Expanded(
                  child: _MiniMetric(label: 'Fare', value: fare),
                ),
              ],
            ),
            if (canNegotiate) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: loading ? null : onNegotiate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warningOrange.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        color: AppTheme.warningOrange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasOffer
                                  ? 'Your offer will be sent to the driver'
                                  : 'Negotiate fare',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasOffer
                                  ? 'Listed fare $listedFare · tap to change'
                                  : 'Ask the driver for a lower rate',
                              style: const TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.payments_outlined, color: AppTheme.successGreen),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cash payment only',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppTheme.dangerRed)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareTrip,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share trip'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCallDriver,
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call driver'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: loading ? null : onSendRequest,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      hasOffer
                          ? 'Send request with my offer'
                          : 'Send ride request',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the customer propose a per-km rate below the listed one. Pops with the
/// offer, or with 0 when the customer removes an existing offer.
class _NegotiateFareSheet extends StatefulWidget {
  const _NegotiateFareSheet({
    required this.listedRate,
    required this.distanceKm,
    this.initialOffer,
  });

  final double listedRate;
  final double distanceKm;
  final double? initialOffer;

  @override
  State<_NegotiateFareSheet> createState() => _NegotiateFareSheetState();
}

class _NegotiateFareSheetState extends State<_NegotiateFareSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialOffer == null ? '' : _format(widget.initialOffer!),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  double? get _value => double.tryParse(_controller.text.trim());

  String? get _error {
    if (_controller.text.trim().isEmpty) return null;
    final value = _value;
    if (value == null || value <= 0) return 'Enter a valid rate';
    if (value >= widget.listedRate) {
      return 'Must be lower than Rs. ${_format(widget.listedRate)} / km';
    }
    return null;
  }

  void _usePercentOff(int percent) {
    final rate = (widget.listedRate * (100 - percent) / 100).floorToDouble();
    _controller.text = _format(rate);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final error = _error;
    final valid = value != null && error == null && value > 0;
    final listedFare = widget.distanceKm * widget.listedRate;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Negotiate fare',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Listed rate Rs. ${_format(widget.listedRate)} / km · fare Rs. ${listedFare.toStringAsFixed(0)}',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Your offer per km',
              prefixText: 'Rs. ',
              suffixText: '/ km',
              errorText: error,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final percent in const [5, 10, 15])
                ActionChip(
                  label: Text('$percent% off'),
                  onPressed: () => _usePercentOff(percent),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            valid
                ? 'Fare at your offer: Rs. ${(widget.distanceKm * value).toStringAsFixed(0)} '
                      '(Rs. ${(listedFare - widget.distanceKm * value).toStringAsFixed(0)} less)'
                : 'The driver can accept your offer, decline, or send their own offer.',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: valid ? () => Navigator.pop(context, value) : null,
            child: const Text('Use this offer'),
          ),
          if (widget.initialOffer != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, 0.0),
              child: const Text('Remove my offer'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
