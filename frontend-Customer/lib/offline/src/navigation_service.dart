import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'navigation_graph.dart';

/// One persistent worker keeps the country graph off the UI isolate.
class OfflineNavigationService {
  OfflineNavigationService._();
  static final instance = OfflineNavigationService._();
  Future<void>? _loading;
  SendPort? _worker;
  Isolate? _isolate;
  ReceivePort? _replies;
  int _sequence = 0;
  final _pending = <int, Completer<Map<String, dynamic>>>{};

  Future<void> _load() => _loading ??= _start();
  Future<void> _start() async {
    final replies = ReceivePort();
    _replies = replies;
    final ready = Completer<void>();
    replies.listen((dynamic message) {
      if (message is SendPort) {
        _worker = message;
        ready.complete();
      } else if (message is Map) {
        final id = message['id'] as int;
        final request = _pending.remove(id);
        if (message['error'] != null) {
          request?.completeError(FormatException(message['error'].toString()));
        } else {
          request?.complete(
            Map<String, dynamic>.from(message['result'] as Map),
          );
        }
      } else if (message is String || message is List || message == null) {
        final error = FormatException(
          message is String
              ? message
              : 'The offline navigation worker stopped. Try again.',
        );
        if (!ready.isCompleted) ready.completeError(error);
        _close(error);
      }
    });
    try {
      final data = await rootBundle.load(
        'assets/offline/sri_lanka.nav.gz',
      );
      _isolate = await Isolate.spawn(
        _navigationWorker,
        [
          replies.sendPort,
          TransferableTypedData.fromList([
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ]),
        ],
        onError: replies.sendPort,
        onExit: replies.sendPort,
      );
      await ready.future;
    } catch (_) {
      replies.close();
      _loading = null;
      rethrow;
    }
  }

  /// Release the country graph when navigation is no longer required.
  void close() => _close(const FormatException('Offline navigation closed.'));
  void _close(Object error) {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _replies?.close();
    _replies = null;
    _worker = null;
    _loading = null;
    for (final request in _pending.values) {
      request.completeError(error);
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> request(
    String command,
    Map<String, dynamic> arguments,
  ) async {
    await _load();
    final id = ++_sequence;
    final completion = Completer<Map<String, dynamic>>();
    _pending[id] = completion;
    _worker!.send({'id': id, 'command': command, 'arguments': arguments});
    return completion.future;
  }
}

void _navigationWorker(List<dynamic> initial) {
  final reply = initial[0] as SendPort;
  try {
    final compressed = (initial[1] as TransferableTypedData)
        .materialize()
        .asUint8List();
    final graph = NavigationGraph(Uint8List.fromList(gzip.decode(compressed)));
    final commands = ReceivePort();
    reply.send(commands.sendPort);
    commands.listen((dynamic raw) {
      final message = raw as Map;
      final args = message['arguments'] as Map;
      try {
        double value(String key) => (args[key] as num).toDouble();
        final result = switch (message['command']) {
          'info' => {
            'region': graph.metadata['region'],
            'sourceTimestamp': graph.metadata['sourceTimestamp'],
            'landmarks': (graph.metadata['landmarks'] as List? ?? []).length,
          },
          'route' => graph.route(
            value('startLat'),
            value('startLon'),
            value('endLat'),
            value('endLon'),
            args['profile'] as String,
          ),
          'viewport' => graph.viewport(
            value('south'),
            value('west'),
            value('north'),
            value('east'),
            value('zoom'),
          ),
          'search' => {
            'places': graph.search(
              args['query'] as String,
              latitude: (args['latitude'] as num?)?.toDouble(),
              longitude: (args['longitude'] as num?)?.toDouble(),
            ),
          },
          _ => throw const FormatException('Unknown navigation request.'),
        };
        reply.send({'id': message['id'], 'result': result});
      } catch (error) {
        reply.send({'id': message['id'], 'error': error.toString()});
      }
    });
  } catch (error) {
    reply.send(error.toString());
  }
}
