import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/customer_model.dart';

/// Shared authentication state — wrap MaterialApp with ChangeNotifierProvider.
class AuthProvider extends ChangeNotifier {
  CustomerModel? _customer;
  String? _token;
  bool _loading = false;
  String? _error;

  CustomerModel? get customer => _customer;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get loading => _loading;
  String? get error => _error;

  /// Restore session from persistent storage on app start.
  /// This is called before the app UI is rendered to ensure seamless login state.
  Future<void> tryRestoreSession() async {
    try {
      final token = await ApiService.loadStoredToken();
      final customerData = await ApiService.getCustomer();

      if (token != null && customerData != null) {
        _token = token;
        _customer = CustomerModel.fromJson(customerData);
        _error = null;
        if (kDebugMode) {
          print('✓ Session restored successfully for ${_customer?.name}');
        }
      } else {
        if (kDebugMode) {
          print('No valid session found — user needs to log in');
        }
      }
    } catch (e) {
      // Silently fail — user will need to log in
      if (kDebugMode) {
        print('⚠ Failed to restore session: $e');
      }
      _token = null;
      _customer = null;
    } finally {
      notifyListeners();
    }
  }

  // ── Request OTP (triggers SMS / console log) ──────────────────────────────

  Future<bool> requestOtp(String phone) async {
    _setLoading(true);
    try {
      await ApiService.customerRequestOtp(phone);
      return true;
    } on DioException catch (e) {
      _error = _extractMessage(e) ?? 'Failed to send OTP';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Verify OTP → log in ───────────────────────────────────────────────────

  Future<bool> verifyOtp(String phone, String otp) async {
    _setLoading(true);
    try {
      final res = await ApiService.customerVerifyOtp(phone, otp);
      final data = res.data as Map<String, dynamic>;
      _token = data['token'] as String;
      final customerData = data['customer'] as Map<String, dynamic>;
      _customer = CustomerModel.fromJson(customerData);
      
      // Persist token and customer data for session restore
      await ApiService.saveToken(_token!);
      await ApiService.saveCustomer(customerData);
      
      _error = null;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractMessage(e) ?? 'OTP verification failed';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Register new customer ─────────────────────────────────────────────────

  Future<bool> register(String name, String phone) async {
    _setLoading(true);
    try {
      await ApiService.customerRegister(name, phone);
      _error = null;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractMessage(e) ?? 'Registration failed';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await ApiService.clearToken();
    _token = null;
    _customer = null;
    _error = null;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String? _extractMessage(DioException e) =>
      e.error?.toString().isNotEmpty == true ? e.error.toString() : null;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
