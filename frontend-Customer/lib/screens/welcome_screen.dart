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
    final screenSize = MediaQuery.sizeOf(context);
    final logoSize = (screenSize.width * 0.22).clamp(68.0, 84.0);
    final logoTextSize = (screenSize.width * 0.097).clamp(30.0, 38.0);
    final horizontalPadding = (screenSize.width * 0.07).clamp(20.0, 28.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      RideXLogo(size: logoSize, textSize: logoTextSize),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome to RideX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 36),
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
                      const SizedBox(height: 24),
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
          },
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

class _WelcomeButtonState extends State<_WelcomeButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;
  late final AnimationController _shineController;
  late final Animation<double> _shineOpacity;

  bool get _isActive => _isHovered || _isFocused || _isPressed;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shineOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_shineController);
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  void _playShine() {
    _shineController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: FocusableActionDetector(
        onShowFocusHighlight: (focused) {
          setState(() => _isFocused = focused);
          if (focused) _playShine();
        },
        mouseCursor: SystemMouseCursors.click,
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _playShine();
          },
          onExit: (_) => setState(() {
            _isHovered = false;
            _isPressed = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _playShine();
            },
            onTapCancel: () => setState(() => _isPressed = false),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTap: widget.onTap,
            child: AnimatedContainer(
              height: 56,
              duration: const Duration(milliseconds: 200),
              curve: _isActive ? Curves.easeOut : Curves.easeIn,
              decoration: BoxDecoration(
                color: _isActive ? AppTheme.primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppTheme.primaryBlue),
                boxShadow: _isActive && !_isPressed
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF008EEC,
                          ).withValues(alpha: 0.82),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _shineController,
                          builder: (context, child) {
                            return Positioned(
                              left:
                                  -40 +
                                  (constraints.maxWidth + 80) *
                                      _shineController.value,
                              top: 4,
                              bottom: 4,
                              child: Opacity(
                                opacity: _shineOpacity.value,
                                child: Transform(
                                  transform: Matrix4.skewX(-0.35),
                                  child: Container(
                                    width: 3,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 30,
                                          spreadRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Text(
                          widget.label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
