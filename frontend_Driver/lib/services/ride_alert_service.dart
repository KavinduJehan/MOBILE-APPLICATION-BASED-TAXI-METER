import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/ride_request.dart';

const _viewAction = 'view_request';
const _ignoreAction = 'ignore_request';

/// Required by the plugin for actions that don't open the app ("Ignore");
/// the notification is already cancelled by the action itself.
@pragma('vm:entry-point')
void rideAlertBackgroundResponse(NotificationResponse response) {}

/// Shows the PickMe/Uber-style incoming ride alert: a max-priority, ringing,
/// full-screen notification that appears over other apps and the lock screen.
class RideAlertService {
  RideAlertService._();
  static final RideAlertService instance = RideAlertService._();

  static const _channelId = 'incoming_ride_requests';
  // Ring until answered, like an incoming call (Notification.FLAG_INSISTENT).
  static const int _flagInsistent = 4;
  static const Duration _alertTimeout = Duration(seconds: 60);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<RideRequest> _opened =
      StreamController<RideRequest>.broadcast();
  bool _initialized = false;
  RideRequest? _pendingOpen;

  /// Requests the driver chose to open from an alert while the app was running.
  Stream<RideRequest> get openedRequests => _opened.stream;

  /// A request whose alert relaunched the app after Android closed it; returned once.
  RideRequest? takePendingOpen() {
    final request = _pendingOpen;
    _pendingOpen = null;
    return request;
  }

  Future<void> initialize({bool checkLaunch = true}) async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: rideAlertBackgroundResponse,
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Incoming ride requests',
          description: 'Rings when a customer sends you a hire request.',
          importance: Importance.max,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        ),
      );
      if (!checkLaunch) return;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        _pendingOpen = _requestFrom(response);
      }
    } catch (error) {
      debugPrint('[RideAlert] init failed: $error');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Android 13+ notification permission. The system only shows its prompt
  /// while undecided, so calling this on every launch never re-nags.
  Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (error) {
      debugPrint('[RideAlert] permission request failed: $error');
    }
  }

  Future<void> showIncomingRequest(RideRequest request) async {
    if (request.id.isEmpty) return;
    await initialize(checkLaunch: false);

    final distance = '${request.estimatedDistanceKm.toStringAsFixed(1)} km';
    final rate = request.suggestedRatePerKm ?? request.driverRatePerKm;
    final pickup = request.pickupAddress.isEmpty
        ? 'Pickup on map'
        : request.pickupAddress;
    final dropOff = request.destinationAddress.isEmpty
        ? 'Drop-off on map'
        : request.destinationAddress;
    final title = 'New ride request · $distance';
    final details = 'Pickup: $pickup\nDrop-off: $dropOff';

    final android = AndroidNotificationDetails(
      _channelId,
      'Incoming ride requests',
      channelDescription: 'Rings when a customer sends you a hire request.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      additionalFlags: Int32List.fromList([_flagInsistent]),
      // The socket and the 3s poll can both report the same request: ring once.
      onlyAlertOnce: true,
      timeoutAfter: _alertTimeout.inMilliseconds,
      autoCancel: true,
      color: const Color(0xFF2F6BFF),
      ticker: title,
      styleInformation: BigTextStyleInformation(
        details,
        contentTitle: '$title — ${request.customerName}',
        summaryText: 'Rs. ${rate.toStringAsFixed(2)} / km',
      ),
      actions: const [
        AndroidNotificationAction(
          _viewAction,
          'View request',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _ignoreAction,
          'Ignore',
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.show(
        id: notificationIdFor(request.id),
        title: '$title — ${request.customerName}',
        body: 'Pickup: $pickup',
        notificationDetails: NotificationDetails(android: android),
        payload: jsonEncode(request.toJson()),
      );
    } catch (error) {
      debugPrint('[RideAlert] show failed: $error');
    }
  }

  Future<void> cancelFor(String requestId) async {
    if (requestId.isEmpty) return;
    try {
      await _plugin.cancel(id: notificationIdFor(requestId));
    } catch (_) {}
  }

  void _onResponse(NotificationResponse response) {
    if (response.actionId == _ignoreAction) return;
    final request = _requestFrom(response);
    if (request != null) _opened.add(request);
  }

  RideRequest? _requestFrom(NotificationResponse response) {
    if (response.actionId == _ignoreAction) return null;
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload);
      if (data is! Map) return null;
      return RideRequest.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Stable across app restarts (unlike String.hashCode), so repeat reports of
  /// the same request update one notification instead of stacking.
  @visibleForTesting
  static int notificationIdFor(String requestId) {
    var hash = 0x811c9dc5;
    for (final unit in requestId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
