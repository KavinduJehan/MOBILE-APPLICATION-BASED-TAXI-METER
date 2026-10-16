import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'offline_widgets.dart';

/// Shows [payload] as a large QR on a white tile. Reaching the dialog already
/// means the trip is saved, so the copy tells the user what to do next.
Future<void> showTripQr(
  BuildContext context,
  String title,
  String payload, {
  String hint = 'Ask the passenger to scan this code on their phone.',
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: OfflineUi.panel,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(14),
              child: QrImageView(data: payload, size: 250),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OfflineUi.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  ),
);

class TripQrScanner extends StatefulWidget {
  const TripQrScanner({
    super.key,
    required this.title,
    required this.validate,
    this.hint = 'Point the camera at the QR code',
  });
  final String title;
  final String hint;
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
      offlineTick();
      await _controller.stop();
      if (mounted) Navigator.pop(context, qr);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = offlineErrorMessage(
          e,
          'That is not a trip QR code. Try the code on the other phone.',
        ),
      );
      // Pause briefly so a bad code does not flash the message every frame.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      title: Text(widget.title),
      backgroundColor: Colors.transparent,
      actions: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (context, state, _) => IconButton(
            tooltip: 'Torch',
            onPressed: _controller.toggleTorch,
            icon: Icon(
              state.torchState == TorchState.on
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
            ),
          ),
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _detect),
        OfflineScannerOverlay(hint: widget.hint, hasError: _error != null),
        if (_error != null)
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: SafeArea(
              child: OfflineNotice(
                _error!,
                tone: OfflineTone.danger,
                action: 'OK',
                onAction: () => setState(() => _error = null),
              ),
            ),
          ),
      ],
    ),
  );
}
