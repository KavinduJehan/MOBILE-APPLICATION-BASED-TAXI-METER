import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';

typedef OnRequestResponseCallback = void Function(Map<String, dynamic> data);
typedef OnDriverLocationCallback = void Function(Map<String, dynamic> data);
typedef OnTripEndedCallback = void Function(Map<String, dynamic> data);

/// [event] is 'driver_arrived', 'trip_started' or 'trip_cancelled'.
typedef OnTripEventCallback =
    void Function(String event, Map<String, dynamic> data);

class CustomerSocketService {
  CustomerSocketService._();
  static final CustomerSocketService instance = CustomerSocketService._();

  io.Socket? _socket;
  String? _requestId;
  String? _tripId;
  OnRequestResponseCallback? _onResponse;
  OnDriverLocationCallback? _onDriverLocation;
  OnTripEndedCallback? _onTripEnded;
  OnTripEventCallback? _onTripEvent;

  bool get isConnected => _socket?.connected ?? false;

  void _ensureSocket() {
    if (_socket != null) return;

    final socketUrl = ApiService.socketUrl;
    _socket = io.io(
      socketUrl,
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
      debugPrint('[CustomerSocket] Connected to $socketUrl');
      if (_requestId != null && _requestId!.isNotEmpty) {
        _socket!.emit('join', _requestId);
      }
      if (_tripId != null && _tripId!.isNotEmpty) {
        _socket!.emit('join', _tripId);
        _socket!.emit('join_trip', _tripId);
      }
    });

    _socket!.on('request_response', (data) {
      debugPrint('[CustomerSocket] Received request_response: $data');
      if (_onResponse != null && data is Map) {
        _onResponse!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('driver_location', (data) {
      debugPrint('[CustomerSocket] Received driver_location: $data');
      if (_onDriverLocation != null && data is Map) {
        _onDriverLocation!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip_ended', (data) {
      debugPrint('[CustomerSocket] Received trip_ended: $data');
      if (_onTripEnded != null && data is Map) {
        _onTripEnded!(Map<String, dynamic>.from(data));
      }
    });

    for (final event in const [
      'driver_arrived',
      'trip_started',
      'trip_cancelled',
    ]) {
      _socket!.on(event, (data) {
        debugPrint('[CustomerSocket] Received $event: $data');
        if (_onTripEvent != null && data is Map) {
          _onTripEvent!(event, Map<String, dynamic>.from(data));
        }
      });
    }

    _socket!.onDisconnect((_) {
      debugPrint('[CustomerSocket] Disconnected');
    });

    _socket!.connect();
  }

  void listenToRequest({
    required String requestId,
    required OnRequestResponseCallback onResponse,
  }) {
    _requestId = requestId;
    _onResponse = onResponse;

    _ensureSocket();
    if (_socket!.connected) {
      _socket!.emit('join', requestId);
    }
  }

  void listenToTrip({
    required String tripId,
    OnDriverLocationCallback? onLocation,
    OnTripEndedCallback? onTripEnded,
    OnTripEventCallback? onTripEvent,
  }) {
    _tripId = tripId;
    _onDriverLocation = onLocation;
    _onTripEnded = onTripEnded;
    _onTripEvent = onTripEvent;

    _ensureSocket();
    if (_socket!.connected) {
      _socket!.emit('join', tripId);
      _socket!.emit('join_trip', tripId);
    }
  }

  void stopListeningTrip() {
    _onDriverLocation = null;
    _onTripEnded = null;
    _onTripEvent = null;
  }

  void disconnect() {
    // dispose() also removes the event listeners registered on this socket.
    _socket?.dispose();
    _socket = null;
  }
}
