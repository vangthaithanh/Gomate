import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum GoMatePlaceCategory { attraction, cafe, food, nature, shopping }

class GoMateMapPlace {
  final String placeId;
  final String name;
  final String categoryLabel;
  final String address;
  final String? province;
  final String? district;
  final String? description;
  final String? thumbnailUrl;
  final List<String> mediaUrls;
  final String? openingHours;
  final int? priceLevel;
  final double rating;
  final int reviewCount;
  final int saveCount;
  final bool isSaved;
  final GoMatePlaceCategory category;
  final Position position;

  const GoMateMapPlace({
    required this.placeId,
    required this.name,
    required this.categoryLabel,
    required this.address,
    this.province,
    this.district,
    this.description,
    this.thumbnailUrl,
    this.mediaUrls = const <String>[],
    this.openingHours,
    this.priceLevel,
    required this.rating,
    required this.reviewCount,
    this.saveCount = 0,
    required this.isSaved,
    required this.category,
    required this.position,
  });

  GoMateMapPlace copyWith({bool? isSaved}) => GoMateMapPlace(
    placeId: placeId,
    name: name,
    categoryLabel: categoryLabel,
    address: address,
    province: province,
    district: district,
    description: description,
    thumbnailUrl: thumbnailUrl,
    mediaUrls: mediaUrls,
    openingHours: openingHours,
    priceLevel: priceLevel,
    rating: rating,
    reviewCount: reviewCount,
    saveCount: saveCount,
    isSaved: isSaved ?? this.isSaved,
    category: category,
    position: position,
  );
}
