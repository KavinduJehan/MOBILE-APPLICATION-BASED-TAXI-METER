import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _rateCtrl  = TextEditingController();
  double? _areaAverage;

  // AUTO mode state
  Map<String, dynamic>? _autoRate;
  bool _autoLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    await auth.loadProfile(force: true);
    final profile = auth.profile;
    if (!mounted || profile == null) return;

    _rateCtrl.text = profile.ratePerKm.toStringAsFixed(2);

    if (auth.rateMode == 'AUTO') {
      // Fetch the live algorithm result
      await _refreshAutoRate(profile.area);
    } else {
      // Fetch the area average for context
      try {
        final avg = await auth.api.getAreaRate(profile.area);
        if (!mounted) return;
        setState(() => _areaAverage = avg);
      } catch (_) {}
    }
  }

  Future<void> _refreshAutoRate(String area) async {
    if (!mounted) return;
    setState(() => _autoLoading = true);
    try {
      final result = await context.read<AuthProvider>().api.getAutoRate(area);
      if (!mounted) return;
      setState(() => _autoRate = result);
    } catch (_) {
      // Silently ignore – UI shows a retry button
    } finally {
      if (mounted) setState(() => _autoLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (rate == null) return;
    final auth = context.read<AuthProvider>();
    try {
      await auth.updateRate(rate);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rate updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Unable to save rate')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final profile = auth.profile;
    final isAuto  = auth.rateMode == 'AUTO';

    return AppShellScaffold(
      appBar: AppBar(title: const Text('Rate')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile + rate input card ──────────────────────────────────
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
                  SectionTitle(
                    title: isAuto ? 'Auto-calculated rate' : 'Profile rate',
                    subtitle: isAuto
                        ? 'Your rate is set by the surge pricing algorithm.'
                        : 'Adjust the amount you charge per kilometer.',
                  ),
                  const SizedBox(height: 18),
                  InfoRow(label: 'Name',    value: profile?.name ?? '-'),
                  InfoRow(label: 'License', value: profile?.licenseNumber ?? '-'),
                  InfoRow(label: 'Vehicle', value: profile?.vehicleNumber ?? '-'),
                  InfoRow(label: 'Area',    value: profile?.area ?? '-'),
                  const SizedBox(height: 10),

                  if (!isAuto) ...[
                    // Manual / Admin mode: show the text field
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        enabled: auth.rateMode != 'ADMIN',
                        decoration: InputDecoration(
                          labelText: 'Rate per km',
                          suffixText: 'Rs',
                          helperText: _areaAverage == null
                              ? 'Area average unavailable'
                              : 'Area average: Rs. ${_areaAverage!.toStringAsFixed(2)}',
                        ),
                        validator: (value) {
                          if (auth.rateMode == 'ADMIN') return null;
                          final parsed = double.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed <= 0) return 'Enter a valid rate';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (auth.rateMode == 'ADMIN') ...[
                      _modeNoticeBox(
                        Colors.orange,
                        'Rates are controlled by the regulator. You cannot change your rate.',
                      ),
                      const SizedBox(height: 20),
                    ],
                    PrimaryActionButton(
                      label: 'Save Rate',
                      isBusy: auth.busy,
                      onPressed: auth.rateMode == 'ADMIN' ? null : _save,
                    ),
                  ] else ...[
                    // AUTO mode: big live rate display
                    _modeNoticeBox(
                      const Color(0xFF6C7CFF),
                      'Smart auto-pricing is active. The algorithm sets your rate in real time.',
                    ),
                    const SizedBox(height: 20),
                    if (_autoLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_autoRate != null)
                      _autoRateDisplay(_autoRate!)
                    else
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              _refreshAutoRate(profile?.area ?? ''),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh live rate'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _autoLoading
                          ? null
                          : () => _refreshAutoRate(profile?.area ?? ''),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _modeNoticeBox(Color color, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      );

  Widget _autoRateDisplay(Map<String, dynamic> data) {
    final breakdown   = (data['breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final effectiveRate = (data['effectiveRate'] as num?)?.toDouble() ?? 0;
    final baseRate    = (data['baseRate'] as num?)?.toDouble() ?? 0;
    final multiplier  = (data['multiplier'] as num?)?.toDouble() ?? 1;

    double d(String key) => (breakdown[key] as num?)?.toDouble() ?? 0;
    String s(String key) => breakdown[key]?.toString() ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big effective rate
        Center(
          child: Column(
            children: [
              Text(
                'Rs. ${effectiveRate.toStringAsFixed(2)} / km',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C7CFF),
                ),
              ),
              Text(
                'Base Rs. ${baseRate.toStringAsFixed(2)}  ×  ${multiplier.toStringAsFixed(2)}x surge',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        const Text(
          'What\'s driving the rate?',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _signalRow('🚗', 'Demand vs supply',
            '${d("availableDrivers").toInt()} drivers  ·  ${d("activeRequests").toInt()} requests',
            d('demandSupplyFactor')),
        _signalRow('🕐', 'Time of day', _timeLabel(),
            d('timeFactor')),
        _signalRow('🌦', 'Weather', s('weatherCondition'),
            d('weatherFactor')),
        _signalRow('📍', 'Area tier', data['area']?.toString() ?? '-',
            d('areaFactor')),
      ],
    );
  }

  Widget _signalRow(String icon, String label, String detail, double factor) {
    final isHigh = factor >= 1.3;
    final color  = isHigh ? Colors.orangeAccent : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(detail, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${factor.toStringAsFixed(2)}x',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel() {
    final hour = DateTime.now().hour;
    if (hour >= 7  && hour <= 9)  return 'Morning rush';
    if (hour >= 17 && hour <= 20) return 'Evening rush';
    if (hour >= 22 || hour <= 2)  return 'Late night';
    return 'Off-peak';
  }
}
