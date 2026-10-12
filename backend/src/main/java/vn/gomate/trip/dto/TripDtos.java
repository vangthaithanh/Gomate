package vn.gomate.trip.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.*;
import java.util.List;
import java.util.UUID;

public final class TripDtos {
 private TripDtos() {}

 public record CreateTripRequest(
  @NotBlank @Size(max=200) String title,
  @Size(max=2000) String description,
  String tripType,
  List<UUID> selectedMemberIds,
  @NotNull LocalDate startDate,
  @NotNull LocalDate endDate,
  @Size(max=64) String timezone
 ) {}

 public record UpdateTripRequest(
  @Size(max=200) String title,
  @Size(max=2000) String description,
  LocalDate startDate,
  LocalDate endDate,
  @Pattern(regexp="DRAFT|PLANNED|ACTIVE|COMPLETED|CANCELLED") String status,
  @Size(max=64) String timezone
 ) {}

 public record AddStopRequest(
  @NotNull Long placeId,
  @Min(1) Integer dayNo,
  @Min(1) Integer orderNo,
  OffsetDateTime plannedStartAt,
  OffsetDateTime plannedEndAt,
  @Min(1) Integer plannedDurationMin,
  @Size(max=2000) String note,
  @Min(1) Integer checkinRadiusM
 ) {}

 public record UpdateStopRequest(
  Long placeId,
  @Min(1) Integer dayNo,
  @Min(1) Integer orderNo,
  OffsetDateTime plannedStartAt,
  OffsetDateTime plannedEndAt,
  @Min(1) Integer plannedDurationMin,
  Boolean clearTime,
  @Size(max=2000) String note,
  @Min(1) Integer checkinRadiusM
 ) {}

 public record ReorderStopsRequest(@NotEmpty List<@Valid StopOrder> stops) {}

 public record StopOrder(@NotNull UUID stopId,@Min(1) int dayNo,@Min(1) int orderNo) {}

 public record OptimizeStopsRequest(@Min(1) Integer dayNo) {}

 public record AddMembersRequest(@NotEmpty List<UUID> selectedMemberIds) {}

 public record TripSummary(
  UUID id,
  String title,
  String description,
  String tripType,
  String status,
  LocalDate startDate,
  LocalDate endDate,
  String timezone,
  UUID linkedConversationId,
  boolean pinned,
  int memberCount,
  int stopCount,
  LocalDateTime createdAt,
  LocalDateTime updatedAt
 ) {}

 public record TripDetail(
  UUID id,
  UUID ownerId,
  String title,
  String description,
  String tripType,
  String status,
  LocalDate startDate,
  LocalDate endDate,
  String timezone,
  UUID linkedConversationId,
  boolean pinned,
  int memberCount,
  LocalDateTime startedAt,
  LocalDateTime completedAt,
  LocalDateTime createdAt,
  LocalDateTime updatedAt,
  List<Member> members,
  List<Stop> stops,
  List<Reminder> reminders
 ) {}

 public record PinnedTripResponse(TripDetail trip) {}

 public record Member(
  UUID userId,
  String displayName,
  String avatarUrl,
  String role,
  String status,
  LocalDateTime joinedAt,
  Boolean locationSharingEnabled
 ) {}

 public record Stop(
  UUID id,
  Long placeId,
  String name,
  String category,
  String categoryName,
  BigDecimal latitude,
  BigDecimal longitude,
  String thumbnailUrl,
  int dayNo,
  int orderNo,
  LocalDateTime plannedStartAt,
  LocalDateTime plannedEndAt,
  Integer plannedDurationMin,
  boolean hasCompleteInterval,
  String note,
  int checkinRadiusM,
  String status
 ) {}

 public record PublishLocationRequest(
  @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
  @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
  @DecimalMin("0.0") Double accuracyM,
  OffsetDateTime capturedAt
 ) {}

 public record TripLocationItem(
  UUID userId,
  String displayName,
  String avatarUrl,
  double latitude,
  double longitude,
  Double accuracyM,
  Instant capturedAt,
  Instant updatedAt,
  String locationState
 ) {}

 public record Reminder(
  UUID id,
  UUID tripStopId,
  UUID recipientUserId,
  String reminderType,
  LocalDateTime remindAt,
  String status
 ) {}
}
