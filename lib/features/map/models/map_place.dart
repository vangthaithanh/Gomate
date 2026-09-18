import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum GoMatePlaceCategory { attraction, cafe, food, nature, shopping }

class GoMateMapPlace {
  final String placeId;
  final String name;
  final String categoryLabel;
  final String address;
  final double rating;
  final int reviewCount;
  final bool isSaved;
  final GoMatePlaceCategory category;
  final Position position;

  const GoMateMapPlace({
    required this.placeId,
    required this.name,
    required this.categoryLabel,
    required this.address,
    required this.rating,
    required this.reviewCount,
    required this.isSaved,
    required this.category,
    required this.position,
  });

  GoMateMapPlace copyWith({bool? isSaved}) => GoMateMapPlace(
        placeId: placeId,
        name: name,
        categoryLabel: categoryLabel,
        address: address,
        rating: rating,
        reviewCount: reviewCount,
        isSaved: isSaved ?? this.isSaved,
        category: category,
        position: position,
      );
}
