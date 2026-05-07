import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/income_summary.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _loading = true;
  IncomeSummary? _summary;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    try {
      final summary = await auth.api.getIncomeSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Unable to load earnings')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final maxAmount = (summary?.byDay.isNotEmpty == true)
        ? summary!.byDay.map((day) => day.amount).fold<double>(0, (highest, amount) => amount > highest ? amount : highest)
        : 0.0;
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Earnings')),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            const SectionTitle(title: 'Income overview', subtitle: 'Track earnings and completed trips at a glance.'),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator()))
            else if (summary == null || summary.byDay.isEmpty)
              const EmptyStateCard(
                title: 'No completed trips yet',
                subtitle: 'Earnings will appear here after you close completed rides.',
                icon: Icons.bar_chart_rounded,
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatCard(label: 'Total earnings', value: 'Rs. ${summary.totalEarnings.toStringAsFixed(2)}', icon: Icons.payments_rounded),
                  StatCard(label: 'Completed trips', value: summary.totalTrips.toString(), icon: Icons.route_rounded),
                ],
              ),
              const SizedBox(height: 18),
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
                    Text('Earnings by day', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ...summary.byDay.map(
                      (day) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DayBar(label: day.label, amount: day.amount, maxAmount: maxAmount),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.label, required this.amount, required this.maxAmount});

  final String label;
  final double amount;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.08, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('Rs. ${amount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2F6BFF)),
          ),
        ),
      ],
    );
  }
}