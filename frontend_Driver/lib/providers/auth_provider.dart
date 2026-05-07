import 'package:flutter/material.dart';

import '../models/api_exception.dart';
import '../models/driver_profile.dart';
import '../services/api_service.dart';
import '../services/session_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() : api = ApiService();

  final ApiService api;

  bool _bootstrapping = true;
  bool _busy = false;
  String? _errorMessage;
  String? _token;
  DriverProfile? _profile;

  bool get bootstrapping => _bootstrapping;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;
  String? get token => _token;
  DriverProfile? get profile => _profile;
  bool get isAuthenticated => _token != null;

  Future<void> bootstrap() async {
    if (!_bootstrapping) {
      return;
    }
    _setBusy(true);
    try {
      _token = await SessionStore.readToken();
      if (_token != null) {
        // Try reading a locally persisted profile (used for offline/demo mode)
        _profile = await SessionStore.readProfile() ?? await api.getProfile();
      }
    } catch (error) {
      await SessionStore.clear();
      _token = null;
      _profile = null;
      _errorMessage = _messageFrom(error);
    } finally {
      _bootstrapping = false;
      _setBusy(false);
    }
  }

  Future<void> login({required String email, required String password}) async {
    _setBusy(true);
    try {
      final result = await api.login(email: email, password: password);
      _token = result.token;
      await SessionStore.saveToken(result.token);
      _profile = result.profile ?? await api.getProfile();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<String> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String licenseNumber,
    required String vehicleNumber,
    required String area,
  }) async {
    _setBusy(true);
    try {
      final message = await api.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
        licenseNumber: licenseNumber,
        vehicleNumber: vehicleNumber,
        area: area,
      );
      _errorMessage = null;
      return message;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> loadProfile({bool force = false}) async {
    if (!force && _profile != null) {
      return;
    }
    if (_token == null) {
      return;
    }
    _setBusy(true);
    try {
      _profile = await api.getProfile();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _messageFrom(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> updateRate(double ratePerKm) async {
    _setBusy(true);
    try {
      await api.updateRate(ratePerKm);
      _profile = _profile?.copyWith(ratePerKm: ratePerKm);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> refreshQr() async {
    _setBusy(true);
    try {
      final result = await api.generateQr();
      _profile = _profile?.copyWith(qrCode: result.qrCode) ?? _profile;
      if (_profile == null) {
        await loadProfile(force: true);
      }
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    await SessionStore.clear();
    _token = null;
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  String _messageFrom(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }
}