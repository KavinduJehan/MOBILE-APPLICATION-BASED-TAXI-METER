import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/active_trip_provider.dart';
import 'providers/auth_provider.dart';
import 'services/ride_alert_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RideAlertService.instance.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ActiveTripProvider()),
      ],
      child: const RideXDriverApp(),
    ),
  );
}
