import 'package:flutter/material.dart';

import '../authentication/auth_screen.dart';
import '../authentication/customer_signup_screen.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openCreateAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerSignupScreen()),
    );
  }

  void _openSignIn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const RideXLogo(size: 84, textSize: 38),
              const SizedBox(height: 30),
              const Text(
                'Welcome to RideX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 56),
              const Text(
                "I'm new to RideX",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _WelcomeButton(
                label: 'Get Started',
                onTap: () => _openCreateAccount(context),
              ),
              const SizedBox(height: 34),
              const Text(
                'Already connected?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _WelcomeButton(
                label: 'Sign In',
                onTap: () => _openSignIn(context),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
