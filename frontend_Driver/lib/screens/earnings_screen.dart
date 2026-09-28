import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/income_summary.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';

enum _Period { week, month }

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _loading = true;
  IncomeSummary? _summary;
  _Period _period = _Period.week;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    setState(() => _loading = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Unable to load earnings')),
      );
    }
  }

  List<IncomeByDay> get _periodData {
    final days = _summary?.byDay ?? [];
    if (_period == _Period.week) return days.take(7).toList();
    return days.take(30).toList();
  }

  double get _periodTotal => _periodData.fold(0, (sum, d) => sum + d.amount);

  IncomeByDay? get _bestDay {
    final data = _periodData;
    if (data.isEmpty) return null;
    return data.reduce((a, b) => a.amount >= b.amount ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final data    = _periodData;
    final maxAmount = data.isEmpty ? 0.0
        : data.map((d) => d.amount).fold<double>(0, (h, a) => a > h ? a : h);
    final best = _bestDay;

    return AppShellScaffold(
      appBar: AppBar(title: const Text('Earnings')),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            const SectionTitle(
              title: 'Income overview',
              subtitle: 'Track earnings and completed trips at a glance.',
            ),
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
              // Period toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1422),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: _Period.values.map((p) {
                    final active = _period == p;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _period = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF2F6BFF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              p == _Period.week ? 'Last 7 days' : 'Last 30 days',
                              style: TextStyle(
                                color: active ? Colors.white : Colors.white54,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Stat cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          label: _period == _Period.week ? '7-day earnings' : '30-day earnings',
                          value: 'Rs. ${_periodTotal.toStringAsFixed(2)}',
                          icon: Icons.payments_rounded,
                          accentColor: const Color(0xFF2F6BFF),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          label: 'Total earnings',
                          value: 'Rs. ${summary.totalEarnings.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet_rounded,
                          accentColor: const Color(0xFF38BDF8),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          label: 'Completed rides',
                          value: summary.completedTrips.toString(),
                          icon: Icons.check_circle_rounded,
                          accentColor: const Color(0xFF22C55E),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          label: 'Cancelled rides',
                          value: summary.cancelledTrips.toString(),
                          icon: Icons.cancel_rounded,
                          accentColor: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Best day
              if (best != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2C1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFF22C55E), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Best day: ${best.label}',
                          style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'Rs. ${best.amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Bar chart
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
                    Text(
                      'Earnings by day',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    if (data.isEmpty)
                      const Center(child: Text('No data for this period', style: TextStyle(color: Colors.white38)))
                    else
                      ...data.map(
                        (day) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DayBar(
                            label: day.label,
                            amount: day.amount,
                            maxAmount: maxAmount,
                            highlight: best != null && day.label == best.label,
                          ),
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
  const _DayBar({
    required this.label,
    required this.amount,
    required this.maxAmount,
    this.highlight = false,
  });

  final String label;
  final double amount;
  final double maxAmount;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.04, 1.0);
    final color = highlight ? const Color(0xFF22C55E) : const Color(0xFF2F6BFF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: highlight ? const Color(0xFF22C55E) : Colors.white,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              'Rs. ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: highlight ? const Color(0xFF22C55E) : Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
