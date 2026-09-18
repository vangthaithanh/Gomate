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
  final String apiBaseUrl;

  const SpringPostgresPlaceDataSource({
    required this.apiBaseUrl,
  });

  @override
  Future<List<GoMateMapPlace>> getPlaces({
    String? query,
    GoMatePlaceCategory? category,
  }) {
    throw UnimplementedError(
      'Implement khi Place API + PostgreSQL schema hoàn tất.',
    );
  }

  @override
  Future<GoMateMapPlace> getPlaceById(String placeId) {
    throw UnimplementedError(
      'Implement GET /api/v1/places/$placeId khi Place API hoàn tất.',
    );
  }
}
