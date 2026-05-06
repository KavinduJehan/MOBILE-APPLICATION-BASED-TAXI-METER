import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/onboarding_screen.dart';
import '../providers/auth_provider.dart';
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

  final _passwordController = TextEditingController();
  bool _obscure = true;

  bool get _isComplete => _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_isComplete) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithEmail(
      widget.emailAddress,
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
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
                Icons.lock_rounded,
                color: AppTheme.primaryBlue,
                size: 58,
              ),
              const SizedBox(height: 22),
              const Text(
                'Enter Password',
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
                'Signing in as ${widget.emailAddress}',
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
              // ── Password field ────────────────────────────────────────────
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: AppTheme.primaryBlue,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: _mutedText),
                  filled: true,
                  fillColor: _surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: _mutedText,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 16),
              // ── Error message ─────────────────────────────────────────────
              if (auth.error != null)
                Text(
                  auth.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 15),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () {
                  auth.clearError();
                  Navigator.maybePop(context);
                },
                child: const Text(
                  'Use a different email',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              // ── Login button ──────────────────────────────────────────────
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: (_isComplete && !auth.loading) ? _login : null,
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
                          'Sign In',
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
