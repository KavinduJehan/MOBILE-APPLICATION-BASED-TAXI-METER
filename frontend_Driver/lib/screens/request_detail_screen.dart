import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../services/counter_offer_tracker.dart';
import '../services/ride_alert_service.dart';
import '../theme/app_theme.dart';
import '../utils/google_polyline.dart';
import '../widgets/app_widgets.dart';
import 'driver_navigation_screen.dart';

const _pickupColor = Color(0xFF34D399);
const _destinationColor = Color(0xFFF87171);
const _offerColor = Color(0xFFFBBF24);

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.request});

  final RideRequest request;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  // Kept as state because sending a counter-offer changes its negotiation
  // status while this screen stays open.
  late RideRequest _request = widget.request;
  bool _accepting = false;
  bool _rejecting = false;
  bool _countering = false;
  bool _resolved = false;
  Timer? _answerPoll;
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

  LatLng get _pickup => LatLng(_request.pickupLatitude, _request.pickupLongitude);
  LatLng get _destination =>
      LatLng(_request.destinationLatitude, _request.destinationLongitude);
  bool get _hasPickup => _isValid(_pickup);
  bool get _hasDestination => _isValid(_destination);

  static bool _isValid(LatLng p) => p.latitude != 0 || p.longitude != 0;

  @override
  void initState() {
    super.initState();
    // The driver is looking at it now: stop the ringing alert.
    RideAlertService.instance.cancelFor(widget.request.id);
    CounterOfferTracker.instance.activeRequestId = widget.request.id;
    if (_request.awaitingCustomer) _watchForCustomerAnswer();
    _loadTripRoute();
    _locateDriver();
  }

  @override
  void dispose() {
    _answerPoll?.cancel();
    final tracker = CounterOfferTracker.instance;
    if (tracker.activeRequestId == widget.request.id) {
      tracker.activeRequestId = null;
    }
    super.dispose();
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

  void _openNavigation(TripRecord trip, {String? receiptNumber}) {
    _resolved = true;
    _answerPoll?.cancel();
    CounterOfferTracker.instance.remove(_request.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DriverNavigationScreen(
          trip: trip,
          request: _request,
          receiptNumber: receiptNumber,
        ),
      ),
    );
  }

  Future<void> _accept(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _accepting = true);
    try {
      final response = await auth.api.respondToRequest(
        requestId: _request.id,
        action: 'accept',
      );
      final trip = TripRecord.fromJson(_readTrip(response));
      if (!mounted) return;
      _openNavigation(trip, receiptNumber: _readReceipt(response));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_errorText(error, 'Unable to accept request'))),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _reject(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _rejecting = true);
    try {
      await auth.api.respondToRequest(requestId: _request.id, action: 'reject');
      _resolved = true;
      _answerPoll?.cancel();
      CounterOfferTracker.instance.remove(_request.id);
      if (!mounted) return;
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_errorText(error, 'Unable to reject request'))),
      );
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  /// Lets the driver answer the customer's offer with a rate of their own.
  Future<void> _sendCounterOffer(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final counterRate = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CounterOfferSheet(request: _request),
    );
    if (counterRate == null || !mounted) return;

    setState(() => _countering = true);
    try {
      await auth.api.respondToRequest(
        requestId: _request.id,
        action: 'counter',
        counterRatePerKm: counterRate,
      );
      if (!mounted) return;
      setState(() => _request = _request.withCounterOffer(counterRate));
      CounterOfferTracker.instance.add(_request);
      _watchForCustomerAnswer();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_errorText(error, 'Unable to send your offer'))),
      );
    } finally {
      if (mounted) setState(() => _countering = false);
    }
  }

  void _watchForCustomerAnswer() {
    _answerPoll?.cancel();
    _answerPoll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkCustomerAnswer(),
    );
  }

  Future<void> _checkCustomerAnswer() async {
    if (_resolved || !mounted) return;
    late final Map<String, dynamic> data;
    try {
      data = await context.read<AuthProvider>().api.getRequestStatus(
        _request.id,
      );
    } catch (_) {
      return; // Offline or server hiccup: try again on the next tick.
    }
    if (_resolved || !mounted) return;
    final status = data['status']?.toString() ?? 'pending';
    if (status == 'pending') return;

    final trip = data['trip'];
    if (status == 'accepted' && trip is Map) {
      _openNavigation(TripRecord.fromJson(Map<String, dynamic>.from(trip)));
      return;
    }

    _resolved = true;
    _answerPoll?.cancel();
    CounterOfferTracker.instance.remove(_request.id);
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Offer declined',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${_request.customerName} did not accept your fare offer. This request is closed.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) navigator.pop();
  }

  String _errorText(Object error, String fallback) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
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
    final offer = _request.suggestedRatePerKm;
    final listedRate = _request.driverRatePerKm;
    final distance = _request.estimatedDistanceKm.toStringAsFixed(1);

    if (offer == null) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelTitle('Estimated fare'),
            const SizedBox(height: 8),
            Text(
              'Rs. ${_request.fareAt(listedRate).toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$distance km × Rs. ${listedRate.toStringAsFixed(2)} / km',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final counter = _request.counterRatePerKm;
    final waiting = _request.awaitingCustomer && counter != null;
    final saving = _request.fareAt(listedRate) - _request.fareAt(offer);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_outlined, color: _offerColor, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: _PanelTitle('Fare negotiation')),
              Text(
                '$distance km',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RateTile(
                  title: 'Listed rate',
                  rate: listedRate,
                  fare: _request.fareAt(listedRate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RateTile(
                  title: 'Customer offers',
                  rate: offer,
                  fare: _request.fareAt(offer),
                  color: _offerColor,
                ),
              ),
            ],
          ),
          if (waiting) ...[
            const SizedBox(height: 10),
            _RateTile(
              title: 'Your offer',
              rate: counter,
              fare: _request.fareAt(counter),
              color: AppTheme.accent,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Waiting for ${_request.customerName} to answer your offer…',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'The customer is asking for Rs. ${saving.toStringAsFixed(2)} off the listed fare. '
              'Accept it, send your own offer, or reject the request.',
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar(AuthProvider auth) {
    final busy = _accepting || _rejecting || _countering;
    final offer = _request.suggestedRatePerKm;
    final waiting = _request.awaitingCustomer;

    Widget spinner([Color? color]) => SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: color == null ? null : AlwaysStoppedAnimation(color),
      ),
    );

    Widget rejectButton(String label) => SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: busy ? null : () => _reject(auth),
        style: OutlinedButton.styleFrom(
          foregroundColor: _destinationColor,
          side: BorderSide(color: _destinationColor.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _rejecting ? spinner() : const Icon(Icons.close_rounded),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );

    Widget acceptButton(String label) => SizedBox(
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
        icon: _accepting
            ? spinner(Colors.white)
            : const Icon(Icons.check_rounded),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );

    final Widget content;
    if (waiting) {
      // Counter-offer sent: the only thing left to do is withdraw.
      content = SizedBox(
        width: double.infinity,
        child: rejectButton('Withdraw offer and reject'),
      );
    } else if (offer != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          acceptButton(
            'Accept offer · Rs. ${_request.fareAt(offer).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: rejectButton('Reject')),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _sendCounterOffer(auth),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _offerColor,
                      side: BorderSide(
                        color: _offerColor.withValues(alpha: 0.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _countering
                        ? spinner(_offerColor)
                        : const Icon(Icons.swap_vert_rounded),
                    label: const Text(
                      'My offer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(flex: 2, child: rejectButton('Reject')),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: acceptButton('Accept ride')),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: content,
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

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.title,
    required this.rate,
    required this.fare,
    this.color,
  });

  final String title;
  final double rate;
  final double fare;

  /// Highlights the tile; null renders it as a neutral reference value.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent == null
            ? AppTheme.surfaceAlt
            : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent == null
              ? Colors.white12
              : accent.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent ?? Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs. ${rate.toStringAsFixed(2)} / km',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Fare Rs. ${fare.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet where the driver enters a counter-offer between the
/// customer's offer and the listed rate. Pops with the chosen rate.
class _CounterOfferSheet extends StatefulWidget {
  const _CounterOfferSheet({required this.request});

  final RideRequest request;

  @override
  State<_CounterOfferSheet> createState() => _CounterOfferSheetState();
}

class _CounterOfferSheetState extends State<_CounterOfferSheet> {
  late final TextEditingController _controller;

  double get _offer => widget.request.suggestedRatePerKm ?? 0;
  double get _listed => widget.request.driverRatePerKm;
  double get _midpoint => double.parse(((_offer + _listed) / 2).toStringAsFixed(0));

  @override
  void initState() {
    super.initState();
    // Start from the middle when it is a valid counter, else the listed rate.
    final start = _midpoint > _offer && _midpoint <= _listed ? _midpoint : _listed;
    _controller = TextEditingController(text: _format(start));
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
    final value = _value;
    if (value == null) return 'Enter a rate per km';
    if (value <= _offer) {
      return 'Must be more than the customer\'s Rs. ${_format(_offer)}';
    }
    if (value > _listed) {
      return 'Cannot be more than the listed Rs. ${_format(_listed)}';
    }
    return null;
  }

  void _set(double value) {
    _controller.text = _format(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final error = _error;
    final quickRates = <double>{
      if (_midpoint > _offer && _midpoint < _listed) _midpoint,
      _listed,
    };

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
            'Send your offer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer offers Rs. ${_format(_offer)} / km · listed rate Rs. ${_format(_listed)} / km',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Your rate per km',
              prefixText: 'Rs. ',
              suffixText: '/ km',
              errorText: error,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final rate in quickRates)
                ActionChip(
                  label: Text(
                    rate == _listed
                        ? 'Listed · Rs. ${_format(rate)}'
                        : 'Meet halfway · Rs. ${_format(rate)}',
                  ),
                  onPressed: () => _set(rate),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value != null && error == null
                ? 'Fare at your offer: Rs. ${widget.request.fareAt(value).toStringAsFixed(2)} '
                      'for ${widget.request.estimatedDistanceKm.toStringAsFixed(1)} km'
                : 'The customer has to agree before the trip starts.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: error == null && value != null
                  ? () => Navigator.pop(context, value)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Send offer to customer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
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
