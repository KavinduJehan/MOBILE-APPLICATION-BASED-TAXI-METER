import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:customer_app/offline/offline_trip.dart';
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
              'navigationProfile': 'car',
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
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            }
          : Map<String, dynamic>.from(_offer ?? widget.existingOffer!);
      if (_offer != null) {
        offer['timestamp'] = DateTime.now().toUtc().toIso8601String();
      }
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
      final trips = await TripStore.all(_owner);
      if (trips.any((trip) => !trip.completed)) {
        throw StateError('Resume your active trip from Offline Trips.');
      }
      final trip = TripSession({
        ...offer,
        'ratePerKm': widget.agreedRatePerKm,
        'startTime': offer['timestamp'],
        'distanceKm': 0.0,
        'status': 'ongoing',
      });
      if (!mounted) return;
      final qr = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => TripQrScanner(
            title: 'Scan driver acceptance',
            hint: 'Scan the confirmation QR on the driver\u2019s phone',
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
          profile: 'car',
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final offer = {
      ..._offer!,
      'destination': choice.toJson(),
      'navigationProfile': 'car',
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
            style: TextButton.styleFrom(foregroundColor: OfflineUi.danger),
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
  Widget build(BuildContext context) {
    final destination = _offer?['destination'];
    final vehicle = (widget.driver['vehicleNumber'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Trip Offer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OfflineHandshakeSteps(stage: 1),
              const OfflineHeader(
                icon: Icons.qr_code_2_rounded,
                title: 'Show this to your driver',
                subtitle: 'They scan it, accept, then show you a confirmation.',
              ),
              const SizedBox(height: 16),
              OfflinePanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    OfflineInfoRow(
                      icon: Icons.directions_car_rounded,
                      label: 'Driver',
                      value:
                          '${widget.driver['name'] ?? 'Driver'}${vehicle.isEmpty ? '' : ' • $vehicle'}',
                    ),
                    OfflineInfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Agreed rate',
                      value:
                          'Rs. ${widget.agreedRatePerKm.toStringAsFixed(2)} / km',
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_offer != null)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseDestination,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    alignment: Alignment.centerLeft,
                    side: const BorderSide(color: OfflineUi.stroke),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(
                    destination is Map
                        ? 'Destination: ${destination['name']}'
                        : 'Add a destination (optional)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 16),
              if (_offer != null)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(data: jsonEncode(_offer), size: 250),
                  ),
                )
              else if (_error == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                OfflineNotice(
                  _error!.replaceFirst(RegExp(r'^(Bad state|Exception): '), ''),
                  tone: OfflineTone.danger,
                ),
                const SizedBox(height: 12),
              ],
              if (_offer != null && _offer!['customerIdentity'] == null) ...[
                const OfflineNotice(
                  'Saved on this phone only. Prepare your account while online to enable syncing.',
                  tone: OfflineTone.warning,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _offer == null || _busy ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Driver accepted? Scan confirmation'),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _prepare,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Fresh QR'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _discard,
                      style: TextButton.styleFrom(
                        foregroundColor: OfflineUi.danger,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Discard offer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
