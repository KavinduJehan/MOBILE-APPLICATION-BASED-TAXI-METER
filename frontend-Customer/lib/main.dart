import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryRestoreSession(),
      child: const SmartTaxiMeterApp(),
    ),
  );
}

class SmartTaxiMeterApp extends StatelessWidget {
  const SmartTaxiMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Taxi Meter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MobileFrame(child: SplashScreen()),
    );
  }
}

class MobileFrame extends StatelessWidget {
  final Widget child;

  const MobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: Center(
        child: Container(
          width: 390,
          height: 844,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
