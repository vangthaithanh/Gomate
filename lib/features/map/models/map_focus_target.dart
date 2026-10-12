class MapFocusTarget {
  final String label;
  final String? placeId;
  final double? latitude;
  final double? longitude;

  const MapFocusTarget({
    required this.label,
    this.placeId,
    this.latitude,
    this.longitude,
  });

  bool get hasPlace => placeId != null && placeId!.trim().isNotEmpty;

  bool get hasCoordinate => latitude != null && longitude != null;
}
