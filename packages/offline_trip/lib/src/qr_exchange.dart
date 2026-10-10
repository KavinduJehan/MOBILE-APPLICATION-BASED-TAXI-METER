import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showTripQr(BuildContext context, String title, String payload) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(data: payload, size: 250),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ask the passenger to scan this code on their phone.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

class TripQrScanner extends StatefulWidget {
  const TripQrScanner({super.key, required this.title, required this.validate});
  final String title;
  final void Function(Map<String, dynamic>) validate;
  @override
  State<TripQrScanner> createState() => _TripQrScannerState();
}

class _TripQrScannerState extends State<TripQrScanner> {
  final _controller = MobileScannerController();
  bool _processing = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    _processing = true;
    try {
      final qr = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      widget.validate(qr);
      await _controller.stop();
      if (mounted) Navigator.pop(context, qr);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _processing = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _detect),
        if (_error != null)
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            ),
          ),
      ],
    ),
  );
}
