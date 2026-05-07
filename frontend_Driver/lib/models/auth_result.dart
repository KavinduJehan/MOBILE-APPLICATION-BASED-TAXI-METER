import 'driver_profile.dart';

class AuthResult {
  AuthResult({required this.token, this.profile, this.message});

  final String token;
  final DriverProfile? profile;
  final String? message;
}