import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/onboarding_screen.dart';
import '../theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String emailAddress;

  const EmailVerificationScreen({
    super.key,
    this.emailAddress = 'user@example.com',
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const _surfaceDark = Color(0xFF1A1A1C);
  static const _inactiveDark = Color(0xFF2A2A2C);
  static const _mutedText = Color(0xFF9CA3AF);

  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());

  bool get _isComplete {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(String value, int index) {
    setState(() {});

    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _verifyCode() {
    if (!_isComplete) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppTheme.primaryBlue,
                  iconSize: 34,
                  style: IconButton.styleFrom(
                    backgroundColor: _surfaceDark,
                    fixedSize: const Size(48, 48),
                  ),
                ),
              ),
              const SizedBox(height: 58),
              const Icon(
                Icons.mark_email_read_rounded,
                color: AppTheme.primaryBlue,
                size: 58,
              ),
              const SizedBox(height: 22),
              const Text(
                'Check Your Email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Enter the 4-digit code sent to ${widget.emailAddress}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _mutedText,
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 42),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  _controllers.length,
                  (index) => _CodeBox(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    onChanged: (value) => _onCodeChanged(value, index),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => Navigator.maybePop(context),
                child: const Text(
                  'Use a different email',
                  style: TextStyle(
                    fontSize: 17,
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
                    backgroundColor: _isComplete
                        ? AppTheme.primaryBlue
                        : _inactiveDark,
                    foregroundColor: _isComplete
                        ? Colors.white
                        : const Color(0xFF77777A),
                    elevation: 0,
                    disabledBackgroundColor: _inactiveDark,
                    disabledForegroundColor: const Color(0xFF77777A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: _isComplete ? _verifyCode : null,
                  child: const Text(
                    'Verify Email',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
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

class _CodeBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _CodeBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 70,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        cursorColor: AppTheme.primaryBlue,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        decoration: const InputDecoration(
          filled: true,
          fillColor: Color(0xFF111111),
          isDense: true,
          counterText: '',
          contentPadding: EdgeInsets.symmetric(vertical: 15),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: _EmailVerificationScreenState._surfaceDark,
              width: 3,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 3),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
