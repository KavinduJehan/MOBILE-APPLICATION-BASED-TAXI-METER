import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/driver_profile.dart';

class SessionStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'ridex_driver_jwt';
  static const String _profileKey = 'ridex_driver_profile';

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  static Future<void> saveProfile(DriverProfile profile) => _storage.write(key: _profileKey, value: jsonEncode({
        'name': profile.name,
        'phone': profile.phone,
        'email': profile.email,
        'licenseNumber': profile.licenseNumber,
        'vehicleNumber': profile.vehicleNumber,
        'area': profile.area,
        'ratePerKm': profile.ratePerKm,
        'pricingMode': profile.pricingMode,
        'isVerified': profile.isVerified,
        'qrCode': profile.qrCode,
      }));

  static Future<DriverProfile?> readProfile() async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return DriverProfile.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _profileKey);
  }
}
