import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    return kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
  }
}
