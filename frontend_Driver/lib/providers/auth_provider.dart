import 'package:flutter/material.dart';

import '../models/api_exception.dart';
import '../models/driver_profile.dart';
import '../services/api_service.dart';
import '../services/driver_location_service.dart';
import '../services/offline_database.dart';
import '../services/session_store.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _locationService = DriverLocationService(api);
    DriverSocketService.instance.addConfigListener(_handleSocketConfigUpdate);
  }

  void _handleSocketConfigUpdate(String mode, double? rate) {
    debugPrint('[AuthProvider] Live socket config received: mode=$mode, rate=$rate');
    _systemRateMode = mode;
    if (_profile != null) {
      _profile = _profile!.copyWith(
        pricingMode: mode,
        ratePerKm: rate ?? _profile!.ratePerKm,
      );
      OfflineDatabase.instance.cacheProfile(_profile!);
      SessionStore.saveProfile(_profile!);
    }
    notifyListeners();
  }


  final ApiService api = ApiService();
  late final DriverLocationService _locationService;

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
  String? get locationError => _locationService.lastError;
  bool get locationUpdatesRunning => _locationService.isRunning;
  DateTime? get lastLocationUpdate => _locationService.lastSuccessfulUpdate;

  String? _systemRateMode;

  String get rateMode => _systemRateMode ?? _profile?.pricingMode ?? 'ADMIN';

  Future<void> bootstrap() async {
    if (!_bootstrapping) {
      return;
    }
    _setBusy(true);
    try {
      _token = await SessionStore.readToken();
      if (_token != null) {
        // Fetch current public config from server
        try {
          final config = await api.getPublicConfig();
          if (config['rateMode'] != null) {
            _systemRateMode = config['rateMode'].toString();
          }
        } catch (_) {}

        try {
          _profile = await api.getProfile();
          if (_systemRateMode != null && _profile != null) {
            _profile = _profile!.copyWith(pricingMode: _systemRateMode);
          }
          if (_profile != null) {
            await OfflineDatabase.instance.cacheProfile(_profile!);
            await SessionStore.saveProfile(_profile!);
            DriverSocketService.instance.init(driverId: _profile!.id);
          }
        } catch (_) {
          _profile = await SessionStore.readProfile() ?? await OfflineDatabase.instance.getCachedProfile();
          if (_systemRateMode != null && _profile != null) {
            _profile = _profile!.copyWith(pricingMode: _systemRateMode);
          }
        }
      }
    } catch (error) {
      // Offline fallback: don't wipe token immediately if server unreachable
      _profile ??= await OfflineDatabase.instance.getCachedProfile();
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

      try {
        final config = await api.getPublicConfig();
        if (config['rateMode'] != null) {
          _systemRateMode = config['rateMode'].toString();
        }
      } catch (_) {}

      _profile = result.profile ?? await api.getProfile();
      if (_systemRateMode != null && _profile != null) {
        _profile = _profile!.copyWith(pricingMode: _systemRateMode);
      }
      if (_profile != null) {
        await OfflineDatabase.instance.cacheProfile(_profile!);
        await SessionStore.saveProfile(_profile!);
        DriverSocketService.instance.init(driverId: _profile!.id);
      }
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    _setBusy(true);
    try {
      final res = await api.forgotPassword(email);
      _errorMessage = null;
      return res;
    } catch (error) {
      _errorMessage = _messageFrom(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _setBusy(true);
    try {
      final res = await api.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      _errorMessage = null;
      return res;
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
    String area = '',
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
      try {
        final config = await api.getPublicConfig();
        if (config['rateMode'] != null) {
          _systemRateMode = config['rateMode'].toString();
        }
      } catch (_) {}

      _profile = await api.getProfile();
      if (_systemRateMode != null && _profile != null) {
        _profile = _profile!.copyWith(pricingMode: _systemRateMode);
      }
      if (_profile != null) {
        await OfflineDatabase.instance.cacheProfile(_profile!);
        await SessionStore.saveProfile(_profile!);
        DriverSocketService.instance.init(driverId: _profile!.id);
      }
      _errorMessage = null;
    } catch (error) {
      _profile ??= await OfflineDatabase.instance.getCachedProfile();
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
      if (_profile != null) {
        await OfflineDatabase.instance.cacheProfile(_profile!);
      }
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
    _locationService.stop();
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

  Future<void> startLocationUpdates() async {
    await _startLocationUpdates();
    notifyListeners();
  }

  void stopLocationUpdates() {
    _locationService.stop();
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  Future<void> _startLocationUpdates() async {
    if (_token == null || _locationService.isRunning) return;
    await _locationService.start();
    if (_locationService.lastError != null) {
      _errorMessage = _locationService.lastError;
    }
  }

  String _messageFrom(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  @override
  void dispose() {
    DriverSocketService.instance.removeConfigListener(_handleSocketConfigUpdate);
    _locationService.stop();
    super.dispose();
  }
}
