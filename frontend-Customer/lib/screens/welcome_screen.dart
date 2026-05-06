import 'package:flutter/material.dart';

import '../authentication/auth_screen.dart';
import '../theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const _MeterLogo(),
              const SizedBox(height: 44),
              const Text(
                'RideX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(flex: 4),

              const SizedBox(height: 16),
              const Text(
                'Fair rides, clear fares, safer trips',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8A8A8A),
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 72),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                child: const Text.rich(
                  TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: 'Sign In',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeterLogo extends StatelessWidget {
  const _MeterLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 160,
      height: 128,
      child: CustomPaint(painter: _MeterLogoPainter()),
    );
  }
}

class _MeterLogoPainter extends CustomPainter {
  const _MeterLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const mint = AppTheme.primaryBlue;
    final center = Offset(size.width * 0.5, size.height * 0.62);
    final radius = size.width * 0.42;

    final arcPaint = Paint()
      ..color = mint
      ..strokeWidth = 26
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.05,
      4.02,
      false,
      arcPaint,
    );

    final needlePaint = Paint()
      ..color = mint
      ..style = PaintingStyle.fill;

    final needle = Path()
      ..moveTo(center.dx + 2, center.dy - 12)
      ..lineTo(size.width * 0.98, center.dy)
      ..lineTo(center.dx + 2, center.dy + 12)
      ..close();
    canvas.drawPath(needle, needlePaint);

    canvas.drawCircle(center, 22, needlePaint);

    final innerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
