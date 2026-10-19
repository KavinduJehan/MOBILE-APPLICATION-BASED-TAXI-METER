// ignore_for_file: file_names

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/connectivity_check.dart';
import '../theme.dart';
import 'driver_verification.dart';

class QRScan extends StatefulWidget {
  const QRScan({super.key, this.activeListenable, this.offlineOnly = false});

  final ValueListenable<bool>? activeListenable;
  final bool offlineOnly;

  @override
  State<QRScan> createState() => _QRScanState();
}

class _QRScanState extends State<QRScan> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() {
      _processing = true;
      _error = null;
    });
    await _controller.stop();

    try {
      // QR payload: { token, name, licenseNumber, vehicleNumber, area, ratePerKm, pricingMode }
      final Map<String, dynamic> payload =
          jsonDecode(raw) as Map<String, dynamic>;
      final String? qrToken = payload['token'] as String?;
      if (qrToken == null || qrToken.isEmpty) {
        throw 'QR code has no token field';
      }

      Map<String, dynamic> driver;
      bool offlineMode = false;
      bool online = false;

      Future<Map<String, dynamic>> fromPayload() async {
        // Cannot confirm verified status without the server.
        offlineMode = true;
        online = await hasInternetConnection();
        return {
          'token': payload['token'],
          'name': payload['name'] ?? 'Unknown Driver',
          'licenseNumber': payload['licenseNumber'] ?? '—',
          'vehicleNumber': payload['vehicleNumber'] ?? '—',
          'area': payload['area'] ?? '',
          'ratePerKm': payload['ratePerKm'] ?? 0,
          'pricingMode': payload['pricingMode'] ?? 'DRIVER',
          'isVerified': false,
          '_offlineMode': true,
        };
      }

      if (widget.offlineOnly) {
        // The passenger chose an offline trip: use the QR profile on purpose.
        driver = await fromPayload();
      } else {
        try {
          final resp = await ApiService.getDriverByQR(qrToken);
          driver = resp.data as Map<String, dynamic>;
          driver['token'] = qrToken;
        } catch (e) {
          // Only fall back when the server is truly unreachable. A server
          // answer (e.g. unknown QR) is a real error, not "no internet".
          if (!isNetworkFailure(e)) {
            throw 'This driver QR was not recognised. Ask the driver to refresh their QR.';
          }
          driver = await fromPayload();
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverVerificationScreen(
            driver: driver,
            offlineMode: offlineMode,
            hasInternet: online,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e is String ? e : 'Failed to load driver. Please try again.';
        _processing = false;
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeListenable = widget.activeListenable;
    if (activeListenable == null) return _buildScanner(context);
    return ValueListenableBuilder<bool>(
      valueListenable: activeListenable,
      builder: (context, isActive, child) {
        return isActive ? _buildScanner(context) : const SizedBox.shrink();
      },
    );
  }

  Widget _buildScanner(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Scan Driver QR')),
      body: Stack(
        children: [
          // ── Camera view ─────────────────────────────────────────────────────
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // ── Scan frame overlay ───────────────────────────────────────────────
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlue, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // ── Status / error ───────────────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_processing && _error == null)
                  const CircularProgressIndicator(color: AppTheme.primaryBlue),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_processing)
                  const Text(
                    'Align driver QR code inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
