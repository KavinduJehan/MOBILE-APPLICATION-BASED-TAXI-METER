import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineIdentityService {
  static Future<String?> cached(String customerId) async =>
      (await SharedPreferences.getInstance()).getString(
        'offline_identity_$customerId',
      );
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
