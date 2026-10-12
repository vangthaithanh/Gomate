package vn.gomate.user.dto;

import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public final class UserDtos {
 private UserDtos() {}

 public record RelationshipStats(long followingCount,long followersCount,long mutualFriendCount) {}

 public record UserProfile(
  UUID id,
  UUID userId,
  String email,
  String role,
  String status,
  String nickname,
  String displayName,
  String fullName,
  String avatarUrl,
  String city,
  String bio,
  String interestCodes,
  boolean googleLinked,
  boolean onboardingCompleted,
  RelationshipStats relationshipStats,
  Boolean followingByMe,
  Boolean followsMe,
  Boolean mutualFriend,
  LocalDateTime createdAt,
  LocalDateTime lastLoginAt
 ) {}

 public record ProfileUpdate(
  @Size(min=3,max=40) String nickname,
  @Size(max=120) String fullName,
  @Size(max=120) String city,
  @Size(max=1000) String bio,
  @Size(max=1000) String avatarUrl
 ) {}

 public record UserSearchItem(
  UUID userId,
  String nickname,
  String displayName,
  String avatarUrl,
  String city,
  String bio,
  boolean followingByMe,
  boolean followsMe,
  boolean mutualFriend
 ) {}

 public record Page<T>(List<T> items,int page,int size,long total) {}
}
