package vn.gomate.notification.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class NotificationDtos {
 private NotificationDtos() {}

 public record Item(
  UUID id,String type,UUID actorId,String actorName,String avatarUrl,
  String message,boolean isRead,Instant occurredAt,
  UUID invitationId,String invitationStatus,UUID tripId,String tripName,
  UUID reminderId,Integer reminderOffsetMinutes,Instant plannedStartAt,
  Long postId,Long commentId,
  Integer reminderDaysBefore,java.time.LocalDate tripStartDate,java.time.LocalDate reminderDate,String reminderTimezone
 ) {}

 public record PostTarget(long postId,Long commentId,Long rootCommentId,boolean commentAvailable) {}

 public record Page(List<Item> items,int page,int size,long total,long unreadCount) {}
}
