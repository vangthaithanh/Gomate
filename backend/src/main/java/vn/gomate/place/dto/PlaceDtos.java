package vn.gomate.place.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public final class PlaceDtos {
 private PlaceDtos() {}

 public record Category(Long id,String code,String name) {}

 public record Media(Long id,String mediaType,String url,String caption,Integer sortOrder,LocalDateTime createdAt) {}

 public record Summary(
  Long placeId,
  String name,
  String category,
  String categoryName,
  BigDecimal latitude,
  BigDecimal longitude,
  String province,
  String district,
  String address,
  String thumbnailUrl
 ) {}

 public record Detail(
  Long id,
  String name,
  Category category,
  String description,
  String province,
  String district,
  String address,
  BigDecimal latitude,
  BigDecimal longitude,
  String openingHours,
  Integer priceLevel,
  BigDecimal avgRating,
  Integer reviewCount,
  Integer saveCount,
  String sourceType,
  String status,
  LocalDateTime createdAt,
  LocalDateTime updatedAt,
  List<Media> media
 ) {}
}
