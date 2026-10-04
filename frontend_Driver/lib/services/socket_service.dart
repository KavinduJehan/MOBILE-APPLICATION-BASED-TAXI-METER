import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../models/ride_request.dart';

typedef OnNewRequestCallback = void Function(RideRequest request);

/// [event] is 'trip_ended' or 'trip_cancelled'; [tripId] is the trip it is for.
typedef OnTripClosedCallback = void Function(String event, String tripId);
typedef OnConfigUpdatedCallback = void Function(String rateMode, double? ratePerKm);

class DriverSocketService {
  DriverSocketService._();
  static final DriverSocketService instance = DriverSocketService._();

  io.Socket? _socket;
  String? _driverId;
  OnNewRequestCallback? _onNewRequest;
  OnTripClosedCallback? _onTripClosed;

  /// Hears about the trip being ended or cancelled from the customer's side.
  void listenForTripClosed(OnTripClosedCallback onClosed) =>
      _onTripClosed = onClosed;

  void stopListeningForTripClosed() => _onTripClosed = null;
  final List<OnConfigUpdatedCallback> _configListeners = [];

  bool get isConnected => _socket?.connected ?? false;

  void addConfigListener(OnConfigUpdatedCallback listener) {
    if (!_configListeners.contains(listener)) {
      _configListeners.add(listener);
    }
  }

  void removeConfigListener(OnConfigUpdatedCallback listener) {
    _configListeners.remove(listener);
  }

  void setOnNewRequest(OnNewRequestCallback callback) {
    _onNewRequest = callback;
  }

  void init({required String driverId, OnNewRequestCallback? onNewRequest}) {
    _driverId = driverId;
    if (onNewRequest != null) {
      _onNewRequest = onNewRequest;
    }

    if (_socket != null && _socket!.connected) {
      _socket!.emit('join', driverId);
      return;
    }

    final rawUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/api/?$'), '');

    _socket = io.io(
      rawUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          // A fresh socket each time: socket_io_client otherwise hands back
          // the cached one and every reconnect stacks duplicate listeners.
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected to server: $rawUrl');
      if (_driverId != null && _driverId!.isNotEmpty) {
        _socket!.emit('join', _driverId);
      }
    });

    for (final event in const ['trip_ended', 'trip_cancelled']) {
      _socket!.on(event, (data) {
        final tripId = data is Map ? data['tripId']?.toString() : null;
        if (tripId != null) _onTripClosed?.call(event, tripId);
      });
    }

    _socket!.on('new_request', (data) {
      debugPrint('[Socket] Received new_request event: $data');
      if (_onNewRequest != null && data is Map) {
        try {
          final request = RideRequest.fromJson(Map<String, dynamic>.from(data));
          _onNewRequest!(request);
        } catch (e) {
          debugPrint('[Socket] Error parsing new_request: $e');
        }
      }
    });

    _socket!.on('pricing_mode_changed', (data) {
      debugPrint('[Socket] Received pricing_mode_changed: $data');
      if (data is Map) {
        final mode = data['rateMode']?.toString() ?? 'ADMIN';
        final rate = data['ratePerKm'] != null ? (data['ratePerKm'] as num).toDouble() : null;
        for (final listener in List.of(_configListeners)) {
          listener(mode, rate);
        }
      }
    });

    _socket!.on('config_updated', (data) {
      debugPrint('[Socket] Received config_updated: $data');
      if (data is Map) {
        final mode = data['rateMode']?.toString() ?? 'ADMIN';
        final rate = data['autoBaseRate'] != null ? (data['autoBaseRate'] as num).toDouble() : null;
        for (final listener in List.of(_configListeners)) {
          listener(mode, rate);
        }
      }
    });

    _socket!.on('driver_profile_updated', (data) {
      debugPrint('[Socket] Received driver_profile_updated: $data');
      if (data is Map) {
        final mode = data['pricingMode']?.toString();
        final rate = data['ratePerKm'] != null ? (data['ratePerKm'] as num).toDouble() : null;
        if (mode != null) {
          for (final listener in List.of(_configListeners)) {
            listener(mode, rate);
          }
        }
      }
    });

    _socket!.on('driver_pricing_updated', (data) {
      debugPrint('[Socket] Received driver_pricing_updated: $data');
      if (data is Map) {
        final mode = data['pricingMode']?.toString();
        final targetDriverId = data['driverId']?.toString();
        if (targetDriverId == null || targetDriverId == _driverId) {
          final rate = data['ratePerKm'] != null ? (data['ratePerKm'] as num).toDouble() : null;
          if (mode != null) {
            for (final listener in List.of(_configListeners)) {
              listener(mode, rate);
            }
          }
        }
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected from server');
    });

    _socket!.connect();
  }

  void emitLocationUpdate({
    required double lat,
    required double lng,
    String? tripId,
    String? customerId,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('driver_location_update', {
        'driverId': _driverId,
        'lat': lat,
        'lng': lng,
        if (tripId != null && tripId.isNotEmpty) 'tripId': tripId,
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
      });
    }
  }

  void disconnect() {
    // dispose() also removes the event listeners registered on this socket.
    _socket?.dispose();
    _socket = null;
  }
}
