import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rate_model.dart';
import '../providers/rate_provider.dart';
import '../theme.dart';

class RateComparison extends StatefulWidget {
  final String? area;
  final double? driverRate;

  const RateComparison({super.key, this.area, this.driverRate});

  @override
  State<RateComparison> createState() => _RateComparisonState();
}

class _RateComparisonState extends State<RateComparison> {
  late String _area;
  final _areaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _area = widget.area?.trim().isNotEmpty == true ? widget.area! : 'Colombo';
    _areaController.text = _area;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RateProvider>().load(_area);
    });
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<RateProvider>().load(_area);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Live Rate Comparison')),
      body: Consumer<RateProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryBlue,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _areaController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (value.trim().isEmpty) return;
                    setState(() => _area = value.trim());
                    context.read<RateProvider>().load(_area);
                  },
                  decoration: InputDecoration(
                    labelText: 'Area',
                    labelStyle: const TextStyle(color: Color(0xFFB5B5B5)),
                    prefixIcon: const Icon(Icons.map, color: AppTheme.primaryBlue),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (provider.loading && provider.rate == null)
                  const SizedBox(
                    height: 260,
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                    ),
                  )
                else if (provider.rate == null)
                  _RateError(
                    message: provider.error ?? 'No live rate data available',
                    onRetry: _refresh,
                  )
                else
                  _RateDetails(
                    rate: provider.rate!,
                    driverRate: widget.driverRate,
                    showingCached: provider.showingCached,
                    error: provider.error,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RateDetails extends StatelessWidget {
  final AreaRateModel rate;
  final double? driverRate;
  final bool showingCached;
  final String? error;

  const _RateDetails({
    required this.rate,
    required this.driverRate,
    required this.showingCached,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final perKm = rate.perKmCharge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showingCached)
          const _Banner(
            icon: Icons.cloud_off,
            text: 'Showing latest cached rate. Pull to retry live data.',
          )
        else if (error != null)
          _Banner(icon: Icons.info_outline, text: error!),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF333336)),
          ),
          child: Column(
            children: [
              _Row(label: 'Area', value: rate.areaName),
              _Row(label: 'Base fare', value: _money(rate.baseFare)),
              _Row(label: 'Per km charge', value: _money(perKm)),
              _Row(label: 'Waiting charge', value: _money(rate.waitingCharge)),
              _Row(
                label: 'Surge multiplier',
                value: '${rate.surgeMultiplier.toStringAsFixed(2)}x',
              ),
              _Row(
                label: 'Last updated',
                value: rate.lastUpdatedAt == null
                    ? '-'
                    : _formatDate(rate.lastUpdatedAt!),
              ),
              if (driverRate != null) ...[
                const Divider(color: Color(0xFF333336)),
                _Row(label: 'Driver rate', value: _money(driverRate)),
                _Row(
                  label: 'Comparison',
                  value: _status(driverRate!, perKm),
                  valueColor: _statusColor(driverRate!, perKm),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _money(double? value) =>
      value == null ? '-' : 'Rs. ${value.toStringAsFixed(2)}';

  static String _status(double driverRate, double? marketRate) {
    if (marketRate == null || marketRate == 0) return 'No area average';
    final diff = driverRate - marketRate;
    if (diff.abs() < 1) return 'Matches market';
    return diff > 0 ? 'Above market' : 'Below market';
  }

  static Color _statusColor(double driverRate, double? marketRate) {
    if (marketRate == null || marketRate == 0) return Colors.white70;
    final diff = driverRate - marketRate;
    if (diff.abs() < 1) return AppTheme.successGreen;
    return diff > 0 ? Colors.orangeAccent : AppTheme.successGreen;
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _Row({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF))),
          ),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryBlue),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _RateError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _RateError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => onRetry(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
