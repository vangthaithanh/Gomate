import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../place/data/place_repository.dart';
import '../../place/models/place_models.dart';
import '../models/map_place.dart';
import 'place_data_source.dart';

/// KHUNG PRODUCTION ĐÚNG ROADMAP.
///
/// Flutter KHÔNG kết nối PostgreSQL trực tiếp.
///
/// Luồng:
/// Flutter
///   -> GET /api/v1/places
///   -> Spring Boot
///   -> PostgreSQL tables places / categories / ...
///   -> Place DTO
///   -> GoMateMapPlace
class SpringPostgresPlaceDataSource implements PlaceDataSource {
  final PlaceRepository _repository;

  SpringPostgresPlaceDataSource({PlaceRepository? repository})
    : _repository = repository ?? PlaceRepository.production();

  @override
  Future<List<GoMateMapPlace>> getPlaces({
    String? query,
    GoMatePlaceCategory? category,
  }) async {
    final q = query?.trim() ?? '';
    final places = q.isEmpty
        ? await _repository.listPlaces()
        : await _repository.searchPlaces(q);

    final mapped = places.map(_fromSummary).toList(growable: false);
    if (category == null) return mapped;

    return mapped
        .where((place) => place.category == category)
        .toList(growable: false);
  }

  @override
  Future<GoMateMapPlace> getPlaceById(String placeId) async {
    final id = int.tryParse(placeId);
    if (id == null) {
      throw ArgumentError('Place API id phải là số: $placeId');
    }

    final detail = await _repository.getPlace(id);
    return _fromDetail(detail);
  }

  GoMateMapPlace _fromSummary(PlaceSummary place) {
    return GoMateMapPlace(
      placeId: place.placeId.toString(),
      name: place.name,
      categoryLabel: place.categoryName,
      address: _address(place.address, place.district, place.province),
      province: place.province,
      district: place.district,
      thumbnailUrl: place.thumbnailUrl,
      mediaUrls: [if (place.thumbnailUrl != null) place.thumbnailUrl!],
      rating: 0,
      reviewCount: 0,
      isSaved: false,
      category: _category(place.category, place.categoryName),
      position: Position(place.longitude, place.latitude),
    );
  }

  GoMateMapPlace _fromDetail(PlaceDetail place) {
    final imageUrls = place.media
        .where((media) => media.mediaType.toUpperCase() == 'IMAGE')
        .map((media) => media.url)
        .toList(growable: false);

    return GoMateMapPlace(
      placeId: place.id.toString(),
      name: place.name,
      categoryLabel: place.category.name,
      address: _address(place.address, place.district, place.province),
      province: place.province,
      district: place.district,
      description: place.description,
      thumbnailUrl: imageUrls.isEmpty ? null : imageUrls.first,
      mediaUrls: imageUrls,
      openingHours: place.openingHours,
      priceLevel: place.priceLevel,
      rating: place.rating,
      reviewCount: place.reviewCount,
      saveCount: place.saveCount,
      isSaved: false,
      category: _category(place.category.code, place.category.name),
      position: Position(place.longitude, place.latitude),
    );
  }

  String _address(String? address, String? district, String province) {
    final parts = [
      if (address != null && address.trim().isNotEmpty) address.trim(),
      if (district != null && district.trim().isNotEmpty) district.trim(),
      province.trim(),
    ];
    return parts.join(', ');
  }

  GoMatePlaceCategory _category(String code, String label) {
    final source = '$code $label'.toLowerCase();

    if (source.contains('lake') ||
        source.contains('nature') ||
        source.contains('hồ') ||
        source.contains('thiên nhiên')) {
      return GoMatePlaceCategory.nature;
    }
    if (source.contains('food') || source.contains('ẩm thực')) {
      return GoMatePlaceCategory.food;
    }
    if (source.contains('cafe') || source.contains('cà phê')) {
      return GoMatePlaceCategory.cafe;
    }
    if (source.contains('shopping') || source.contains('mua sắm')) {
      return GoMatePlaceCategory.shopping;
    }
    return GoMatePlaceCategory.attraction;
  }
}
