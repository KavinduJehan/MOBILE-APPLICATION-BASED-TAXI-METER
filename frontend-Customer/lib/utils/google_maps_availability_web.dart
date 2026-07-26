import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('globalThis')
external JSObject get _globalThis;

bool get isGoogleMapsAvailable {
  if (!_globalThis.has('google')) return false;
  final google = _globalThis['google'];
  return google != null &&
      google.isA<JSObject>() &&
      (google as JSObject).has('maps');
}
