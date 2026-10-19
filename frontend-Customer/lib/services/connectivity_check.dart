import 'dart:io';

import 'package:dio/dio.dart';

import 'api_service.dart';

/// Real reachability check: opens a TCP connection to the API host instead of
/// assuming "no internet" whenever a request fails or the offline flow is used.
Future<bool> hasInternetConnection({
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    final uri = Uri.parse(ApiService.dio.options.baseUrl);
    final port = uri.hasPort ? uri.port : (uri.scheme == 'http' ? 80 : 443);
    final socket = await Socket.connect(uri.host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// True when [error] means the server could not be reached at all (as opposed
/// to the server answering with an error such as 404).
bool isNetworkFailure(Object error) =>
    error is DioException && error.response == null;
