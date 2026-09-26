import '../utils/json_helpers.dart';

class RideRequest {
  RideRequest({
    required this.id,
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
    final customer =
        readMap(json, ['customer', 'customerDetails']) ??
        const <String, dynamic>{};
    return RideRequest(
      id: readString(json, ['id', '_id', 'requestId']),
      customerName: readString(
        json,
        ['customerName', 'passengerName'],
        fallback: readString(customer, [
          'name',
          'fullName',
        ], fallback: 'Customer'),
      ),
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
      suggestedRatePerKm: json['suggestedRatePerKm'] is num
          ? (json['suggestedRatePerKm'] as num).toDouble()
          : (json['suggestedRate'] is num
                ? (json['suggestedRate'] as num).toDouble()
                : null),
      status: readString(json, ['status'], fallback: 'pending'),
      createdAt: readDateTime(json, ['createdAt', 'requestedAt']),
    );
  }

  double fareAt(double ratePerKm) => ratePerKm * estimatedDistanceKm;
}
