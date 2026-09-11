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

      if (!mounted) return;
      setState(() {
        _status = newStatus;
        _agreedRate = agreedRate;
        _error = null;
      });

      if (newStatus == 'accepted') {
        _timer?.cancel();
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
            ),
          ),
        );
      } else if (newStatus == 'rejected') {
        _timer?.cancel();
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
              Icon(
                isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded,
                size: 80,
                color: isRejected ? Colors.redAccent : AppTheme.primaryBlue,
              ),
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
