
class MapPlaceUi {
  final String id;
  final String name;
  final String subtitle;
  final String address;
  final String distanceText;
  final String openInfo;
  final String priceInfo;
  final double rating;
  final int reviewCount;
  final int likeCount;
  final List<String> tags;
  final String? imageAsset;

  const MapPlaceUi({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.address,
    required this.distanceText,
    required this.openInfo,
    required this.priceInfo,
    required this.rating,
    required this.reviewCount,
    required this.likeCount,
    required this.tags,
    this.imageAsset,
  });
}
