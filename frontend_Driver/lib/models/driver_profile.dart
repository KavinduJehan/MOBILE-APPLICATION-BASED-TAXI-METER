import '../utils/json_helpers.dart';

class DriverProfile {
  DriverProfile({
    this.id = '',
    required this.name,
    required this.phone,
    required this.email,
    required this.licenseNumber,
    required this.vehicleNumber,
    this.area = '',
    required this.ratePerKm,
    this.pricingMode = 'ADMIN',
    required this.isVerified,
    required this.qrCode,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String licenseNumber;
  final String vehicleNumber;
  final String area;
  final double ratePerKm;
  final String pricingMode;
  final bool isVerified;
  final String qrCode;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: readString(json, ['id', '_id', 'driverId']),
      name: readString(json, ['name', 'fullName', 'driverName']),
      phone: readString(json, ['phone', 'phoneNumber', 'mobile']),
      email: readString(json, ['email']),
      licenseNumber: readString(json, ['licenseNumber', 'license', 'licenseNo']),
      vehicleNumber: readString(json, ['vehicleNumber', 'vehicleNo', 'vehicle']),
      area: readString(json, ['area', 'serviceArea']),
      ratePerKm: readDouble(json, ['ratePerKm', 'rate', 'perKmRate']),
      pricingMode: readString(json, ['pricingMode'], fallback: 'ADMIN'),
      isVerified: readBool(json, ['isVerified', 'verified']),
      qrCode: readString(json, ['qrCode', 'qr_code', 'qrImage']),
    );
  }

  DriverProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? licenseNumber,
    String? vehicleNumber,
    String? area,
    double? ratePerKm,
    String? pricingMode,
    bool? isVerified,
    String? qrCode,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      area: area ?? this.area,
      ratePerKm: ratePerKm ?? this.ratePerKm,
      pricingMode: pricingMode ?? this.pricingMode,
      isVerified: isVerified ?? this.isVerified,
      qrCode: qrCode ?? this.qrCode,
    );
  }
}
