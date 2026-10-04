package vn.gomate.semantic.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public final class SemanticDtos {
 private SemanticDtos() {}

 public record InterestOption(
  Long id,
  String code,
  String label,
  String groupCode,
  String groupName,
  String interestType,
  String description,
  Boolean active
 ) {}

 public record PlaceTag(
  Long id,
  String code,
  String label,
  Boolean active
 ) {}

 public record InterestTagMapping(
  String interestCode,
  String tagCode,
  BigDecimal weight
 ) {}

 public record PlaceTagLink(
  Long placeId,
  String externalId,
  String placeName,
  String tagCode,
  String tagLabel,
  BigDecimal weight
 ) {}

 public record UserInterest(
  String interestCode,
  String interestLabel,
  String groupCode,
  BigDecimal preferenceWeight,
  LocalDateTime selectedAt
 ) {}
}
