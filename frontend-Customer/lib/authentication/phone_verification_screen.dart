import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/main_navigation.dart';
import '../screens/onboarding_screen.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';

import '../services/firebase_auth_service.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isNewUser;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.isNewUser = false,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  static const _surfaceDark = AppTheme.surface;
  static const _inactiveDark = Color(0xFF2A2A2C);
  static const _mutedText = Color(0xFF8A8A8A);
  static const _otpLength = 6;

  final _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  bool _requesting = false;
  bool _verifying = false;
  String? _error;
  String? _info;

  String? _verificationId;
  int? _resendToken;

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == _otpLength;
  String get _displayPhone {
    final phone = widget.phoneNumber;
    if (phone.length == 10 && phone.startsWith('0')) {
      return '+94 ${phone.substring(1)}';
    }
    return phone;
  }

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
      _info = null;
    });

    try {
      await FirebaseAuthService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        resendToken: _resendToken,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _requesting = false;
            _info = 'Verification code sent to $_displayPhone';
          });
        },
        onVerificationFailed: (errorMessage) {
          if (!mounted) return;
          setState(() {
            _requesting = false;
            _error = errorMessage;
          });
        },
        onAutoVerified: (idToken) async {
          if (!mounted) return;
          await _loginWithIdToken(idToken);
        },
      );
    } catch (_) {
      if (!mounted) return;
      // Graceful fallback to backend direct OTP
      final auth = context.read<AuthProvider>();
      final ok = await auth.requestOtp(widget.phoneNumber);
      if (mounted) {
        setState(() {
          _requesting = false;
          if (ok) {
            _info = 'Verification code sent.';
          } else {
            _error = auth.error ?? 'Failed to send OTP';
          }
        });
      }
    }
  }

  Future<void> _loginWithIdToken(String idToken) async {
    setState(() => _verifying = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithFirebasePhone(idToken: idToken);
    if (!mounted) return;
    if (ok) {
      final destination = widget.isNewUser
          ? const OnboardingScreen()
          : const MainNavigation();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
      return;
    }
    setState(() {
      _verifying = false;
      _error = auth.error ?? 'Login failed. Please try again.';
    });
  }

  void _onCodeChanged(String value, int index) {
    if (_requesting || _verifying) return;
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
    if (!_isComplete || _requesting || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });

    try {
      if (_verificationId != null) {
        final idToken = await FirebaseAuthService.verifyOtp(
          verificationId: _verificationId!,
          smsCode: _otp,
        );
        await _loginWithIdToken(idToken);
      } else {
        // Fallback to backend direct OTP
        final auth = context.read<AuthProvider>();
        final ok = await auth.verifyOtp(widget.phoneNumber, _otp);
        if (!mounted) return;
        if (ok) {
          final destination = widget.isNewUser
              ? const OnboardingScreen()
              : const MainNavigation();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => destination),
            (_) => false,
          );
          return;
        }

        final message = auth.error ?? 'Invalid OTP';
        auth.clearError();
        _clearOtp();
        setState(() {
          _error = message.toLowerCase().contains('expired')
              ? 'Code expired. Press Resend code to get a new one.'
              : message;
          _info = null;
        });
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) {
        _clearOtp();
        setState(() {
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {});
  }

  Future<void> _resendOtp() async {
    _clearOtp();
    _focusNodes[0].requestFocus();
    await _sendOtp();
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
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
                  const SizedBox(height: 8),
                  const RideXLogo(size: 74, textSize: 32),
                  const SizedBox(height: 30),
                  const Text(
                    'Verification Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'A 6-digit verification code has been sent to $_displayPhone. Please enter the OTP below to verify your mobile.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _mutedText,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 42),
                  if (_requesting || _verifying)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  else
                    Center(
                      child: SizedBox(
                        width: 340,
                        child: Row(
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
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  ] else if (_info != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _info!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.successGreen,
                        fontSize: 14,
                      ),
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
                      'Need to Change the mobile number?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: _surfaceDark,
                        foregroundColor: _requesting
                            ? _mutedText
                            : AppTheme.primaryBlue,
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
                      onPressed: (_requesting || _verifying)
                          ? null
                          : _resendOtp,
                      child: Text(
                        _requesting ? 'Sending...' : 'Resend code',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isComplete
                            ? AppTheme.actionBlue
                            : _inactiveDark,
                        foregroundColor: _isComplete
                            ? Colors.white
                            : const Color(0xFF77777A),
                        disabledBackgroundColor: _inactiveDark,
                        disabledForegroundColor: const Color(0xFF77777A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.buttonRadius,
                          ),
                        ),
                      ),
                      onPressed: (_isComplete && !auth.loading && !_verifying)
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
                              'VERIFY NOW',
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
