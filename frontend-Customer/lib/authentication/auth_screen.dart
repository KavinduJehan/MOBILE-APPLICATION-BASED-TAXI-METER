import 'package:flutter/material.dart';

import 'phone_verification_screen.dart';
import '../theme.dart';
import 'package:flutter/services.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();

  String get _phoneNumber => _phoneController.text.trim();

  bool get _canContinue =>
      _phoneNumber.length == 10 && _phoneNumber.startsWith('0');

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_canContinue) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(
          phoneNumber: _phoneNumber,
          isNewCustomer: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.white,
                        tooltip: 'Back',
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      'Enter your mobile number to sign in or create an account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Phone input
                    Row(
                      children: [
                        const Text(
                          '\u{1F1F1}\u{1F1F0}',
                          style: TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            autofocus: true,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            cursorColor: AppTheme.primaryBlue,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: '+94 77 234 5678',
                              hintStyle: TextStyle(
                                color: Color(0xFF5F5F62),
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _continue(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "We'll send a 6-digit code to verify your number.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 15,
                        height: 1.3,
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
