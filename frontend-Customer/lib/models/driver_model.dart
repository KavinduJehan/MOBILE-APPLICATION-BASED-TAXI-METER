class DriverModel {
  final String id;
  final String name;
  final String vehicleType;
  final String vehicleNumber;
  final String area;
  final double ratePerKm;
  final double? distanceKm;
  final double rating;
  final bool isAvailable;
  final bool isVerified;

  const DriverModel({
    required this.id,
    required this.name,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.area,
    required this.ratePerKm,
    required this.distanceKm,
    required this.rating,
    required this.isAvailable,
    required this.isVerified,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final updatedAt = _readMap(json['location'])?['updatedAt'];
    final vehicle = _readMap(json['vehicle']);
    final available = json['isAvailable'] as bool? ??
        (updatedAt == null || DateTime.tryParse(updatedAt.toString()) != null);

    return DriverModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown driver').toString(),
      vehicleType: (json['vehicleType'] ?? vehicle?['type'] ?? 'Taxi').toString(),
      vehicleNumber:
          (json['vehicleNumber'] ?? vehicle?['number'] ?? '-').toString(),
      area: (json['area'] ?? '').toString(),
      ratePerKm: _readDouble(json['ratePerKm']),
      distanceKm: _nullableDouble(json['distanceKm'] ?? json['distance']),
      rating: _readDouble(json['rating'], fallback: 4.8),
      isAvailable: available,
      isVerified: json['isVerified'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
        'area': area,
        'ratePerKm': ratePerKm,
        'distanceKm': distanceKm,
        'rating': rating,
        'isAvailable': isAvailable,
        'isVerified': isVerified,
      };

  Map<String, dynamic> toLegacyMap() => {
        '_id': id,
        'name': name,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
        'area': area,
        'ratePerKm': ratePerKm,
        'isVerified': isVerified,
      };

  static Map<String, dynamic>? _readMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static double _readDouble(Object? value, {double fallback = 0}) =>
      _nullableDouble(value) ?? fallback;

  static double? _nullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
