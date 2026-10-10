import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:offline_trip/offline_trip.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/offline_identity_service.dart';

class OfflineTripOfferScreen extends StatefulWidget {
  const OfflineTripOfferScreen({
    super.key,
    required this.driver,
    required this.customerName,
    this.customerPhone,
    required this.agreedRatePerKm,
    this.isOffline = false,
    this.existingOffer,
  });
  final Map<String, dynamic> driver;
  final String customerName;
  final String? customerPhone;
  final double agreedRatePerKm;
  final bool isOffline;
  final Map<String, dynamic>? existingOffer;
  @override
  State<OfflineTripOfferScreen> createState() => _OfflineTripOfferScreenState();
}

class _OfflineTripOfferScreenState extends State<OfflineTripOfferScreen> {
  Map<String, dynamic>? _offer;
  String? _error;
  bool _busy = false;
  String get _owner => context.read<AuthProvider>().customer?.id ?? '';
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      if (_owner.isEmpty) {
        throw StateError('Sign in before starting an offline trip.');
      }
      if (!widget.agreedRatePerKm.isFinite || widget.agreedRatePerKm <= 0) {
        throw StateError('Enter a valid agreed rate.');
      }
      final trips = await TripStore.all(_owner);
      if (trips.any((trip) => !trip.completed)) {
        throw StateError(
          'You already have an offline trip. Open it from Offline Trips.',
        );
      }
      final token = (widget.driver['token'] ?? widget.driver['qrToken'] ?? '')
          .toString();
      if (token.isEmpty) {
        throw StateError(
          'Scan the driver’s current QR before making an offer.',
        );
      }
      final pending = await TripStore.pendingOffer(_owner);
      if (pending != null && widget.existingOffer == null && _offer == null) {
        throw StateError(
          'Resume your saved offer from Offline Trips before making another one.',
        );
      }
      final identity = await OfflineIdentityService.cached(_owner);
      final offer = widget.existingOffer == null && _offer == null
          ? <String, dynamic>{
              'version': 1,
              'type': 'TRIP_OFFER',
              'localId': newOfflineId(),
              'driverToken': token,
              'driverId': widget.driver['_id'] ?? widget.driver['id'],
              'driverName': widget.driver['name'] ?? 'Driver',
              'vehicleNumber': widget.driver['vehicleNumber'] ?? '',
              'customerName': widget.customerName,
              'customerPhone': widget.customerPhone ?? '',
              'customerId': _owner,
              'customerIdentity': ?identity,
              'agreedRatePerKm': widget.agreedRatePerKm,
              'timestamp': DateTime.now().toIso8601String(),
            }
          : Map<String, dynamic>.from(_offer ?? widget.existingOffer!);
      if (_offer != null) offer['timestamp'] = DateTime.now().toIso8601String();
      await TripStore.saveOffer(_owner, offer);
      if (mounted) {
        setState(() {
          _offer = offer;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _confirm() async {
    if (_offer == null || _busy) return;
    setState(() => _busy = true);
    try {
      final offer = _offer!;
      final trip = TripSession({
        ...offer,
        'ratePerKm': widget.agreedRatePerKm,
        'startTime': offer['timestamp'],
        'distanceKm': 0.0,
        'status': 'ongoing',
      });
      final qr = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => TripQrScanner(
            title: 'Scan driver acceptance',
            validate: (qr) {
              trip.validateExchange(qr, 'TRIP_ACCEPTED');
              if (qr['customerId'] != _owner ||
                  qr['customerName'] != widget.customerName) {
                throw const FormatException(
                  'This confirmation is for another passenger.',
                );
              }
            },
          ),
        ),
      );
      if (qr == null) return;
      trip.data.addAll({
        'driverId': qr['driverId'],
        'startTime': qr['startTime'],
        'driverName': qr['driverName'],
        'vehicleNumber': qr['vehicleNumber'],
      });
      await TripStore.save(_owner, trip);
      await TripStore.clearOffer(_owner);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OfflineMeterScreen(trip: trip, owner: _owner, driverMode: false),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDestination() async {
    if (_offer == null || _busy) return;
    final choice = await Navigator.push<OfflineDestination>(
      context,
      MaterialPageRoute(
        builder: (_) => OfflineNavigationScreen(
          selectDestination: true,
          destination: OfflineDestination.fromJson(_offer!['destination']),
          profile: _offer!['navigationProfile'] as String? ?? 'tuk',
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final offer = {
      ..._offer!,
      'destination': choice.toJson(),
      'navigationProfile': choice.profile,
    };
    await TripStore.saveOffer(_owner, offer);
    if (mounted) setState(() => _offer = offer);
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this offer?'),
        content: const Text(
          'Only discard if the driver has not accepted it. This does not cancel a trip already started on the driver’s phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep offer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TripStore.clearOffer(_owner);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline Trip Offer')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Show this offer to your driver',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '${widget.driver['name'] ?? 'Driver'} • ${widget.driver['vehicleNumber'] ?? ''}',
          ),
          Text(
            '${widget.customerName} • Rs. ${widget.agreedRatePerKm.toStringAsFixed(2)} / km',
          ),
          const SizedBox(height: 20),
          if (_offer != null)
            OutlinedButton.icon(
              onPressed: _busy ? null : _chooseDestination,
              icon: const Icon(Icons.map),
              label: Text(
                _offer!['destination'] is Map
                    ? 'Destination: ${(_offer!['destination'] as Map)['name']}'
                    : 'Choose destination on offline map',
              ),
            ),
          if (_offer != null)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(data: jsonEncode(_offer), size: 260),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'After the driver accepts, scan their acceptance QR to confirm the same trip and open your offline meter. Offers expire after 30 minutes.',
          ),
          if (_offer != null && _offer!['customerIdentity'] == null)
            const Text(
              'No saved account identity. This trip will remain on this phone; use Prepare for offline while online to enable cloud account linking.',
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _offer == null || _busy ? null : _confirm,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan driver acceptance'),
          ),
          TextButton(
            onPressed: _busy ? null : _prepare,
            child: const Text('Generate a fresh offer'),
          ),
          TextButton(
            onPressed: _busy ? null : _discard,
            child: const Text('Discard unaccepted offer'),
          ),
        ],
      ),
    ),
  );
}
