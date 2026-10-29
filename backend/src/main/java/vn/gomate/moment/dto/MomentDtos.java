package vn.gomate.moment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class MomentDtos {
 private MomentDtos() {}

 public record UploadedMedia(
  String mediaUrl,
  String publicId,
  String mediaType,
  Integer width,
  Integer height,
  Long bytes
 ) {}

 public record CreateMomentRequest(
  @NotBlank String mediaUrl,
  @NotBlank String publicId,
  @Size(max=140) String caption,
  @Size(max=160) String locationText,
  Long placeId,
  Double latitude,
  Double longitude
 ) {}

 public record MomentItem(
  String momentId,
  UUID ownerId,
  String ownerName,
  String ownerNickname,
  String ownerAvatarUrl,
  String mediaUrl,
  String mediaPublicId,
  String mediaType,
  String caption,
  String locationText,
  Long placeId,
  Double latitude,
  Double longitude,
  Instant createdAt,
  Instant expiresAt,
  boolean own,
  boolean viewedByCurrentUser,
  List<ReactionItem> reactions
 ) {}

 public record ReactionItem(
  String reactionId,
  UUID userId,
  String userName,
  String nickname,
  String avatarUrl,
  String type,
  Instant reactedAt
 ) {}

 public record FriendPreview(
  UUID userId,
  String name,
  String nickname,
  String avatarUrl,
  boolean self,
  boolean mutualFriend,
  boolean muted,
  boolean hasAvailableMoment,
  int availableMomentCount,
  Instant latestMomentAt
 ) {}

 public record HomeResponse(
  List<FriendPreview> stripItems,
  List<MomentItem> availableFriendMoments,
  List<MomentItem> myMoments
 ) {}

 public record ReactRequest(@NotBlank String type) {}

 public record SendMomentMessageRequest(@NotBlank @Size(max=4000) String text) {}

 public record BatchDeleteRequest(List<String> momentIds) {}
}
