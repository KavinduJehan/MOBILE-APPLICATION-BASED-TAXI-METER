import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'earnings_screen.dart';
import 'incoming_requests_screen.dart';
import 'qr_screen.dart';
import 'rate_screen.dart';
import 'settings_screen.dart';
import 'trip_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    Future.microtask(auth.loadProfile);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return AppShellScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${profile?.name.split(' ').first ?? 'Driver'}!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Manage your rides from one secure dashboard.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const DriverLogo(size: 58),
              ],
            ),
            const SizedBox(height: 20),
            if (profile != null && !profile.isVerified)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E2F00),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'Your account is pending admin approval. You cannot receive ride requests yet.',
                  style: TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w600),
                ),
              ),
            if (profile != null && !profile.isVerified) const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0E1422), const Color(0xFF14253D).withValues(alpha: 0.95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live status', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Text(
                    profile?.isVerified == true ? 'Verified and ready for requests' : 'Pending verification',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      StatCard(label: 'Rate per km', value: 'Rs. ${profile?.ratePerKm.toStringAsFixed(2) ?? '0.00'}', icon: Icons.payments_rounded),
                      StatCard(label: 'Area', value: profile?.area.isNotEmpty == true ? profile!.area : 'Unknown', icon: Icons.place_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Quick Actions', subtitle: 'Jump straight to the tasks you use every day.'),
            const SizedBox(height: 14),
            ActionCard(
              title: 'Incoming Requests',
              subtitle: 'Review pending ride requests and respond.',
              icon: Icons.receipt_long_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IncomingRequestsScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'My QR Code',
              subtitle: 'Show riders your verification QR.',
              icon: Icons.qr_code_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Update Rate',
              subtitle: 'Keep your per-km rate current.',
              icon: Icons.price_change_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RateScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Trip History',
              subtitle: 'Check completed rides and receipts.',
              icon: Icons.route_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TripHistoryScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Earnings',
              subtitle: 'Track daily income and completed trips.',
              icon: Icons.bar_chart_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarningsScreen())),
            ),
            const SizedBox(height: 12),
            ActionCard(
              title: 'Settings',
              subtitle: 'Review profile and sign out.',
              icon: Icons.settings_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            if (auth.busy) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
        ),
      ),
    );
  }
}