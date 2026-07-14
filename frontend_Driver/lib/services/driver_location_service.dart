import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'api_service.dart';

class DriverLocationService {
  DriverLocationService(this._api);

  final ApiService _api;
  Timer? _timer;
  bool _updating = false;
  String? _lastError;

  String? get lastError => _lastError;
  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (_timer != null) return;

    final allowed = await _ensurePermission();
    if (!allowed) return;

    await _publishCurrentLocation();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_publishCurrentLocation()),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _lastError = 'Location services are disabled.';
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _lastError = 'Location permission denied.';
      return false;
    }

    _lastError = null;
    return true;
  }

  Future<void> _publishCurrentLocation() async {
    if (_updating) return;
    _updating = true;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      await _api.updateLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _updating = false;
    }
  }
}
