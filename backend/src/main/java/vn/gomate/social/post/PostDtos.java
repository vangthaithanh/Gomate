package vn.gomate.social.post;

import java.util.List;
import java.util.UUID;
import java.time.OffsetDateTime;
import jakarta.validation.constraints.*;

public final class PostDtos {
 private PostDtos() {}
 public record Publish(@NotNull UUID clientRequestId, @NotNull String caption,
  @NotNull String audience, @NotNull @Size(min=1,max=12) List<@NotNull UUID> mediaIds,
  @NotNull List<@NotNull String> hashtags, @NotNull List<@NotNull UUID> taggedUserIds, Long placeId) {}
 public record Media(UUID id,String kind,String mimeType,Long bytes,Long durationMs,Integer width,Integer height,
  int sortOrder,String url,String thumbnailUrl) {}
 public record Detail(long id,UUID authorId,String authorName,String caption,String audience,
  List<String> hashtags,List<UUID> taggedUserIds,Long placeId,List<Media> media,OffsetDateTime createdAt,
  boolean pinned,OffsetDateTime pinnedAt,String authorAvatar,String placeName,
  long likeCount,boolean likedByMe,boolean savedByMe,long commentCount) {}
 public record Engagement(long postId,long likeCount,boolean likedByMe,boolean savedByMe,long commentCount) {}
 public record Page(List<Detail> items,String nextCursor) {}
 public record Liker(UUID userId,String displayName,String nickname,String avatarUrl) {}
 public record LikersPage(List<Liker> items,String nextCursor) {}
 public record Audience(@NotNull String audience) {}
 public record Uploaded(UUID mediaId,String kind,Long durationMs,Long bytes) {}
}
