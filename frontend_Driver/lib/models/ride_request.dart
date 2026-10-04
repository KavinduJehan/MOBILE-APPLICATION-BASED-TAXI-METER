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
    this.counterRatePerKm,
    this.negotiationStatus = 'none',
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

  /// This driver's counter-offer to the customer's suggested rate, if sent.
  final double? counterRatePerKm;

  /// none | customer_offered | driver_countered | agreed | declined
  final String negotiationStatus;
  final String status;

  /// The customer asked for a lower rate and is waiting for the driver.
  bool get hasCustomerOffer =>
      suggestedRatePerKm != null && negotiationStatus != 'driver_countered';

  /// The driver sent a counter-offer and is waiting for the customer.
  bool get awaitingCustomer =>
      negotiationStatus == 'driver_countered' && counterRatePerKm != null;
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
      counterRatePerKm: _optionalDouble(json['counterRatePerKm']),
      negotiationStatus: readString(
        json,
        ['negotiationStatus'],
        // Older backends don't send it: a suggested rate still means an offer.
        fallback: _optionalDouble(json['suggestedRatePerKm']) != null
            ? 'customer_offered'
            : 'none',
      ),
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

  RideRequest withCounterOffer(double counterRate) => RideRequest(
    id: id,
    customerId: customerId,
    customerName: customerName,
    pickupAddress: pickupAddress,
    destinationAddress: destinationAddress,
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
    destinationLatitude: destinationLatitude,
    destinationLongitude: destinationLongitude,
    estimatedDistanceKm: estimatedDistanceKm,
    driverRatePerKm: driverRatePerKm,
    suggestedRatePerKm: suggestedRatePerKm,
    counterRatePerKm: counterRate,
    negotiationStatus: 'driver_countered',
    status: status,
    createdAt: createdAt,
  );

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
    if (counterRatePerKm != null) 'counterRatePerKm': counterRatePerKm,
    'negotiationStatus': negotiationStatus,
    'status': status,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
