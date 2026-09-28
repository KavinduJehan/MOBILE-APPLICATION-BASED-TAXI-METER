import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip_record.dart';
import '../providers/auth_provider.dart';
import '../utils/json_helpers.dart';
import '../widgets/app_widgets.dart';

class DriverReceiptScreen extends StatefulWidget {
  const DriverReceiptScreen({super.key, required this.trip});

  final TripRecord trip;

  @override
  State<DriverReceiptScreen> createState() => _DriverReceiptScreenState();
}

class _DriverReceiptScreenState extends State<DriverReceiptScreen> {
  bool _loading = true;
  String? _receiptNumber;
  String? _error;

  @override
  void initState() {
    super.initState();
    // If the trip already carries the receipt number, skip the network call
    final rn = widget.trip.receiptNumber;
    if (rn != null && rn.isNotEmpty) {
      _receiptNumber = rn;
      _loading = false;
    } else {
      Future.microtask(_fetchReceipt);
    }
  }

  Future<void> _fetchReceipt() async {
    try {
      final data = await context.read<AuthProvider>().api.getReceiptForTrip(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _receiptNumber = readString(data, ['receiptNumber', 'receiptId', 'id', '_id']);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load receipt from server.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final surge = trip.surgeBreakdown;
    final isSurge = surge != null;

    return AppShellScaffold(
      appBar: AppBar(title: const Text('Receipt')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E1422), Color(0xFF14253D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFF69A8FF), size: 22),
                      const SizedBox(width: 10),
                      const Text('Trip receipt', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      StatusPill(
                        label: trip.status.toUpperCase(),
                        color: trip.status == 'completed' ? const Color(0xFF22C55E) : const Color(0xFF69A8FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Receipt number
                  if (_loading)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13))
                  else
                    Text(
                      _receiptNumber?.isNotEmpty == true ? '#${_receiptNumber!}' : 'Receipt not available',
                      style: const TextStyle(
                        color: Color(0xFF69A8FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 14),
                  Text(trip.customerName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(_formatDate(trip.date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 18),
                  InfoRow(label: 'From', value: trip.startAddress.isNotEmpty ? trip.startAddress : 'N/A'),
                  InfoRow(label: 'To',   value: trip.endAddress.isNotEmpty   ? trip.endAddress   : 'N/A'),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  InfoRow(label: 'Distance', value: '${trip.distanceKm.toStringAsFixed(2)} km'),
                  InfoRow(label: 'Rate per km', value: 'Rs. ${trip.ratePerKm.toStringAsFixed(2)}'),
                  if (isSurge) ...[
                    const SizedBox(height: 8),
                    _SurgeRow(label: 'Surge multiplier', value: '${(surge['multiplier'] as num?)?.toStringAsFixed(2) ?? '-'}×'),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total fare', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        'Rs. ${trip.fare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Surge breakdown panel
            if (isSurge) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1422),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C7CFF).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFF6C7CFF), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Auto-pricing breakdown',
                          style: TextStyle(
                            color: Color(0xFF6C7CFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _breakdownRow('🚗', 'Demand / supply',
                        '${(surge['availableDrivers'] as num?)?.toInt() ?? 0} drivers · ${(surge['activeRequests'] as num?)?.toInt() ?? 0} requests',
                        (surge['demandSupplyFactor'] as num?)?.toDouble() ?? 1.0),
                    _breakdownRow('🕐', 'Time of day', '', (surge['timeFactor'] as num?)?.toDouble() ?? 1.0),
                    _breakdownRow('🌦', 'Weather', surge['weatherCondition']?.toString() ?? '-',
                        (surge['weatherFactor'] as num?)?.toDouble() ?? 1.0),
                    _breakdownRow('📍', 'Area tier', '', (surge['areaFactor'] as num?)?.toDouble() ?? 1.0),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String icon, String label, String detail, double factor) {
    final color = factor >= 1.3 ? Colors.orangeAccent : Colors.white60;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                if (detail.isNotEmpty) Text(detail, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Text('${factor.toStringAsFixed(2)}×', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SurgeRow extends StatelessWidget {
  const _SurgeRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF6C7CFF)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Color(0xFF6C7CFF), fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
