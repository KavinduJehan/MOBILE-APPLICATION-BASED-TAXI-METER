import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/income_summary.dart';
import '../models/trip_record.dart';
import '../utils/trip_place_label.dart';
import 'driver_receipt_screen.dart';
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
  int _days = 1;

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
    final chartData = _days == 1
        ? summary?.daysForPeriod(7, _today) ?? <IncomeByDay>[]
        : data;
    final total = data.fold<double>(0, (sum, day) => sum + day.amount);
    final max = chartData.fold<double>(
      0,
      (max, day) => day.amount > max ? day.amount : max,
    );
    final active = chartData.where((day) => day.amount > 0).toList();
    final best = active.isEmpty
        ? null
        : active.reduce((a, b) => a.amount >= b.amount ? a : b);
    final periodTrips = data.every((day) => day.trips != null)
        ? data.fold<int>(0, (sum, day) => sum + day.trips!)
        : null;
    final yesterday = summary?.daysForPeriod(2, _today).first.amount ?? 0;
    final difference = total - yesterday;

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
                          ButtonSegment(value: 1, label: Text('Today')),
                          ButtonSegment(value: 7, label: Text('7 days')),
                          ButtonSegment(value: 30, label: Text('30 days')),
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
                                    _days == 1
                                        ? "Today's earnings"
                                        : 'Last $_days days',
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
                            if (_days == 1) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      difference > 0
                                          ? Icons.trending_up_rounded
                                          : difference < 0
                                          ? Icons.trending_down_rounded
                                          : Icons.trending_flat_rounded,
                                      color: difference < 0
                                          ? Colors.orangeAccent
                                          : const Color(0xFF34D399),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        difference == 0
                                            ? 'Same earnings as yesterday'
                                            : '${_money(difference.abs())} ${difference > 0 ? 'more' : 'less'} than yesterday',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                        child: Wrap(
                          spacing: 32,
                          runSpacing: 20,
                          children: [
                            _stat(
                              _days == 1
                                  ? 'Trips completed today'
                                  : 'Trips in this period',
                              periodTrips?.toString() ?? 'Unavailable',
                              Icons.route_rounded,
                            ),
                            _stat(
                              'Average fare per trip',
                              periodTrips == null
                                  ? 'Unavailable'
                                  : _money(
                                      periodTrips == 0
                                          ? 0
                                          : total / periodTrips,
                                    ),
                              Icons.payments_outlined,
                            ),
                          ],
                        ),
                      ),
                      if (_days == 1) ...[
                        const SizedBox(height: 16),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Today's trips",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Destination and fare • Tap to view receipt',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (summary.todayTrips == null)
                                const Text(
                                  'Trip details are currently unavailable.',
                                  style: TextStyle(color: Colors.white60),
                                )
                              else if (summary.todayTrips!.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'No completed trips today yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white60),
                                  ),
                                )
                              else
                                ...summary.todayTrips!.map(_tripTile),
                            ],
                          ),
                        ),
                      ],
                      if (_days != 1) ...[
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
                                Text(
                                  _days == 1
                                      ? 'Your week at a glance'
                                      : 'Daily earnings',
                                  style: const TextStyle(
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
                                ...chartData.reversed.map(
                                  (day) => _dayRow(
                                    day,
                                    max,
                                    day.label == best?.label,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

  Widget _tripTile(TripRecord trip) {
    final time = trip.date?.toUtc().add(const Duration(hours: 5, minutes: 30));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DriverReceiptScreen(trip: trip)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tripPlaceLabel(trip.endAddress),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} • Completed',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _money(trip.fare),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
