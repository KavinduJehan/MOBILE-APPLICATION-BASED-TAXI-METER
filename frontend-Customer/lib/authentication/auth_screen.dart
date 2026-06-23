import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/main_navigation.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import 'phone_verification_screen.dart';

enum _SignInMode { password, otp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  _SignInMode _mode = _SignInMode.password;
  bool _obscurePassword = true;
  String? _error;

  String get _otpPhoneNumber => '0${_phoneController.text.trim()}';

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signInWithPassword() async {
    FocusScope.of(context).unfocus();
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _error = null);

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      identifier: _normalizeIdentifier(_identifierController.text),
      password: _passwordController.text,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } else {
      setState(() => _error = auth.error ?? 'Login failed');
      auth.clearError();
    }
  }

  void _continueWithOtp() {
    FocusScope.of(context).unfocus();
    if (!_otpFormKey.currentState!.validate()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(phoneNumber: _otpPhoneNumber),
      ),
    );
  }

  String _normalizeIdentifier(String value) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 9) return '0$digits';
    if (digits.length == 10 && digits.startsWith('0')) return digits;
    if (digits.length == 11 && digits.startsWith('94')) {
      return '0${digits.substring(2)}';
    }
    return trimmed.toLowerCase();
  }

  String? _validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or phone number is required';
    }
    final normalized = _normalizeIdentifier(value);
    final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized);
    final isPhone = RegExp(r'^0[1-9]\d{8}$').hasMatch(normalized);
    if (!isEmail && !isPhone) {
      return 'Enter a valid email or Sri Lankan phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  String? _validateOtpPhone(String? value) {
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
                'Use your RideX account details or sign in with a phone OTP.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              SegmentedButton<_SignInMode>(
                segments: const [
                  ButtonSegment(
                    value: _SignInMode.password,
                    label: Text('Password'),
                    icon: Icon(Icons.lock_rounded),
                  ),
                  ButtonSegment(
                    value: _SignInMode.otp,
                    label: Text('OTP'),
                    icon: Icon(Icons.sms_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mode = selection.first;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _mode == _SignInMode.password
                    ? _PasswordSignInForm(
                        key: const ValueKey('password-form'),
                        formKey: _passwordFormKey,
                        identifierController: _identifierController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onTogglePassword: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        validateIdentifier: _validateIdentifier,
                        validatePassword: _validatePassword,
                        onSubmit: auth.loading ? null : _signInWithPassword,
                      )
                    : _OtpSignInForm(
                        key: const ValueKey('otp-form'),
                        formKey: _otpFormKey,
                        phoneController: _phoneController,
                        validatePhone: _validateOtpPhone,
                        onSubmit: _continueWithOtp,
                      ),
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
                  onPressed: auth.loading
                      ? null
                      : (_mode == _SignInMode.password
                          ? _signInWithPassword
                          : _continueWithOtp),
                  child: auth.loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _mode == _SignInMode.password
                              ? 'Sign In'
                              : 'Send OTP',
                          style: const TextStyle(
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

class _PasswordSignInForm extends StatelessWidget {
  const _PasswordSignInForm({
    super.key,
    required this.formKey,
    required this.identifierController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.validateIdentifier,
    required this.validatePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final String? Function(String?) validateIdentifier;
  final String? Function(String?) validatePassword;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: identifierController,
            keyboardType: TextInputType.emailAddress,
            cursorColor: AppTheme.primaryBlue,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'Email or Phone Number',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            validator: validateIdentifier,
            onFieldSubmitted: (_) => onSubmit?.call(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            cursorColor: AppTheme.primaryBlue,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white54,
                ),
              ),
            ),
            validator: validatePassword,
            onFieldSubmitted: (_) => onSubmit?.call(),
          ),
        ],
      ),
    );
  }
}

class _OtpSignInForm extends StatelessWidget {
  const _OtpSignInForm({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.validatePhone,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final String? Function(String?) validatePhone;
  final VoidCallback onSubmit;

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
          prefixIcon: Icon(Icons.phone_rounded),
        ),
        validator: validatePhone,
        onFieldSubmitted: (_) => onSubmit(),
      ),
    );
  }
}
