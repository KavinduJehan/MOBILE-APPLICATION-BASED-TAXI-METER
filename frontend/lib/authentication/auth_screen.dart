import 'package:flutter/material.dart';

import 'email_verification_screen.dart';
import 'phone_verification_screen.dart';
import '../theme.dart';

enum _AuthMethod { phone, email }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  _AuthMethod _method = _AuthMethod.phone;

  bool get _canContinue {
    final text = _activeController.text.trim();
    return text.isNotEmpty;
  }

  TextEditingController get _activeController {
    return _method == _AuthMethod.phone ? _phoneController : _emailController;
  }

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_refresh);
    _emailController.addListener(_refresh);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  void _toggleMethod() {
    setState(() {
      _method = _method == _AuthMethod.phone
          ? _AuthMethod.email
          : _AuthMethod.phone;
    });
  }

  void _continue() {
    if (!_canContinue) {
      return;
    }

    final value = _activeController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _method == _AuthMethod.phone
            ? PhoneVerificationScreen(phoneNumber: '+94 $value')
            : EmailVerificationScreen(emailAddress: value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _method == _AuthMethod.phone;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome to RideX',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verify with your phone number or email to continue safely',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 34),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isPhone
                          ? _PhoneInput(controller: _phoneController)
                          : _EmailInput(controller: _emailController),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      isPhone
                          ? "We'll send a short verification code to your number."
                          : "You'll enter your password on the next screen.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextButton(
                      onPressed: _toggleMethod,
                      child: Text(
                        isPhone ? 'Use email instead' : 'Use phone instead',
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canContinue
                              ? AppTheme.primaryBlue
                              : const Color(0xFF2A2A2C),
                          foregroundColor: _canContinue
                              ? Colors.white
                              : const Color(0xFF77777A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        onPressed: _canContinue ? _continue : null,
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneInput extends StatelessWidget {
  final TextEditingController controller;

  const _PhoneInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('phone-input'),
      children: [
        const Text('\u{1F1F1}\u{1F1F0}', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        const Text(
          '+94',
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            cursorColor: AppTheme.primaryBlue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              hintText: '71 234 5678',
              hintStyle: TextStyle(
                color: Color(0xFF5F5F62),
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmailInput extends StatelessWidget {
  final TextEditingController controller;

  const _EmailInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('email-input'),
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      cursorColor: AppTheme.primaryBlue,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'email@gmail.com',
        hintStyle: const TextStyle(
          color: Color(0xFF5F5F62),
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF1A1A1C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppTheme.primaryBlue),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 13,
        ),
      ),
    );
  }
}
