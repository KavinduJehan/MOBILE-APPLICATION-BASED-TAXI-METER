import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'request_detail_screen.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  Timer? _timer;
  bool _loading = true;
  List<RideRequest> _requests = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final auth = context.read<AuthProvider>();
    try {
      final requests = await auth.api.getIncomingRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.errorMessage ?? 'Unable to load requests')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      appBar: AppBar(
        leading: tabBackButton(context),
        title: const Text('Incoming Requests'),
      ),
      child: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            const SectionTitle(title: 'Live queue', subtitle: 'The list refreshes automatically every 3 seconds.'),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_requests.isEmpty)
              const EmptyStateCard(
                title: 'No incoming requests',
                subtitle: 'New ride requests will appear here when passengers send them to you.',
                icon: Icons.local_taxi_rounded,
              )
            else
              ..._requests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(
                    request: request,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RequestDetailScreen(request: request)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final RideRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final suggestedRate = request.suggestedRatePerKm;
    final driverRate = request.driverRatePerKm;
    final highlightSuggested = suggestedRate != null && suggestedRate != driverRate;
    return Material(
      color: const Color(0xFF0E1422),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(request.customerName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  StatusPill(label: request.status.toUpperCase(), color: const Color(0xFF69A8FF)),
                ],
              ),
              const SizedBox(height: 12),
              Text('${request.pickupAddress} -> ${request.destinationAddress}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniInfo(label: 'Distance', value: '${request.estimatedDistanceKm.toStringAsFixed(1)} km')),
                  Expanded(child: _MiniInfo(label: 'Your rate', value: 'Rs. ${driverRate.toStringAsFixed(2)}')),
                ],
              ),
              if (suggestedRate != null) ...[
                const SizedBox(height: 10),
                _MiniInfo(
                  label: 'Suggested rate',
                  value: 'Rs. ${suggestedRate.toStringAsFixed(2)}',
                  highlight: highlightSuggested,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white54)),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: highlight ? const Color(0xFFFFC107) : Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}