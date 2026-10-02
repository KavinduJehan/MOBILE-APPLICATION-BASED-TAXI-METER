import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _vehicleCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile;
    _nameCtrl    = TextEditingController(text: p?.name ?? '');
    _emailCtrl   = TextEditingController(text: p?.email ?? '');
    _phoneCtrl   = TextEditingController(text: p?.phone ?? '');
    _vehicleCtrl = TextEditingController(text: p?.vehicleNumber ?? '');
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _vehicleCtrl]) {
      c.addListener(() => setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _vehicleCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    try {
      final updated = await auth.api.updateProfile(
        name:          _nameCtrl.text.trim(),
        email:         _emailCtrl.text.trim(),
        phone:         _phoneCtrl.text.trim(),
        vehicleNumber: _vehicleCtrl.text.trim(),
      );
      // Refresh provider so the rest of the app sees the new values
      await auth.loadProfile(force: true);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated — hi, ${updated.name.split(' ').first}!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Could not save — try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return AppShellScaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar + verification badge
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3C7BFF), Color(0xFF1C4FD6)],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x442F6BFF), blurRadius: 24, offset: Offset(0, 12)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (profile?.name.isNotEmpty == true)
                            ? profile!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  if (profile?.isVerified == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF22C55E),
                          border: Border.all(color: const Color(0xFF040404), width: 2),
                        ),
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                profile?.isVerified == true ? 'Verified driver' : 'Pending verification',
                style: TextStyle(
                  color: profile?.isVerified == true ? const Color(0xFF22C55E) : Colors.orangeAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                profile?.licenseNumber ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Read-only fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account info', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  InfoRow(label: 'License no.', value: profile?.licenseNumber ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Editable form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _Field(
                    controller: _nameCtrl,
                    label: 'Full name',
                    icon: Icons.person_rounded,
                    validator: (v) => (v?.trim().isEmpty == true) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return 'Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v!)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    controller: _phoneCtrl,
                    label: 'Phone number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v?.trim().isEmpty == true) ? 'Phone is required' : null,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    controller: _vehicleCtrl,
                    label: 'Vehicle number',
                    icon: Icons.directions_car_rounded,
                    validator: (v) => (v?.trim().isEmpty == true) ? 'Vehicle number is required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            PrimaryActionButton(
              label: 'Save changes',
              isBusy: auth.busy,
              onPressed: _dirty ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.white38),
      ),
    );
  }
}
