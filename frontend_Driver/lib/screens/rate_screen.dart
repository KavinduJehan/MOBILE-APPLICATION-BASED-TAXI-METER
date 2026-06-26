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
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  double? _areaAverage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    await auth.loadProfile(force: true);
    final profile = auth.profile;
    if (!mounted || profile == null) return;
    _rateController.text = profile.ratePerKm.toStringAsFixed(2);
    try {
      final areaRate = await auth.api.getAreaRate(profile.area);
      if (!mounted) return;
      setState(() => _areaAverage = areaRate);
    } catch (_) {
      // Keep the screen usable even if the average rate endpoint is unavailable.
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rate = double.tryParse(_rateController.text.trim());
    if (rate == null) return;
    final auth = context.read<AuthProvider>();
    try {
      await auth.updateRate(rate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Unable to save rate')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Update Rate')),
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
                  const SectionTitle(title: 'Profile rate', subtitle: 'Adjust the amount you charge per kilometer.'),
                  const SizedBox(height: 18),
                  InfoRow(label: 'Name', value: profile?.name ?? '-'),
                  InfoRow(label: 'License', value: profile?.licenseNumber ?? '-'),
                  InfoRow(label: 'Vehicle', value: profile?.vehicleNumber ?? '-'),
                  InfoRow(label: 'Area', value: profile?.area ?? '-'),
                  const SizedBox(height: 10),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: auth.rateMode != 'ADMIN',
                      decoration: InputDecoration(
                        labelText: 'Rate per km',
                        suffixText: 'Rs',
                        helperText: _areaAverage == null ? 'Area average unavailable' : 'Area average: Rs. ${_areaAverage!.toStringAsFixed(2)}',
                      ),
                      validator: (value) {
                        if (auth.rateMode == 'ADMIN') return null;
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid rate';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
+                  if (auth.rateMode == 'ADMIN') ...[
+                    Container(
+                      padding: const EdgeInsets.all(14),
+                      decoration: BoxDecoration(
+                        color: Colors.orange.withOpacity(0.12),
+                        borderRadius: BorderRadius.circular(16),
+                        border: Border.all(color: Colors.orange.withOpacity(0.24)),
+                      ),
+                      child: const Text(
+                        'Rates are controlled by the regulator. You cannot change your rate.',
+                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
+                      ),
+                    ),
+                    const SizedBox(height: 20),
+                  ],
                   PrimaryActionButton(
                     label: 'Save Rate',
                     isBusy: auth.busy,
                     onPressed: auth.rateMode == 'ADMIN' ? null : _save,
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}