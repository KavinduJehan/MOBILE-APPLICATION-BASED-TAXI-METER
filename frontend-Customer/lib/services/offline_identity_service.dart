import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineIdentityService {
  static Future<String?> cached(String customerId) async {
    final proof = (await SharedPreferences.getInstance()).getString(
      'offline_identity_$customerId',
    );
    if (proof == null) {
      return null;
    }
    try {
      final parts = proof.split('.');
      if (parts.length != 2) return null;
      final claim =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts.first))),
              )
              as Map;
      if (claim['customerId'] != customerId ||
          claim['expiresAt'] is! num ||
          (claim['expiresAt'] as num) <=
              DateTime.now().millisecondsSinceEpoch) {
        return null;
      }
      return proof; // Display expiry locally; the server still verifies the signature.
    } catch (_) {
      return null;
    }
  }

  static Future<void> prepare(String customerId) async {
    final response = await ApiService.dio.get(
      '/trips/offline-identity',
      options: Options(
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );
    await (await SharedPreferences.getInstance()).setString(
      'offline_identity_$customerId',
      (response.data as Map)['identity'] as String,
    );
  }
}
