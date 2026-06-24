import 'package:flutter/material.dart';

import '../theme.dart';

class RideXLogo extends StatelessWidget {
  const RideXLogo({
    super.key,
    this.size = 84,
    this.showText = true,
    this.textSize = 40,
  });

  final double size;
  final bool showText;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF3C7BFF), Color(0xFF1C4FD6)],
              radius: 0.95,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x552F6BFF),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Icon(
            Icons.navigation_rounded,
            size: size * 0.48,
            color: Colors.white,
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'RideX',
            style: TextStyle(
              color: Colors.white,
              fontSize: textSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class AppGradientScaffold extends StatelessWidget {
  const AppGradientScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.background, Color(0xFF070A12), Color(0xFF0A1020)],
        ),
      ),
      child: child,
    );
  }
}
