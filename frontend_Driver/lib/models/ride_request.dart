import '../utils/json_helpers.dart';

class RideRequest {
  RideRequest({
    required this.id,
    this.customerId,
    required this.customerName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.estimatedDistanceKm,
    required this.driverRatePerKm,
    required this.suggestedRatePerKm,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String? customerId;
  final String customerName;
  final String pickupAddress;
  final String destinationAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final double estimatedDistanceKm;
  final double driverRatePerKm;
  final double? suggestedRatePerKm;
  final String status;
  final DateTime? createdAt;

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    final customer = readMap(json, ['customer', 'customerDetails']) ?? const <String, dynamic>{};
    final rawCustomer = json['customer'];
    final customerId = rawCustomer is String
        ? rawCustomer
        : (readString(customer, ['id', '_id']).isEmpty ? null : readString(customer, ['id', '_id']));
    return RideRequest(
      id: readString(json, ['id', '_id', 'requestId']),
      customerId: customerId,
      customerName: readString(json, ['customerName', 'passengerName'], fallback: readString(customer, ['name', 'fullName'], fallback: 'Customer')),
      pickupAddress: readString(json, ['pickupAddress', 'pickup', 'from']),
      destinationAddress: readString(json, [
        'destinationAddress',
        'destAddress',
        'destination',
        'to',
      ]),
      pickupLatitude: readDouble(json, ['pickupLat', 'pickupLatitude']),
      pickupLongitude: readDouble(json, ['pickupLng', 'pickupLongitude']),
      destinationLatitude: readDouble(json, [
        'destLat',
        'destinationLat',
        'destinationLatitude',
      ]),
      destinationLongitude: readDouble(json, [
        'destLng',
        'destinationLng',
        'destinationLongitude',
      ]),
      estimatedDistanceKm: readDouble(json, [
        'estimatedDistanceKm',
        'distanceKm',
        'distance',
      ]),
      driverRatePerKm: readDouble(json, [
        'driverRatePerKm',
        'ratePerKm',
        'driverRate',
      ]),
      // Push payloads carry every value as a string ('' when absent).
      suggestedRatePerKm: _optionalDouble(json['suggestedRatePerKm']) ??
          _optionalDouble(json['suggestedRate']),
      status: readString(json, ['status'], fallback: 'pending'),
      createdAt: readDateTime(json, ['createdAt', 'requestedAt']),
    );
  }

  static double? _optionalDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double fareAt(double ratePerKm) => ratePerKm * estimatedDistanceKm;

  /// Round-trips through [RideRequest.fromJson]; used as notification payload.
  Map<String, dynamic> toJson() => {
    '_id': id,
    if (customerId != null) 'customer': customerId,
    'customerName': customerName,
    'pickupAddress': pickupAddress,
    'destinationAddress': destinationAddress,
    'pickupLat': pickupLatitude,
    'pickupLng': pickupLongitude,
    'destLat': destinationLatitude,
    'destLng': destinationLongitude,
    'estimatedDistanceKm': estimatedDistanceKm,
    'driverRatePerKm': driverRatePerKm,
    if (suggestedRatePerKm != null) 'suggestedRatePerKm': suggestedRatePerKm,
    'status': status,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
