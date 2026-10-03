import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'services/ride_alert_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RideAlertService.instance.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const RideXDriverApp(),
    ),
  );
}
