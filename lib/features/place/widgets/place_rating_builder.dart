import 'package:flutter/material.dart';
import '../data/place_review_repository.dart';

/// Only rebuilds the rating badge/text, never the Map, images or Post Feed.
class PlaceRatingBuilder extends StatelessWidget {
  const PlaceRatingBuilder({
    super.key,
    required this.placeId,
    required this.average,
    required this.count,
    required this.builder,
  });
  final String placeId;
  final double average;
  final int count;
  final Widget Function(PlaceRating) builder;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlaceRating?>(
    valueListenable: PlaceRatingChanges.forPlace(placeId),
    builder: (_, rating, __) => builder(rating ?? PlaceRating(average, count)),
  );
}
