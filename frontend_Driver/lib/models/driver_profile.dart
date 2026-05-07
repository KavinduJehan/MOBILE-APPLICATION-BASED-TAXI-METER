import '../utils/json_helpers.dart';

class DriverProfile {
  DriverProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.licenseNumber,
    required this.vehicleNumber,
    required this.area,
    required this.ratePerKm,
    required this.isVerified,
    required this.qrCode,
  });

  final String name;
  final String phone;
  final String email;
  final String licenseNumber;
  final String vehicleNumber;
  final String area;
  final double ratePerKm;
  final bool isVerified;
  final String qrCode;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      name: readString(json, ['name', 'fullName', 'driverName']),
      phone: readString(json, ['phone', 'phoneNumber', 'mobile']),
      email: readString(json, ['email']),
      licenseNumber: readString(json, ['licenseNumber', 'license', 'licenseNo']),
      vehicleNumber: readString(json, ['vehicleNumber', 'vehicleNo', 'vehicle']),
      area: readString(json, ['area', 'serviceArea']),
      ratePerKm: readDouble(json, ['ratePerKm', 'rate', 'perKmRate']),
      isVerified: readBool(json, ['isVerified', 'verified']),
      qrCode: readString(json, ['qrCode', 'qr_code', 'qrImage']),
    );
  }

  DriverProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? licenseNumber,
    String? vehicleNumber,
    String? area,
    double? ratePerKm,
    bool? isVerified,
    String? qrCode,
  }) {
    return DriverProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      area: area ?? this.area,
      ratePerKm: ratePerKm ?? this.ratePerKm,
      isVerified: isVerified ?? this.isVerified,
      qrCode: qrCode ?? this.qrCode,
    );
  }
}