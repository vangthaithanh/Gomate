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
  boolean mutualFriend,
  boolean isPrivate,
  boolean followRequestPending
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
  boolean isPrivate,
  boolean followRequestPending,
  LocalDateTime relatedAt
 ) {}

 public record FollowRequest(
  UUID id, UUID requesterId, String nickname, String fullName, String avatarUrl,
  String status, java.time.OffsetDateTime createdAt
 ) {}

 public record Page<T>(
  List<T> items,
  int page,
  int size,
  long total
 ) {}
}
