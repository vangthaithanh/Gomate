package vn.gomate.message.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public final class MessageDtos {
 private MessageDtos() {}

 public record Peer(
  UUID userId,
  String nickname,
  String displayName,
  String avatarUrl,
  String city,
  String bio
 ) {}

 public record ConversationSummary(
  UUID conversationId,
  String type,
  String status,
  UUID linkedTripId,
  String displayName,
  Peer peer,
  List<Member> members,
  Integer memberCount,
  boolean requester,
  boolean recipient,
  boolean muted,
  boolean blockedByMe,
  boolean blockedByPeer,
  long unreadCount,
  MessageItem latestMessage,
  LocalDateTime createdAt,
  LocalDateTime updatedAt
 ) {}

 public record ConversationDetail(
  ConversationSummary conversation,
  List<MessageItem> messages,
  Page page
 ) {}

 public record Member(
  UUID userId,
  String displayName,
  String avatarUrl,
  String role,
  boolean currentUser
 ) {}

 public record MessageItem(
  String messageId,
  UUID conversationId,
  UUID senderUserId,
  String type,
  String text,
  Map<String,Object> context,
  Instant createdAt
 ) {}

 public record DirectOpenRequest(UUID targetUserId) {}

 public record RenameConversationRequest(@NotBlank @Size(max=150) String name) {}

 public record SendTextRequest(
  @NotBlank @Size(max=4000) String text,
  Map<String,Object> context
 ) {}

 public record Page(Integer limit,String before,boolean hasMore) {}
}
