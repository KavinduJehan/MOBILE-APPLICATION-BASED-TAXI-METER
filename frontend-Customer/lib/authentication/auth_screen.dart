import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import 'phone_verification_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  String? _error;

  String get _otpPhoneNumber => '0${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continueWithOtp() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(phoneNumber: _otpPhoneNumber),
      ),
    );
  }

  String? _validatePhone(String? value) {
    final digits = value?.trim() ?? '';
    if (digits.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^[1-9]\d{8}$').hasMatch(digits)) {
      return 'Enter the 9 digits after +94';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white,
                  tooltip: 'Back',
                ),
              ),
              const SizedBox(height: 8),
              const RideXLogo(size: 78, textSize: 34),
              const SizedBox(height: 28),
              const Text(
                'Sign In',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please enter your mobile number to sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              _PhoneSignInForm(
                formKey: _formKey,
                phoneController: _phoneController,
                validatePhone: _validatePhone,
                onSubmit: auth.loading ? null : _continueWithOtp,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: auth.loading ? null : _continueWithOtp,
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
                          'Send OTP',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneSignInForm extends StatelessWidget {
  const _PhoneSignInForm({
    // ignore: unused_element_parameter
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.validatePhone,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final String? Function(String?) validatePhone;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: TextFormField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        cursorColor: AppTheme.primaryBlue,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          labelText: 'Phone Number',
          prefixText: '+94 ',
          prefixStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        validator: validatePhone,
        onFieldSubmitted: (_) => onSubmit?.call(),
      ),
    );
  }
}
