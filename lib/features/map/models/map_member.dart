import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class GoMateMapMember {
  final String userId;
  final String displayName;
  final String assetIcon;
  final Position position;
  final DateTime updatedAt;
  final bool isStale;

  const GoMateMapMember({
    required this.userId,
    required this.displayName,
    required this.assetIcon,
    required this.position,
    required this.updatedAt,
    this.isStale = false,
  });
}
