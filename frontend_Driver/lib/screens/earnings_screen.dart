import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/income_summary.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key, this.isActive = true});
  final bool isActive;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _loading = false;
  IncomeSummary? _summary;
  String? _error;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant EarningsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await context.read<AuthProvider>().api.getIncomeSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _summary == null
            ? 'Unable to load earnings. Check your connection and try again.'
            : 'Could not refresh. Showing your last loaded earnings.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime get _today =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final data = summary?.daysForPeriod(_days, _today) ?? <IncomeByDay>[];
    final total = data.fold<double>(0, (sum, day) => sum + day.amount);
    final max = data.fold<double>(
      0,
      (max, day) => day.amount > max ? day.amount : max,
    );
    final active = data.where((day) => day.amount > 0).toList();
    final best = active.isEmpty
        ? null
        : active.reduce((a, b) => a.amount >= b.amount ? a : b);
    final periodTrips = data.every((day) => day.trips != null)
        ? data.fold<int>(0, (sum, day) => sum + day.trips!)
        : null;

    return AppShellScaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh earnings',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle(
                      title: 'Every trip counts',
                      subtitle: 'Your income from completed rides.',
                    ),
                    const SizedBox(height: 20),
                    if (_loading && summary == null)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null) ...[
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                height: 1.5,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _loading ? null : _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (summary != null) ...[
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 7, label: Text('Last 7 days')),
                          ButtonSegment(value: 30, label: Text('Last 30 days')),
                        ],
                        selected: {_days},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) =>
                            setState(() => _days = value.first),
                      ),
                      const SizedBox(height: 18),
                      _card(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF173967), Color(0xFF101826)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppTheme.accent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Last $_days days',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                if (_loading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _money(total),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              periodTrips == null
                                  ? 'Completed-trip earnings'
                                  : '$periodTrips completed ${periodTrips == 1 ? 'trip' : 'trips'}',
                              style: const TextStyle(color: Colors.white60),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Sri Lanka time',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lifetime overview',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 28,
                              runSpacing: 20,
                              children: [
                                _stat(
                                  'Total earned',
                                  _money(summary.totalEarnings),
                                  Icons.payments_outlined,
                                ),
                                _stat(
                                  'Completed trips',
                                  '${summary.completedTrips}',
                                  Icons.check_circle_outline,
                                ),
                                _stat(
                                  'Average per trip',
                                  _money(
                                    summary.completedTrips == 0
                                        ? 0
                                        : summary.totalEarnings /
                                              summary.completedTrips,
                                  ),
                                  Icons.trending_up_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (summary.completedTrips == 0)
                        const EmptyStateCard(
                          title: 'Your first fare starts here',
                          subtitle:
                              'Complete a trip to start tracking earnings. Offline trips appear after syncing.',
                          icon: Icons.route_rounded,
                        )
                      else
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Daily earnings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Completed fares, grouped by day',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (best != null) ...[
                                Text(
                                  'Best day: ${_label(best.label)}  /  ${_money(best.amount)}',
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (active.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'No completed rides in this period.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white60),
                                  ),
                                ),
                              ...data.reversed.map(
                                (day) =>
                                    _dayRow(day, max, day.label == best?.label),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Only completed trips count toward earnings. Offline fares appear after you sync your trips.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double amount) => 'Rs. ${amount.toStringAsFixed(2)}';

  String _label(String key) {
    final date = DateTime.tryParse(key);
    if (date == null) return key;
    final today = _today;
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _card({required Widget child, Gradient? gradient}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
    ),
    child: child,
  );

  Widget _stat(String label, String value, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppTheme.accent, size: 20),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );

  Widget _dayRow(IncomeByDay day, double max, bool best) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _label(day.label),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (day.trips != null)
              Text(
                '${day.trips} ${day.trips == 1 ? 'trip' : 'trips'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _money(day.amount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: best ? const Color(0xFF34D399) : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : (day.amount / max).clamp(0, 1),
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            color: best ? const Color(0xFF34D399) : AppTheme.primary,
          ),
        ),
      ],
    ),
  );
}
