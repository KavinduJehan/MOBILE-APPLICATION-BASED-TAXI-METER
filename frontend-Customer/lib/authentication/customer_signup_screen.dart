import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import 'phone_verification_screen.dart';

/// Shown when a phone number has no existing account.
/// Customer enters their name to create an account, then is sent an OTP.
class CustomerSignupScreen extends StatefulWidget {
  final String phoneNumber;

  const CustomerSignupScreen({super.key, required this.phoneNumber});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _nameController = TextEditingController();
  String? _error;

  bool get _canSubmit => _nameController.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _error = null);

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _nameController.text.trim(),
      widget.phoneNumber,
    );
    if (!mounted) return;

    if (ok) {
      // Account created — now go to OTP screen (it will auto-send the OTP)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PhoneVerificationScreen(phoneNumber: widget.phoneNumber),
        ),
      );
    } else {
      setState(() => _error = auth.error ?? 'Registration failed');
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'New number detected: ${widget.phoneNumber}\nEnter your name to get started.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                cursorColor: AppTheme.primaryBlue,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: Color(0xFF9A9A9A)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF333336)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.primaryBlue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit
                        ? AppTheme.primaryBlue
                        : const Color(0xFF2A2A2C),
                    foregroundColor: _canSubmit
                        ? Colors.white
                        : const Color(0xFF77777A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: (_canSubmit && !auth.loading) ? _submit : null,
                  child: auth.loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Create Account & Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text(
                  'Use a different number',
                  style: TextStyle(color: Color(0xFF9A9A9A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
