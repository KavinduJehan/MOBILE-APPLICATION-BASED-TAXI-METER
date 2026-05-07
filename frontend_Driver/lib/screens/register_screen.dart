import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseController = TextEditingController();
  final _vehicleController = TextEditingController();
  String _area = 'Colombo';

  final List<String> _areas = const [
    'Colombo',
    'Kandy',
    'Galle',
    'Jaffna',
    'Negombo',
    'Kurunegala',
    'Matara',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    try {
      final message = await auth.register(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        licenseNumber: _licenseController.text.trim(),
        vehicleNumber: _vehicleController.text.trim(),
        area: _area,
      );
      if (!mounted) return;
      Navigator.of(context).pop('$message - pending admin verification');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<AuthProvider>().errorMessage ?? 'Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AppShellScaffold(
      appBar: AppBar(title: const Text('Create Driver Account')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1422),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full name'), validator: _required),
                const SizedBox(height: 14),
                TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'), validator: _required),
                const SizedBox(height: 14),
                TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: _required),
                const SizedBox(height: 14),
                TextFormField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: _passwordValidator),
                const SizedBox(height: 14),
                TextFormField(controller: _licenseController, decoration: const InputDecoration(labelText: 'License number'), validator: _required),
                const SizedBox(height: 14),
                TextFormField(controller: _vehicleController, decoration: const InputDecoration(labelText: 'Vehicle number'), validator: _required),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _area,
                  decoration: const InputDecoration(labelText: 'Area'),
                  items: _areas.map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
                  onChanged: (value) => setState(() => _area = value ?? _area),
                ),
                const SizedBox(height: 20),
                PrimaryActionButton(label: 'Register', isBusy: auth.busy, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }
}