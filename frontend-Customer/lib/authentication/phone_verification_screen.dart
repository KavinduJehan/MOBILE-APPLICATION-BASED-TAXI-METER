import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/home.dart';
import '../theme.dart';
import 'customer_signup_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  static const _surfaceDark = Color(0xFF1A1A1C);
  static const _inactiveDark = Color(0xFF2A2A2C);
  static const _mutedText = Color(0xFF8A8A8A);
  static const _otpLength = 6;

  final _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  bool _requesting = false;
  String? _error;

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == _otpLength;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.requestOtp(widget.phoneNumber);
    if (!mounted) return;
    if (ok) {
      setState(() => _requesting = false);
    } else {
      // Account does not exist â€” go to signup
      if (auth.error?.contains('No account') == true) {
        auth.clearError();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CustomerSignupScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      } else {
        setState(() {
          _error = auth.error ?? 'Failed to send OTP';
          _requesting = false;
        });
        auth.clearError();
      }
    }
  }

  void _onCodeChanged(String value, int index) {
    setState(() {});
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_isComplete) _verifyCode();
  }

  Future<void> _verifyCode() async {
    if (!_isComplete) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(widget.phoneNumber, _otp);
    if (!mounted) return;
    if (ok) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Home()),
        (_) => false,
      );
    } else {
      setState(() => _error = auth.error ?? 'Invalid OTP');
      auth.clearError();
      // Clear boxes so the user can re-enter
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _surfaceDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF333336)),
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      color: AppTheme.primaryBlue,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 58),
              const Text(
                'Enter Verification Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Enter the 6-digit code sent to ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _mutedText,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 42),
              // â”€â”€ OTP boxes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (_requesting)
                const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _otpLength,
                    (i) => _CodeBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      onChanged: (v) => _onCodeChanged(v, i),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ],
              const SizedBox(height: 28),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => Navigator.maybePop(context),
                child: const Text(
                  'Changed your mobile number?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: _surfaceDark,
                    foregroundColor: _mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _requesting ? null : _sendOtp,
                  child: const Text(
                    'Resend code',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                  onPressed: (_isComplete && !auth.loading)
                      ? _verifyCode
                      : null,
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
                          'Verify Now',
                          style: TextStyle(
                            fontSize: 19,
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
      width: 48,
      height: 62,
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
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF111111),
          isDense: true,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: _PhoneVerificationScreenState._surfaceDark,
              width: 3,
            ),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 3),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
