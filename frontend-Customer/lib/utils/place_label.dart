String buildPlaceLabel({
  required String name,
  required String address,
  required String fallback,
}) {
  final cleanName = name.trim();
  final cleanAddress = address.trim();
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
