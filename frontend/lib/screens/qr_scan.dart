// ignore_for_file: file_names

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'driver_verification.dart';

class QRScan extends StatefulWidget {
  const QRScan({super.key});

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
      // QR payload is JSON: { token, name, licenseNumber, vehicleNumber, area, ratePerKm }
      final Map<String, dynamic> payload =
          jsonDecode(raw) as Map<String, dynamic>;
      final String? qrToken = payload['token'] as String?;
      if (qrToken == null || qrToken.isEmpty)
        throw 'QR code has no token field';

      final resp = await ApiService.getDriverByQR(qrToken);
      final driver = resp.data as Map<String, dynamic>;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverVerificationScreen(driver: driver),
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
    return Scaffold(
      backgroundColor: Colors.black,
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
