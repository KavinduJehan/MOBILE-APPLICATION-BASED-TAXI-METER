import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    Future.microtask(() => auth.loadProfile(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final imageBytes = _decodeQr(profile?.qrCode ?? '');
    return AppShellScaffold(
      appBar: AppBar(title: const Text('My QR Code')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  const Text('Show this QR to your customer so they can scan and verify you', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: imageBytes == null
                        ? const SizedBox(
                            width: 220,
                            height: 220,
                            child: Center(child: Icon(Icons.qr_code_rounded, size: 96, color: Colors.black54)),
                          )
                        : Image.memory(imageBytes, width: 220, height: 220, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 20),
                  Text(profile?.name ?? 'Driver name', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(profile?.vehicleNumber ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60)),
                  const SizedBox(height: 6),
                  Text('Rs. ${profile?.ratePerKm.toStringAsFixed(2) ?? '0.00'} per km', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'Refresh QR',
              isBusy: auth.busy,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await auth.refreshQr();
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(content: Text('QR refreshed')));
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Unable to refresh QR')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Uint8List? _decodeQr(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(cleaned);
  }
}