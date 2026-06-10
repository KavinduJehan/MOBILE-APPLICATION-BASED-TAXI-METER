import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Manages persistent user session with expiry and auto-logout capabilities.
class SessionManager {
  static const String _sessionKey = 'session_data';
  static const String _expiryKey = 'session_expiry';
  static const int _sessionDurationDays = 7;
  
  final SharedPreferences _prefs;
  Timer? _expiryTimer;

  SessionManager(this._prefs);

  /// Initialize session with auto-logout timer if session exists
  Future<bool> initializeSession() async {
    if (hasActiveSession()) {
      _startExpiryTimer();
      return true;
    }
    return false;
  }

  /// Create a new session
  Future<void> createSession(Map<String, dynamic> sessionData) async {
    final expiryTime = DateTime.now().add(
      const Duration(days: _sessionDurationDays),
    ).millisecondsSinceEpoch;
    
    await _prefs.setString(_sessionKey, _encodeSession(sessionData));
    await _prefs.setInt(_expiryKey, expiryTime);
    
    _startExpiryTimer();
  }

  /// Check if an active (non-expired) session exists
  bool hasActiveSession() {
    final expiryTime = _prefs.getInt(_expiryKey);
    if (expiryTime == null) return false;
    
    final isExpired = DateTime.now().millisecondsSinceEpoch > expiryTime;
    if (isExpired) {
      clearSession();
      return false;
    }
    return true;
  }

  /// Get remaining session time in minutes
  int? getSessionRemainingMinutes() {
    final expiryTime = _prefs.getInt(_expiryKey);
    if (expiryTime == null) return null;
    
    final remaining = DateTime.fromMillisecondsSinceEpoch(expiryTime)
        .difference(DateTime.now())
        .inMinutes;
    
    return remaining > 0 ? remaining : 0;
  }

  /// Refresh session expiry (extend the timeout)
  Future<void> refreshSession() async {
    if (hasActiveSession()) {
      final expiryTime = DateTime.now().add(
        const Duration(days: _sessionDurationDays),
      ).millisecondsSinceEpoch;
      
      await _prefs.setInt(_expiryKey, expiryTime);
      _startExpiryTimer();
    }
  }

  /// Clear session completely
  Future<void> clearSession() async {
    _expiryTimer?.cancel();
    await _prefs.remove(_sessionKey);
    await _prefs.remove(_expiryKey);
  }

  /// Start auto-logout timer
  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    
    final remaining = getSessionRemainingMinutes();
    if (remaining != null && remaining > 0) {
      _expiryTimer = Timer(
        Duration(minutes: remaining),
        clearSession,
      );
    }
  }

  /// Encode session data (basic obfuscation, not cryptography)
  String _encodeSession(Map<String, dynamic> data) {
    // In production, use proper encryption library
    return data.toString();
  }

  /// Dispose resources
  void dispose() {
    _expiryTimer?.cancel();
  }
}
