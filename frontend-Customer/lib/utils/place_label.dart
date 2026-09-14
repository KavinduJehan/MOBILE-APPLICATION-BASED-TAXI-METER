String normalizeSriLankanAddress(String address) {
  var cleanAddress = address.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleanAddress.isEmpty) return cleanAddress;

  cleanAddress = cleanAddress.replaceAll(RegExp(r'\bSri Lanka\b', caseSensitive: false), '').trim();
  cleanAddress = cleanAddress.replaceAll(RegExp(r'\b[A-Z0-9]{4}\+[A-Z0-9]{3,4}\b'), '').trim();
  cleanAddress = cleanAddress.replaceAll(RegExp(r'\b\d{4,6}\b'), '').trim();
  cleanAddress = cleanAddress.replaceAll(RegExp(r',\s*,+'), ', ').trim();
  cleanAddress = cleanAddress.replaceAll(RegExp(r'\s*,\s*$'), '').trim();
  cleanAddress = cleanAddress.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  final segments = cleanAddress
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) return cleanAddress;
  if (segments.length > 1 && segments.first.contains(' - ')) {
    return segments.first;
  }
  if (segments.length > 2) {
    return '${segments[0]}, ${segments[1]}';
  }

  return segments.join(', ');
}

String buildPlaceLabel({
  required String name,
  required String address,
  required String fallback,
}) {
  final cleanName = normalizeSriLankanAddress(name);
  final cleanAddress = normalizeSriLankanAddress(address);
  final cleanFallback = fallback.trim();

  if (cleanName.isEmpty) {
    return cleanAddress.isEmpty ? cleanFallback : cleanAddress;
  }
  if (cleanAddress.isEmpty) return cleanName;

  final normalizedName = cleanName.toLowerCase();
  final normalizedAddress = cleanAddress.toLowerCase();
  if (normalizedAddress.contains(normalizedName)) return cleanAddress;
  if (normalizedName.contains(normalizedAddress)) return cleanName;
  return '$cleanName, $cleanAddress';
}
