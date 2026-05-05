import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

/// Represents the logged-in driver returned by the backend.
class DriverModel {
  final String id;
  final String name;
  final String email;
  final String role;

  const DriverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) => DriverModel(
    id: json['id'] as String,
    name: json['name'] as String,
    email: (json['email'] as String?) ?? '',
    role: json['role'] as String,
  );
}

/// Shared authentication state — wrap MaterialApp with ChangeNotifierProvider.
class AuthProvider extends ChangeNotifier {
  DriverModel? _driver;
  String? _token;
  bool _loading = false;
  String? _error;

  DriverModel? get driver => _driver;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get loading => _loading;
  String? get error => _error;

  // Session restore is in-memory only for now (no persistence across app restarts).
  // Re-add flutter_secure_storage + tryRestoreSession when deploying to production.
  Future<void> tryRestoreSession() async {}

  // ── Email + password login ────────────────────────────────────────────────

  Future<bool> loginWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final res = await ApiService.login(email, password);
      final data = res.data as Map<String, dynamic>;
      await _persistSession(data);
      return true;
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Login failed';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Phone OTP login skipped for now — add back when Firebase is configured.

  // ── Registration ──────────────────────────────────────────────────────────

  Future<bool> registerWithEmail(Map<String, dynamic> body) async {
    _setLoading(true);
    try {
      final res = await ApiService.register(body);
      final data = res.data as Map<String, dynamic>;
      await _persistSession(data);
      return true;
    } on DioException catch (e) {
      _error = e.error?.toString() ?? 'Registration failed';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    ApiService.clearToken();
    _token = null;
    _driver = null;
    _error = null;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    _token = data['token'] as String;
    _driver = DriverModel.fromJson(data['driver'] as Map<String, dynamic>);
    await ApiService.saveToken(_token!);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
