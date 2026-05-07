import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'login_screen.dart';
import 'qr_screen.dart';
import 'rate_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Settings')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?.name ?? 'Driver profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  InfoRow(label: 'Phone', value: profile?.phone ?? '-'),
                  InfoRow(label: 'Email', value: profile?.email ?? '-'),
                  InfoRow(label: 'License', value: profile?.licenseNumber ?? '-'),
                  InfoRow(label: 'Vehicle', value: profile?.vehicleNumber ?? '-'),
                  InfoRow(label: 'Area', value: profile?.area ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ActionCard(
              title: 'Update Rate',
              subtitle: 'Jump to the per-km rate editor.',
              icon: Icons.price_change_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RateScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Show My QR',
              subtitle: 'Open the QR screen for rider verification.',
              icon: Icons.qr_code_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Sign Out',
              subtitle: 'Clear your session and return to login.',
              icon: Icons.logout_rounded,
              onTap: () async {
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}