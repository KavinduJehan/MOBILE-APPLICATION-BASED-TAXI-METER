import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'trip_progress_screen.dart';

class WaitingForDriverScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> driver;
  final double distanceKm;
  final double ratePerKm;

  const WaitingForDriverScreen({
    super.key,
    required this.requestId,
    required this.driver,
    required this.distanceKm,
    required this.ratePerKm,
  });

  @override
  State<WaitingForDriverScreen> createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen> {
  Timer? _timer;
  String _status = 'pending';
  String? _error;
  double? _agreedRate;

  @override
  void initState() {
    super.initState();
    _poll(); // immediate first check
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final resp = await ApiService.getRequestStatus(widget.requestId);
      final data = resp.data as Map<String, dynamic>;
      final newStatus = data['status'] as String? ?? 'pending';
      final agreedRate = (data['agreedRatePerKm'] as num?)?.toDouble();
      final suggestedRate = (data['suggestedRatePerKm'] as num?)?.toDouble();
      final driverRate = (data['driverRatePerKm'] as num?)?.toDouble();
      final offerDeclined =
          newStatus == 'accepted' &&
          suggestedRate != null &&
          agreedRate != null &&
          driverRate != null &&
          agreedRate == driverRate &&
          agreedRate != suggestedRate;

      if (!mounted) return;
      setState(() {
        _status = newStatus;
        _agreedRate = agreedRate;
        _error = null;
      });

      if (newStatus == 'accepted') {
        _timer?.cancel();
        await context.read<TripProvider>().clearPendingSearch();
        if (!mounted) return;

        // Extract totalFare from the populated trip in the status response
        final tripObj = data['trip'] as Map<String, dynamic>?;
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
              offerDeclined: offerDeclined,
            ),
          ),
        );
      } else if (newStatus == 'rejected') {
        _timer?.cancel();
        await context.read<TripProvider>().clearPendingSearch();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Connection error — retrying…');
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.driver['name'] as String? ?? 'Driver';
    final isRejected = _status == 'rejected';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Waiting for Driver')),
      body: Center(
        child: Padding(
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
                isRejected
                    ? 'Your ride request was declined.'
                    : 'Waiting for driver to accept your request…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isRejected ? Colors.redAccent : Colors.white70,
                  fontSize: 16,
                ),
              ),

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
              if (!isRejected)
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
