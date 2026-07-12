import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await auth.bootstrap();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => auth.isAuthenticated ? const DriverHomeScreen() : const LoginScreen(),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return const AppShellScaffold(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DriverLogo(size: 120),
              SizedBox(height: 24),
              Text(
                'Fair rides, clear fares, safer trips',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}