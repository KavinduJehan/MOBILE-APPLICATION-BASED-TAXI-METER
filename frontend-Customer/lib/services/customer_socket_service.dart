import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';

typedef OnRequestResponseCallback = void Function(Map<String, dynamic> data);

class CustomerSocketService {
  CustomerSocketService._();
  static final CustomerSocketService instance = CustomerSocketService._();

  io.Socket? _socket;
  String? _requestId;
  OnRequestResponseCallback? _onResponse;

  bool get isConnected => _socket?.connected ?? false;

  void listenToRequest({
    required String requestId,
    required OnRequestResponseCallback onResponse,
  }) {
    _requestId = requestId;
    _onResponse = onResponse;

    if (_socket != null && _socket!.connected) {
      _socket!.emit('join', requestId);
      return;
    }

    // Resolve socket host by stripping /api
    final socketUrl = ApiService.socketUrl;

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[CustomerSocket] Connected to $socketUrl');
      if (_requestId != null && _requestId!.isNotEmpty) {
        _socket!.emit('join', _requestId);
      }
    });

    _socket!.on('request_response', (data) {
      debugPrint('[CustomerSocket] Received request_response: $data');
      if (_onResponse != null && data is Map) {
        _onResponse!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[CustomerSocket] Disconnected');
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
