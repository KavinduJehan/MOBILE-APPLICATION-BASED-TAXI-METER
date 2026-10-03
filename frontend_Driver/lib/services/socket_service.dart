import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../models/ride_request.dart';

typedef OnNewRequestCallback = void Function(RideRequest request);

class DriverSocketService {
  DriverSocketService._();
  static final DriverSocketService instance = DriverSocketService._();

  io.Socket? _socket;
  String? _driverId;
  OnNewRequestCallback? _onNewRequest;

  bool get isConnected => _socket?.connected ?? false;

  void init({required String driverId, required OnNewRequestCallback onNewRequest}) {
    _driverId = driverId;
    _onNewRequest = onNewRequest;

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
