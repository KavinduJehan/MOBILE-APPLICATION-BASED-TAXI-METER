import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/nearby_drivers_provider.dart';
import 'providers/rate_provider.dart';
import 'providers/trip_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.tryRestoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => NearbyDriversProvider()),
        ChangeNotifierProvider(create: (_) => RateProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: const SmartTaxiMeterApp(),
    ),
  );
}

class SmartTaxiMeterApp extends StatelessWidget {
  const SmartTaxiMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}

class MobileFrame extends StatelessWidget {
  final Widget child;
  final Color outerColor;

  const MobileFrame({
    super.key,
    required this.child,
    this.outerColor = const Color(0xFFE5E7EB),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: outerColor,
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
