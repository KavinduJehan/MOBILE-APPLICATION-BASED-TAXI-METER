import 'package:google_maps_flutter/google_maps_flutter.dart';

List<LatLng> decodeGooglePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  int decodeValue() {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      if (index >= encoded.length) {
        throw const FormatException('Invalid encoded route polyline');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) == 1 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    latitude += decodeValue();
    longitude += decodeValue();
    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }
  return points;
}
