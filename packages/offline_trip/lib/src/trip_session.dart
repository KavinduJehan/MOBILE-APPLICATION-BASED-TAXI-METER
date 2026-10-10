import 'dart:convert';
import 'dart:math';

String newOfflineId() {
  final random = Random.secure();
  return 'offline-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

class TripSession {
  TripSession(this.data);
  final Map<String, dynamic> data;
  String get id => data['localId'] as String;
  String get status => data['status'] as String? ?? 'ongoing';
  bool get completed => status == 'completed';
  double get rate => (data['ratePerKm'] as num).toDouble();
  double get distanceKm => (data['distanceKm'] as num?)?.toDouble() ?? 0;
  double get fare => double.parse((distanceKm * rate).toStringAsFixed(2));
  DateTime get startTime => DateTime.parse(data['startTime'] as String);
  String get receiptNumber => 'REC-${id.toUpperCase()}';
  List<Map<String, dynamic>> get fixes => (data['fixes'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  String qr(String type) => jsonEncode({
    'version': 1,
    'type': type,
    'localId': id,
    'driverId': data['driverId'],
    'driverToken': data['driverToken'],
    'driverName': data['driverName'],
    'vehicleNumber': data['vehicleNumber'],
    'customerName': data['customerName'],
    'customerId': data['customerId'],
    'ratePerKm': rate,
    'startTime': data['startTime'],
    if (data['destination'] != null) 'destination': data['destination'],
    if (data['navigationProfile'] != null)
      'navigationProfile': data['navigationProfile'],
    if (type == 'TRIP_RECEIPT') ...{
      'distanceKm': distanceKm,
      'totalFare': fare,
      'endTime': data['endTime'],
      'receiptNumber': receiptNumber,
    },
  });

  void validateExchange(Map<String, dynamic> qr, String type) {
    if (qr['version'] != 1 ||
        qr['type'] != type ||
        qr['localId'] != id ||
        qr['driverToken'] != data['driverToken'] ||
        (data['driverId'] != null && qr['driverId'] != data['driverId']) ||
        (qr['ratePerKm'] as num?)?.toDouble() != rate) {
      throw const FormatException(
        'This QR does not match your trip and agreed rate.',
      );
    }
    final start = DateTime.tryParse(qr['startTime']?.toString() ?? '');
    if (type == 'TRIP_ACCEPTED' && data['destination'] != null) {
      final expected = data['destination'] as Map;
      final accepted = qr['destination'];
      if (accepted is! Map ||
          accepted['latitude'] != expected['latitude'] ||
          accepted['longitude'] != expected['longitude'] ||
          accepted['name'] != expected['name'] ||
          qr['navigationProfile'] != data['navigationProfile']) {
        throw const FormatException(
          'This confirmation has a different destination or vehicle profile.',
        );
      }
    }
    if (start == null ||
        start.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw const FormatException('Invalid trip start time.');
    }
    if (type == 'TRIP_RECEIPT') {
      final distance = (qr['distanceKm'] as num?)?.toDouble();
      final fare = (qr['totalFare'] as num?)?.toDouble();
      final end = DateTime.tryParse(qr['endTime']?.toString() ?? '');
      if (distance == null ||
          !distance.isFinite ||
          distance < 0 ||
          fare == null ||
          !fare.isFinite ||
          (fare - distance * rate).abs() > 0.011 ||
          end == null ||
          end.isBefore(start) ||
          end.isAfter(DateTime.now().add(const Duration(minutes: 5))) ||
          start != startTime ||
          qr['receiptNumber'] != receiptNumber) {
        throw const FormatException('Invalid receipt distance, fare or time.');
      }
    }
  }
}
