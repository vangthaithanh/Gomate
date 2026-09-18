import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/map_place.dart';

/// DATA CỨNG CHỈ DÙNG CHO GIAI ĐOẠN TEST MAP FOUNDATION.
///
/// Production theo GOMATE_MAP_ARCHITECTURE_ROADMAP.md:
/// Flutter -> Spring Boot -> PostgreSQL places -> Place DTO -> marker.
///
/// Mapbox Position dùng thứ tự:
/// Position(longitude, latitude)
final List<GoMateMapPlace> demoPlaces = [
  GoMateMapPlace(
    placeId: 'place-101',
    name: 'Hồ Xuân Hương',
    categoryLabel: 'Thiên nhiên',
    address: 'Phường 1, Đà Lạt, Lâm Đồng',
    rating: 4.7,
    reviewCount: 1248,
    isSaved: true,
    category: GoMatePlaceCategory.nature,
    position: Position(108.4488, 11.9416),
  ),
  GoMateMapPlace(
    placeId: 'place-102',
    name: 'Quảng trường Lâm Viên',
    categoryLabel: 'Điểm check-in',
    address: 'Trần Quốc Toản, Đà Lạt',
    rating: 4.6,
    reviewCount: 2035,
    isSaved: false,
    category: GoMatePlaceCategory.attraction,
    position: Position(108.4453, 11.9367),
  ),
  GoMateMapPlace(
    placeId: 'place-103',
    name: 'Chợ Đà Lạt',
    categoryLabel: 'Mua sắm',
    address: 'Nguyễn Thị Minh Khai, Đà Lạt',
    rating: 4.4,
    reviewCount: 3114,
    isSaved: false,
    category: GoMatePlaceCategory.shopping,
    position: Position(108.4376, 11.9439),
  ),
  GoMateMapPlace(
    placeId: 'place-104',
    name: 'Vườn hoa Thành phố',
    categoryLabel: 'Thiên nhiên',
    address: 'Trần Quốc Toản, Đà Lạt',
    rating: 4.5,
    reviewCount: 986,
    isSaved: true,
    category: GoMatePlaceCategory.nature,
    position: Position(108.4499, 11.9514),
  ),
  GoMateMapPlace(
    placeId: 'place-105',
    name: 'Cafe Tùng',
    categoryLabel: 'Cafe',
    address: 'Khu Hòa Bình, Đà Lạt',
    rating: 4.5,
    reviewCount: 724,
    isSaved: false,
    category: GoMatePlaceCategory.cafe,
    position: Position(108.4387, 11.9445),
  ),
  GoMateMapPlace(
    placeId: 'place-106',
    name: 'Bếp 1985',
    categoryLabel: 'Ăn uống',
    address: 'Trung tâm Đà Lạt',
    rating: 4.6,
    reviewCount: 513,
    isSaved: false,
    category: GoMatePlaceCategory.food,
    position: Position(108.4432, 11.9389),
  ),
  GoMateMapPlace(
    placeId: 'place-107',
    name: 'Ga Đà Lạt',
    categoryLabel: 'Điểm check-in',
    address: 'Quang Trung, Đà Lạt',
    rating: 4.5,
    reviewCount: 1542,
    isSaved: false,
    category: GoMatePlaceCategory.attraction,
    position: Position(108.4548, 11.9419),
  ),
  GoMateMapPlace(
    placeId: 'place-108',
    name: 'Dinh Bảo Đại',
    categoryLabel: 'Điểm check-in',
    address: 'Triệu Việt Vương, Đà Lạt',
    rating: 4.5,
    reviewCount: 850,
    isSaved: false,
    category: GoMatePlaceCategory.attraction,
    position: Position(108.4298, 11.9302),
  ),
];

/// Thứ tự Trip test.
/// Route request gửi placeId, KHÔNG gửi Mapbox feature id.
const List<String> demoTripStopIds = [
  'place-103',
  'place-105',
  'place-101',
  'place-102',
  'place-107',
];
