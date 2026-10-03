String tripPlaceLabel(String address) {
  final clean = address.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.isEmpty) return 'Address unavailable';
  // Keep coordinate-only locations intact when no place name was saved.
  if (RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(clean)) {
    return clean;
  }
  final parts = clean
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && part.toLowerCase() != 'sri lanka')
      .toList();
  return parts.take(2).join(', ');
}
