import 'package:latlong2/latlong.dart';

List<LatLng> decodeGooglePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  while (index < encoded.length) {
    var result = 0;
    var shift = 0;
    int value;
    do {
      if (index >= encoded.length) throw const FormatException('Invalid route polyline');
      value = encoded.codeUnitAt(index++) - 63;
      result |= (value & 0x1f) << shift;
      shift += 5;
    } while (value >= 0x20);
    latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

    result = 0;
    shift = 0;
    do {
      if (index >= encoded.length) throw const FormatException('Invalid route polyline');
      value = encoded.codeUnitAt(index++) - 63;
      result |= (value & 0x1f) << shift;
      shift += 5;
    } while (value >= 0x20);
    longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }

  return points;
}