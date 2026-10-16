import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../services/api_service.dart';
import '../services/customer_socket_service.dart';
import '../theme.dart';
import 'trip_progress_screen.dart';

class WaitingForDriverScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> driver;
  final double distanceKm;
  final double ratePerKm;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  const WaitingForDriverScreen({
    super.key,
    required this.requestId,
    required this.driver,
    required this.distanceKm,
    required this.ratePerKm,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
  });

  @override
  State<WaitingForDriverScreen> createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen> {
  Timer? _timer;
  String _status = 'pending';
  String? _error;
  double? _agreedRate;
  bool _handled = false;

  // Fare negotiation
  double? _myOffer; // the rate this customer asked for
  double? _counterRate; // the driver's counter-offer, waiting for an answer
  bool _answering = false;
  bool _declinedByMe = false;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _poll(); // immediate first check
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  void _initSocket() {
    CustomerSocketService.instance.listenToRequest(
      requestId: widget.requestId,
      onResponse: _onSocketResponse,
    );
  }

  void _onSocketResponse(Map<String, dynamic> data) {
    if (!mounted || _handled) return;
    final status = data['status'] as String? ?? '';
    if (status == 'accepted') {
      _handleAccepted(data);
    } else if (status == 'rejected') {
      _handleRejected();
    } else if (status == 'countered') {
      final counter = (data['counterRatePerKm'] as num?)?.toDouble();
      if (counter != null) {
        setState(() {
          _counterRate = counter;
          _myOffer =
              (data['suggestedRatePerKm'] as num?)?.toDouble() ?? _myOffer;
        });
      }
    }
  }

  /// Sends the customer's answer to the driver's counter-offer.
  Future<void> _answerCounterOffer(bool accept) async {
    if (_answering || _handled) return;
    setState(() {
      _answering = true;
      _error = null;
    });
    try {
      final resp = await ApiService.respondToCounterOffer(
        widget.requestId,
        accept ? 'accept' : 'reject',
      );
      if (!mounted) return;
      if (!accept) {
        _declinedByMe = true;
        await _handleRejected();
        return;
      }
      final data = Map<String, dynamic>.from(resp.data as Map);
      final request = data['rideRequest'];
      await _handleAccepted({
        'status': 'accepted',
        'trip': data['trip'],
        if (request is Map) ...{
          'agreedRatePerKm': request['agreedRatePerKm'],
          'pickupAddress': request['pickupAddress'],
          'destAddress': request['destAddress'],
          'pickupLat': request['pickupLat'],
          'pickupLng': request['pickupLng'],
          'destLat': request['destLat'],
          'destLng': request['destLng'],
        },
      });
    } catch (_) {
      if (mounted && !_handled) {
        setState(() => _error = 'Could not send your answer. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    CustomerSocketService.instance.disconnect();
    super.dispose();
  }

  Future<void> _handleAccepted(Map<String, dynamic> data) async {
    if (_handled) return;
    _handled = true;
    _timer?.cancel();
    CustomerSocketService.instance.disconnect();

    final agreedRate = (data['agreedRatePerKm'] as num?)?.toDouble();
    if (mounted) {
      setState(() {
        _status = 'accepted';
        _agreedRate = agreedRate;
        _error = null;
      });
    }

    await context.read<TripProvider>().clearPendingSearch();
    if (!mounted) return;

    final rawTrip = data['trip'];
    final tripObj = rawTrip is Map ? Map<String, dynamic>.from(rawTrip) : null;
    final totalFare = (tripObj?['totalFare'] as num?)?.toDouble();
    final effectiveRate = agreedRate ?? widget.ratePerKm;
    final trip = tripObj == null
        ? null
        : TripModel.fromJson({
            ...tripObj,
            'driver': data['driver'] ?? widget.driver,
            'driverName': widget.driver['name'],
            'vehicleNumber': widget.driver['vehicleNumber'],
            'startLocation':
                tripObj['startLocation'] ?? data['pickupAddress'],
            'endLocation': tripObj['endLocation'] ?? data['destAddress'],
            'distanceKm': tripObj['distanceKm'] ?? widget.distanceKm,
            'ratePerKm': tripObj['ratePerKm'] ?? effectiveRate,
            'totalFare':
                tripObj['totalFare'] ??
                double.parse(
                  (widget.distanceKm * effectiveRate).toStringAsFixed(2),
                ),
          });

    if (trip != null) {
      context.read<TripProvider>().upsertTrip(trip);
    }

    final pLat = widget.pickupLat ?? (data['pickupLat'] as num?)?.toDouble();
    final pLng = widget.pickupLng ?? (data['pickupLng'] as num?)?.toDouble();
    final dLat = widget.destLat ?? (data['destLat'] as num?)?.toDouble();
    final dLng = widget.destLng ?? (data['destLng'] as num?)?.toDouble();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TripProgressScreen(
          requestId: widget.requestId,
          driver: widget.driver,
          trip: trip,
          distanceKm: widget.distanceKm,
          ratePerKm: effectiveRate,
          totalFare: totalFare ?? widget.distanceKm * effectiveRate,
          pickupLat: pLat,
          pickupLng: pLng,
          destLat: dLat,
          destLng: dLng,
        ),
      ),
    );
  }

  Future<void> _handleRejected() async {
    if (_handled) return;
    _handled = true;
    _timer?.cancel();
    CustomerSocketService.instance.disconnect();

    if (mounted) {
      setState(() {
        _status = 'rejected';
        _error = null;
      });
    }
    await context.read<TripProvider>().clearPendingSearch();
  }

  Future<void> _poll() async {
    if (_handled) return;
    try {
      final resp = await ApiService.getRequestStatus(widget.requestId);
      final data = resp.data as Map<String, dynamic>;
      final newStatus = data['status'] as String? ?? 'pending';

      if (!mounted || _handled) return;

      if (newStatus == 'accepted') {
        await _handleAccepted(data);
      } else if (newStatus == 'rejected') {
        await _handleRejected();
      } else {
        final agreedRate = (data['agreedRatePerKm'] as num?)?.toDouble();
        final countered = data['negotiationStatus'] == 'driver_countered';
        setState(() {
          _status = newStatus;
          _agreedRate = agreedRate;
          _myOffer = (data['suggestedRatePerKm'] as num?)?.toDouble();
          _counterRate = countered
              ? (data['counterRatePerKm'] as num?)?.toDouble()
              : null;
          if (!_answering) _error = null;
        });
      }
    } catch (e) {
      if (mounted && !_handled) {
        setState(() => _error = 'Connection error — retrying…');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.driver['name'] as String? ?? 'Driver';
    final isRejected = _status == 'rejected';
    final counterRate = isRejected ? null : _counterRate;
    final hasCounter = counterRate != null;

    final String statusText;
    if (isRejected) {
      statusText = _declinedByMe
          ? 'You declined the driver\'s offer. The request is closed.'
          : 'Your ride request was declined.';
    } else if (hasCounter) {
      statusText = 'The driver sent you a fare offer.';
    } else if (_myOffer != null) {
      statusText =
          'Waiting for the driver to answer your offer of Rs. ${_myOffer!.toStringAsFixed(0)} / km…';
    } else {
      statusText = 'Waiting for driver to accept your request…';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(hasCounter ? 'Driver\'s Offer' : 'Waiting for Driver'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Status icon ────────────────────────────────────────────────
              if (isRejected)
                const Icon(
                  Icons.cancel_rounded,
                  size: 80,
                  color: Colors.redAccent,
                )
              else if (hasCounter)
                const Icon(
                  Icons.handshake_rounded,
                  size: 72,
                  color: AppTheme.warningOrange,
                )
              else
                const WarpSearchLoader(),
              const SizedBox(height: 28),

              // ── Driver name ────────────────────────────────────────────────
              Text(
                driverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ── Status text ────────────────────────────────────────────────
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isRejected ? Colors.redAccent : Colors.white70,
                  fontSize: 16,
                ),
              ),

              if (hasCounter) ...[
                const SizedBox(height: 20),
                _CounterOfferCard(
                  counterRate: counterRate,
                  myOffer: _myOffer,
                  distanceKm: widget.distanceKm,
                  answering: _answering,
                  onAccept: () => _answerCounterOffer(true),
                  onDecline: () => _answerCounterOffer(false),
                ),
              ],

              if (_agreedRate != null && !isRejected) ...[
                const SizedBox(height: 8),
                Text(
                  'Agreed rate: Rs. ${_agreedRate!.toStringAsFixed(0)} / km',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ],

              const SizedBox(height: 40),

              // ── Loading spinner or rejection button ────────────────────────
              if (hasCounter)
                const SizedBox.shrink()
              else if (!isRejected)
                const CircularProgressIndicator(color: AppTheme.primaryBlue)
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.actionBlue,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the driver's counter-offer with Accept / Decline.
class _CounterOfferCard extends StatelessWidget {
  const _CounterOfferCard({
    required this.counterRate,
    required this.myOffer,
    required this.distanceKm,
    required this.answering,
    required this.onAccept,
    required this.onDecline,
  });

  final double counterRate;
  final double? myOffer;
  final double distanceKm;
  final bool answering;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final fare = distanceKm * counterRate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.warningOrange.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Driver offers',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${counterRate.toStringAsFixed(0)} / km',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total fare Rs. ${fare.toStringAsFixed(0)} for ${distanceKm.toStringAsFixed(1)} km',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (myOffer != null) ...[
            const SizedBox(height: 6),
            Text(
              'You offered Rs. ${myOffer!.toStringAsFixed(0)} / km',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: answering ? null : onAccept,
            child: answering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Accept and start trip'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: answering ? null : onDecline,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            child: const Text('Decline offer'),
          ),
        ],
      ),
    );
  }
}

class WarpSearchLoader extends StatefulWidget {
  const WarpSearchLoader({super.key});

  @override
  State<WarpSearchLoader> createState() => _WarpSearchLoaderState();
}

class _WarpSearchLoaderState extends State<WarpSearchLoader>
    with TickerProviderStateMixin {
  late final AnimationController _ringsController;
  late final AnimationController _coreController;

  @override
  void initState() {
    super.initState();
    _ringsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _coreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringsController.dispose();
    _coreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 224,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ringsController, _coreController]),
        builder: (_, _) => CustomPaint(
          painter: _WarpSearchPainter(
            ringsProgress: _ringsController.value,
            coreProgress: _coreController.value,
          ),
        ),
      ),
    );
  }
}

class _WarpSearchPainter extends CustomPainter {
  const _WarpSearchPainter({
    required this.ringsProgress,
    required this.coreProgress,
  });

  final double ringsProgress;
  final double coreProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const baseRadius = 80.0;
    const delays = [0.0, 0.4 / 2.2, 0.8 / 2.2, 1.2 / 2.2];

    for (final delay in delays) {
      final progress = (ringsProgress - delay + 1) % 1;
      final eased = Curves.easeOut.transform(progress);
      final scale = progress <= 0.7
          ? 0.3 + (1.1 - 0.3) * (eased / Curves.easeOut.transform(0.7))
          : 1.1 + (1.4 - 1.1) * ((progress - 0.7) / 0.3);
      final opacity = progress <= 0.7
          ? 1 - (0.85 * progress / 0.7)
          : 0.15 * (1 - ((progress - 0.7) / 0.3));
      final radius = baseRadius * scale;

      final glowPaint = Paint()
        ..color = const Color(0xFF00D1FF).withValues(alpha: opacity * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(center, radius, glowPaint);

      final fillPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00FFFF).withValues(alpha: opacity * 0.15),
            Colors.transparent,
          ],
          stops: const [0.3, 0.7],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, fillPaint);

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF00FFFF).withValues(alpha: opacity * 0.2);
      canvas.drawCircle(center, radius, borderPaint);
    }

    final coreScale = 1 + (0.2 * Curves.easeInOut.transform(coreProgress));
    final coreRadius = 12 * coreScale;
    for (final glow in const [50.0, 30.0, 18.0]) {
      canvas.drawCircle(
        center,
        coreRadius,
        Paint()
          ..color = const Color(
            0xFF00E5FF,
          ).withValues(alpha: glow == 50 ? 0.2 : (glow == 30 ? 0.38 : 0.72))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
      );
    }
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF00E5FF), Color(0xFF0099CC)],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
    );
  }

  @override
  bool shouldRepaint(covariant _WarpSearchPainter oldDelegate) =>
      ringsProgress != oldDelegate.ringsProgress ||
      coreProgress != oldDelegate.coreProgress;
}
