package vn.gomate.relationship.dto;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public final class SocialRelationshipDtos {
 private SocialRelationshipDtos() {}

 public record RelationshipState(
  UUID userId,
  boolean followingByMe,
  boolean followsMe,
  boolean mutualFriend
 ) {}

 public record UserSummary(
  UUID userId,
  String nickname,
  String fullName,
  String avatarUrl,
  String city,
  String bio,
  boolean followingByMe,
  boolean followsMe,
  boolean mutualFriend,
  LocalDateTime relatedAt
 ) {}

 public record Page<T>(
  List<T> items,
  int page,
  int size,
  long total
 ) {}
}
