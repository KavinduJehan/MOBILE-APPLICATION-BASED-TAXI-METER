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

class _WelcomeButton extends StatefulWidget {
  const _WelcomeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isActive => _isHovered || _isFocused || _isPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isActive
        ? AppTheme.primaryBlue
        : AppTheme.primaryBlue.withValues(alpha: 0.18);
    final textColor = _isActive ? Colors.white : AppTheme.primaryBlue;

    return FocusableActionDetector(
      onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
      mouseCursor: SystemMouseCursors.click,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            height: 56,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isActive
                    ? AppTheme.primaryBlue
                    : AppTheme.primaryBlue.withValues(alpha: 0.34),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
