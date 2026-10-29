package vn.gomate.trip.service;

import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import vn.gomate.common.ApiException;
import vn.gomate.location.repository.TripLocationMongoRepository;
import vn.gomate.location.service.TripLocationService;
import vn.gomate.location.realtime.TripLocationStreamHub;
import vn.gomate.message.repository.ConversationRepository;
import vn.gomate.notification.service.NotificationService;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.model.TripStopSequenceItem;
import vn.gomate.trip.repository.TripInvitationRepository;
import vn.gomate.trip.repository.TripRepository;

@Service
public class TripService {
 private static final Logger log=LoggerFactory.getLogger(TripService.class);
 private static final String DEFAULT_TIMEZONE="Asia/Ho_Chi_Minh";
 private static final String DEFAULT_TITLE="Lịch trình";
 private static final Set<String> INVITATION_STATUSES=Set.of("PENDING","ACCEPTED","DECLINED","CANCELLED");
 private final TripRepository repo;
 private final TripPlanningTime planningTime;
 private final TripStartReminderService reminders;
 private final TripInvitationRepository invitations;
 private final NotificationService notifications;
 private final ConversationRepository conversations;
 private final TripStopSequenceValidator stopSequenceValidator;
 private final TripLocationMongoRepository locations;
 private final TripLocationStreamHub locationStreams;
 private final TripLocationService locationService;
 public TripService(TripRepository repo,TripInvitationRepository invitations,NotificationService notifications,ConversationRepository conversations,TripStopSequenceValidator stopSequenceValidator,TripLocationMongoRepository locations,TripLocationStreamHub locationStreams,TripLocationService locationService,TripPlanningTime planningTime,TripStartReminderService reminders) {
  this.repo=repo;
  this.planningTime=planningTime;
  this.reminders=reminders;
  this.invitations=invitations;
  this.notifications=notifications;
  this.conversations=conversations;
  this.stopSequenceValidator=stopSequenceValidator;
  this.locations=locations;
  this.locationStreams=locationStreams;
  this.locationService=locationService;
 }

 private record StopCandidate(
  UUID id,
  long placeId,
  int dayNo,
  int orderNo,
  OffsetDateTime plannedStartAt,
  Integer plannedDurationMin,
  String note,
  int checkinRadiusM,
  String status,
  BigDecimal latitude,
  BigDecimal longitude
 ) implements TripStopSequenceItem {}


 @Transactional
 public TripDtos.TripDetail create(UUID userId,TripDtos.CreateTripRequest req) {
  validateDates(req.startDate(),req.endDate());
  planningTime.validate(req.startDate(),req.endDate(),timezone(req.timezone()),true,true);
  UUID tripId=UUID.randomUUID();
  String title=cleanTitle(req.title());
  List<UUID> selectedMemberIds=validatedSelectedMemberIds(userId,req.selectedMemberIds());
  repo.insertTrip(tripId,userId,title,blankToNull(req.description()),"PERSONAL",req.startDate(),req.endDate(),timezone(req.timezone()));
  repo.insertLeader(tripId,userId);
  reminders.sync(tripId);
  for(UUID memberId:selectedMemberIds) {
   createInvitationLocked(userId,tripId,memberId);
  }
  return detail(userId,tripId);
 }

 public List<TripDtos.TripSummary> list(UUID userId) {
  return repo.listForUser(userId).stream().map(this::summary).toList();
 }

 public TripDtos.TripDetail detail(UUID userId,UUID tripId) {
  var trip=repo.detailForUser(tripId,userId).orElseThrow(ApiException::notFound);
  return detailFromRow(trip);
 }

 public Optional<TripDtos.TripDetail> pinned(UUID userId) {
  return repo.pinnedTripId(userId).map(tripId -> detail(userId,tripId));
 }

 @Transactional
 public void leave(UUID userId,UUID tripId) {
  var trip=repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  if(!repo.isActiveMember(tripId,userId)) throw ApiException.notFound();
  if(repo.isActiveLeader(tripId,userId)) {
   throw new ApiException(422,"TRIP_LEADER_CANNOT_LEAVE","Nhóm trưởng không thể rời lịch trình bằng thao tác này.");
  }
  removeMemberLocked(tripId,userId);
 }

 @Transactional
 public TripDtos.TripDetail removeMember(UUID actorId,UUID tripId,UUID memberId) {
  repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  requireLeader(tripId,actorId);
  if(repo.isActiveLeader(tripId,memberId)) {
   throw new ApiException(422,"TRIP_LEADER_CANNOT_BE_REMOVED","Không thể xóa nhóm trưởng khỏi lịch trình.");
  }
  if(!repo.isActiveMember(tripId,memberId)) throw ApiException.notFound();
  removeMemberLocked(tripId,memberId);
  return detail(actorId,tripId);
 }

 private void removeMemberLocked(UUID tripId,UUID memberId) {
  UUID chatId=repo.groupConversationId(tripId).orElseThrow(() ->
   new ApiException(409,"TRIP_CHAT_INCONSISTENT","Lịch trình nhóm chưa có đoạn chat hoạt động."));
  repo.removeMember(tripId,memberId);
  reminders.cancel(tripId,memberId);
  conversations.removeMember(chatId,memberId);
  repo.unpinTrip(memberId,tripId);
  if(repo.activeTripMembers(tripId).size()==1) {
   conversations.archiveGroup(chatId);
   repo.updateTripType(tripId,"PERSONAL");
  }
  afterCommit(() -> locationService.removeDepartedMemberSnapshot(tripId,memberId));
 }

 @Transactional
 public TripDtos.TripDetail pin(UUID userId,UUID tripId) {
  var trip=repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  if(!repo.isActiveMember(tripId,userId)) throw ApiException.notFound();
  repo.lockLocationActor(userId);
  if(!repo.isPinned(tripId,userId)) repo.pinTrip(userId,tripId);
  return detail(userId,tripId);
 }

 @Transactional
 public void unpin(UUID userId,UUID tripId) {
  repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  if(!repo.isActiveMember(tripId,userId)) throw ApiException.notFound();
  repo.lockLocationActor(userId);
  repo.unpinTrip(userId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail update(UUID userId,UUID tripId,TripDtos.UpdateTripRequest req) {
  var current=lockAsLeader(tripId,userId);
  String title=req.title()==null?(String)current.get("title"):cleanTitle(req.title());
  String description=req.description()==null?(String)current.get("description"):blankToNull(req.description());
  LocalDate startDate=req.startDate()==null?(LocalDate)current.get("startDate"):req.startDate();
  LocalDate endDate=req.endDate()==null?(LocalDate)current.get("endDate"):req.endDate();
  String timezone=req.timezone()==null?(String)current.get("timezone"):timezone(req.timezone());
  validateDates(startDate,endDate);
  boolean startChanged=!startDate.equals(current.get("startDate"));
  boolean zoneChanged=!timezone.equals(current.get("timezone"));
  planningTime.validate(startDate,endDate,timezone,startChanged || zoneChanged,!endDate.equals(current.get("endDate")));
  repo.updateTrip(tripId,title,description,startDate,endDate,timezone);
  if(startChanged || zoneChanged) reminders.sync(tripId);
  return detail(userId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail addMembers(UUID userId,UUID tripId,TripDtos.AddMembersRequest req) {
  requireLeader(tripId,userId);
  repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  List<UUID> selectedMemberIds=validatedInvitationMemberIds(userId,req.selectedMemberIds());
  if(selectedMemberIds.isEmpty()) return detail(userId,tripId);
  for(UUID memberId:selectedMemberIds) createInvitationLocked(userId,tripId,memberId);
  afterCommit(() -> notifyInvitationsReady(tripId,userId,selectedMemberIds));
  return detail(userId,tripId);
 }

 @Transactional
 public TripDtos.TripInvitationItem createInvitation(UUID userId,UUID tripId,TripDtos.CreateInvitationRequest req) {
  requireLeader(tripId,userId);
  repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  return createInvitationLocked(userId,tripId,req.inviteeUserId());
 }

 public List<TripDtos.TripInvitationItem> incomingInvitations(UUID userId,String status) {
  return invitations.incoming(userId,invitationStatus(status)).stream().map(this::invitation).toList();
 }

 @Transactional
 public TripDtos.TripDetail acceptInvitation(UUID userId,UUID invitationId) {
  var row=lockInvitation(invitationId);
  if(!userId.equals((UUID)row.get("inviteeUserId"))) throw ApiException.denied();
  UUID tripId=(UUID)row.get("tripId");
  String status=(String)row.get("status");
  if("ACCEPTED".equals(status)) return detail(userId,tripId);
  if("DECLINED".equals(status)) throw invitationClosed();
  if(!"PENDING".equals(status)) throw invitationClosed();
  repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  if(repo.isActiveMember(tripId,userId)) {
   throw new ApiException(409,"TRIP_MEMBER_EXISTS","Bạn đã là thành viên lịch trình này.");
  }
  UUID inviterId=(UUID)row.get("inviterUserId");
  repo.insertMember(tripId,userId,"MEMBER",inviterId);
  reminders.syncMember(tripId,userId);
  repo.updateTripType(tripId,"GROUP");
  ensureGroupConversationSynced(tripId,inviterId);
  invitations.markResponded(invitationId,"ACCEPTED");
  notifications.invitationStateChanged(invitationId);
  notifications.recordTripInvitation(inviterId,userId,invitationId,true);
  afterCommit(() -> notifyInvitationAccepted(tripId,invitationId,userId));
  return detail(userId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail cancelInvitation(UUID userId,UUID tripId,UUID invitationId) {
  requireLeader(tripId,userId);
  var row=invitations.forUpdate(invitationId).orElseThrow(ApiException::notFound);
  if(!tripId.equals((UUID)row.get("tripId"))) throw ApiException.notFound();
  repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  requireLeader(tripId,userId);
  String status=(String)row.get("status");
  if("CANCELLED".equals(status)) return detail(userId,tripId);
  if(!"PENDING".equals(status)) throw invitationClosed();
  invitations.markCancelled(invitationId);
  notifications.invitationStateChanged(invitationId);
  return detail(userId,tripId);
 }

 @Transactional
 public TripDtos.TripInvitationItem declineInvitation(UUID userId,UUID invitationId) {
  var row=lockInvitation(invitationId);
  if(!userId.equals((UUID)row.get("inviteeUserId"))) throw ApiException.denied();
  String status=(String)row.get("status");
  if(!"PENDING".equals(status) && !"DECLINED".equals(status)) throw invitationClosed();
  if("PENDING".equals(status)) {
   invitations.markResponded(invitationId,"DECLINED");
   notifications.invitationStateChanged(invitationId);
  }
  return invitations.byId(invitationId).map(this::invitation).orElseThrow(ApiException::notFound);
 }

 @Transactional
 public void delete(UUID userId,UUID tripId) {
  var trip=repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  // Retained leadership authorizes an idempotent retry, never active permissions.
  var members=repo.activeTripMembers(tripId);
  if(members.stream().noneMatch(m -> userId.equals(m.get("userId")))) throw ApiException.notFound();
  if(members.stream().noneMatch(m -> userId.equals(m.get("userId")) && "LEADER".equals(m.get("role")))) throw ApiException.denied();
  if(trip.get("archivedAt")==null) {
   var pending=invitations.pendingForTrip(tripId);
   for(var row:pending) invitations.markCancelled((UUID)row.get("invitationId"));
   repo.groupConversationId(tripId).ifPresent(conversations::archiveGroup);
   repo.archiveTrip(tripId);
   reminders.cancel(tripId,null);
   // Refresh existing inbox records; no new notification type or push is created.
   for(var row:invitations.allForTrip(tripId)) notifications.invitationStateChanged((UUID)row.get("invitationId"));
  }
  afterCommit(() -> {
   try { locationStreams.invalidate(tripId); }
   catch(RuntimeException e) { log.warn("Trip location invalidation unavailable after archive: tripId={}",tripId); }
   try { locations.deleteByTrip(tripId); }
   catch(RuntimeException e) { log.warn("Trip snapshot cleanup failed after archive commit: tripId={} errorType={}",tripId,e.getClass().getSimpleName()); }
  });
 }

 @Transactional
 public TripDtos.TripDetail transferLeader(UUID actorId,UUID tripId,UUID targetId) {
  requireLeader(tripId,actorId);
  if(targetId==null || actorId.equals(targetId)
   || !repo.isActiveMember(tripId,targetId) || repo.isActiveLeader(tripId,targetId)
   || !repo.activeUserIds(List.of(targetId)).contains(targetId)) {
   throw new ApiException(422,"TRIP_LEADER_TARGET_INVALID","Chỉ có thể chuyển trưởng nhóm cho thành viên đang hoạt động trong lịch trình.");
  }
  UUID chatId=repo.groupConversationId(tripId).orElseThrow(() ->
   new ApiException(409,"TRIP_CHAT_INCONSISTENT","Lịch trình nhóm chưa có đoạn chat hoạt động."));
  repo.updateMemberRole(tripId,actorId,"MEMBER");
  repo.updateMemberRole(tripId,targetId,"LEADER");
  conversations.updateMemberRole(chatId,actorId,"MEMBER");
  conversations.updateMemberRole(chatId,targetId,"LEADER");
  conversations.touch(chatId);
  return detail(actorId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail addStop(UUID userId,UUID tripId,TripDtos.AddStopRequest req) {
  var trip=lockAsLeader(tripId,userId);
  if(!repo.activePlaceExists(req.placeId())) throw placeNotFound();
  int dayNo=req.dayNo()==null?1:req.dayNo();
  TripStopTime.validateDay((LocalDate)trip.get("startDate"),(LocalDate)trip.get("endDate"),dayNo);
  List<StopCandidate> current=toCandidates(repo.stopRows(tripId));
  int dayCount=(int)current.stream().filter(stop -> stop.dayNo()==dayNo).count();
  int orderNo=req.orderNo()==null?dayCount+1:Math.max(1,Math.min(req.orderNo(),dayCount+1));
  UUID stopId=UUID.randomUUID();
  int radius=req.checkinRadiusM()==null?150:req.checkinRadiusM();
  var zone=planningTime.zone((String)trip.get("timezone"));
  var time=TripStopTime.normalize(req.plannedStartAt(),req.plannedEndAt(),req.plannedDurationMin(),zone);
  TripStopTime.validate(time,(LocalDate)trip.get("startDate"),(LocalDate)trip.get("endDate"),dayNo,zone,planningTime.now());
  List<StopCandidate> candidate=new ArrayList<>();
  for(StopCandidate stop:current) {
   int shifted=stop.dayNo()==dayNo && stop.orderNo()>=orderNo?stop.orderNo()+1:stop.orderNo();
   candidate.add(withOrder(stop,stop.dayNo(),shifted));
  }
  candidate.add(new StopCandidate(
   stopId,
   req.placeId(),
   dayNo,
   orderNo,
   time.start(),
   time.duration(),
   blankToNull(req.note()),
   radius,
   "PLANNED",
   null,
   null
  ));
  candidate=normalizeOrders(candidate);
  stopSequenceValidator.validateNoAdjacentDuplicate(candidate);
  repo.moveStopsToTemporaryOrders(tripId);
  StopCandidate inserted=candidate.stream().filter(stop -> stop.id().equals(stopId)).findFirst().orElseThrow();
  repo.insertStop(
   inserted.id(),
   tripId,
   inserted.placeId(),
   inserted.dayNo(),
   inserted.orderNo(),
   inserted.plannedStartAt(),
   inserted.plannedDurationMin(),
   inserted.note(),
   inserted.checkinRadiusM()
  );
  persistOrders(candidate);
  return detail(userId,tripId);
 }

 @Transactional
 public void deleteStop(UUID userId,UUID tripId,UUID stopId) {
  requireLeader(tripId,userId);
  var actualTripId=repo.stopTripId(stopId).orElseThrow(ApiException::notFound);
  if(!tripId.equals(actualTripId)) throw ApiException.notFound();
  List<StopCandidate> candidate=normalizeOrders(
   toCandidates(repo.stopRows(tripId)).stream()
    .filter(stop -> !stop.id().equals(stopId))
    .toList()
  );
  stopSequenceValidator.validateNoAdjacentDuplicate(candidate);
  repo.deleteStop(stopId);
  repo.moveStopsToTemporaryOrders(tripId);
  persistOrders(candidate);
 }

 @Transactional
 public TripDtos.TripDetail updateStop(UUID userId,UUID tripId,UUID stopId,TripDtos.UpdateStopRequest req) {
  var trip=lockAsLeader(tripId,userId);
  var actualTripId=repo.stopTripId(stopId).orElseThrow(ApiException::notFound);
  if(!tripId.equals(actualTripId)) throw ApiException.notFound();
  List<StopCandidate> current=toCandidates(repo.stopRows(tripId));
  StopCandidate existing=current.stream().filter(stop -> stop.id().equals(stopId)).findFirst().orElseThrow(ApiException::notFound);
  long placeId=req.placeId()==null?existing.placeId():req.placeId();
  if(placeId!=existing.placeId() && !repo.activePlaceExists(placeId)) throw placeNotFound();
  int dayNo=req.dayNo()==null?existing.dayNo():req.dayNo();
  if(dayNo!=existing.dayNo()) TripStopTime.validateDay((LocalDate)trip.get("startDate"),(LocalDate)trip.get("endDate"),dayNo);
  int orderNo=req.orderNo()==null?existing.orderNo():req.orderNo();
  boolean touchesTime=Boolean.TRUE.equals(req.clearTime())
   || req.plannedStartAt()!=null
   || req.plannedEndAt()!=null
   || req.plannedDurationMin()!=null;
  var zone=planningTime.zone((String)trip.get("timezone"));
  var time=Boolean.TRUE.equals(req.clearTime())?new TripStopTime.Value(null,null):touchesTime
   ? TripStopTime.normalize(req.plannedStartAt(),req.plannedEndAt(),req.plannedDurationMin(),zone)
   : new TripStopTime.Value(existing.plannedStartAt(),existing.plannedDurationMin());
  // Metadata edits and identical legacy intervals must not rebase old dates.
  if(touchesTime && !TripStopTime.same(time,existing.plannedStartAt(),existing.plannedDurationMin()))
   TripStopTime.validate(time,(LocalDate)trip.get("startDate"),(LocalDate)trip.get("endDate"),dayNo,zone,planningTime.now());
  String note=req.note()==null?existing.note():blankToNull(req.note());
  int radius=req.checkinRadiusM()==null?existing.checkinRadiusM():req.checkinRadiusM();
  List<StopCandidate> candidate=normalizeOrders(current.stream().map(stop -> {
   if(!stop.id().equals(stopId)) return stop;
   return new StopCandidate(
    stop.id(),
    placeId,
    dayNo,
    orderNo,
    time.start(),
    time.duration(),
    note,
    radius,
    stop.status(),
    stop.latitude(),
    stop.longitude()
   );
  }).toList());
  stopSequenceValidator.validateNoAdjacentDuplicate(candidate);
  StopCandidate updated=candidate.stream().filter(stop -> stop.id().equals(stopId)).findFirst().orElseThrow();
  repo.updateStop(
   stopId,
   updated.placeId(),
   updated.dayNo(),
   updated.orderNo(),
   updated.plannedStartAt(),
   updated.plannedDurationMin(),
   updated.note(),
   updated.checkinRadiusM()
  );
  repo.moveStopsToTemporaryOrders(tripId);
  persistOrders(candidate);
  return detail(userId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail reorderStops(UUID userId,UUID tripId,TripDtos.ReorderStopsRequest req) {
  requireLeader(tripId,userId);
  List<StopCandidate> current=toCandidates(repo.stopRows(tripId));
  Set<UUID> expected=new HashSet<>(current.stream().map(StopCandidate::id).toList());
  Set<UUID> provided=new HashSet<>();
  Set<String> positions=new HashSet<>();
  for(var item:req.stops()) {
   if(!provided.add(item.stopId())) throw ApiException.bad("Một stop bị gửi trùng trong danh sách sắp xếp.");
   if(!expected.contains(item.stopId())) throw ApiException.bad("Stop không thuộc lịch trình này.");
   if(!positions.add(item.dayNo()+":"+item.orderNo())) throw ApiException.bad("Thứ tự stop bị trùng.");
  }
  if(provided.size()!=expected.size()) throw ApiException.bad("Cần gửi đủ toàn bộ stop hiện có khi sắp xếp lại.");
  Map<UUID,TripDtos.StopOrder> orderById=new HashMap<>();
  for(var item:req.stops()) orderById.put(item.stopId(),item);
  List<StopCandidate> candidate=normalizeOrders(current.stream().map(stop -> {
   var order=orderById.get(stop.id());
   return withOrder(stop,order.dayNo(),order.orderNo());
  }).toList());
  stopSequenceValidator.validateNoAdjacentDuplicate(candidate);
  repo.moveStopsToTemporaryOrders(tripId);
  persistOrders(candidate);
  return detail(userId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail optimizeStops(UUID userId,UUID tripId,TripDtos.OptimizeStopsRequest req) {
  requireLeader(tripId,userId);
  Integer targetDay=req==null?null:req.dayNo();
  List<StopCandidate> current=toCandidates(repo.stopRows(tripId));
  List<StopCandidate> optimized=new ArrayList<>();
  Map<Integer,List<StopCandidate>> byDay=new TreeMap<>();
  for(StopCandidate stop:current) byDay.computeIfAbsent(stop.dayNo(),ignored -> new ArrayList<>()).add(stop);
  for(var entry:byDay.entrySet()) {
   List<StopCandidate> day=entry.getValue();
   day.sort(Comparator.comparingInt(StopCandidate::orderNo).thenComparing(StopCandidate::id));
   if(targetDay==null || entry.getKey().equals(targetDay)) {
    optimized.addAll(optimizeDay(day));
   } else {
    optimized.addAll(day);
   }
  }
  optimized=normalizeOrders(optimized);
  stopSequenceValidator.validateNoAdjacentDuplicate(optimized);
  repo.moveStopsToTemporaryOrders(tripId);
  persistOrders(optimized);
  return detail(userId,tripId);
 }

 private TripDtos.TripInvitationItem createInvitationLocked(UUID inviterId,UUID tripId,UUID inviteeId) {
  UUID target=validateInvitee(inviterId,inviteeId);
  if(repo.isActiveMember(tripId,target)) {
   throw new ApiException(409,"TRIP_MEMBER_EXISTS","Người này đã là thành viên lịch trình.");
  }
  var existing=invitations.pending(tripId,target);
  if(existing.isPresent()) return invitation(existing.get());
  UUID id=UUID.randomUUID();
  invitations.insert(id,tripId,inviterId,target);
  notifications.recordTripInvitation(target,inviterId,id,false);
  return invitations.byId(id).map(this::invitation).orElseThrow(ApiException::notFound);
 }

 private UUID validateInvitee(UUID inviterId,UUID inviteeId) {
  if(inviteeId==null) throw ApiException.bad("Thành viên được mời là bắt buộc.");
  if(inviterId.equals(inviteeId)) throw ApiException.bad("Không thể tự mời chính mình vào lịch trình.");
  if(!repo.activeUserIds(List.of(inviteeId)).contains(inviteeId)) {
   throw new ApiException(404,"USER_NOT_FOUND","Không tìm thấy thành viên được chọn.");
  }
  return inviteeId;
 }

 private String invitationStatus(String status) {
  String value=blankToNull(status);
  if(value==null) return "PENDING";
  value=value.toUpperCase(Locale.ROOT);
  if(!INVITATION_STATUSES.contains(value)) throw ApiException.bad("Trạng thái lời mời không hợp lệ.");
  return value;
 }

 private UUID ensureGroupConversationSynced(UUID tripId,UUID creatorId) {
  UUID conversationId=repo.groupConversationId(tripId).orElseGet(() -> {
   UUID created=UUID.randomUUID();
   conversations.createGroupForTrip(created,tripId,creatorId);
   return created;
  });
  for(var member:repo.activeTripMembers(tripId)) {
   UUID memberId=(UUID)member.get("userId");
   String role=(String)member.get("role");
   if(!conversations.participant(conversationId,memberId)) {
    conversations.addMember(conversationId,memberId,role);
   }
  }
  return conversationId;
 }

 private TripDtos.TripInvitationItem invitation(Map<String,Object> row) {
  return new TripDtos.TripInvitationItem(
   (UUID)row.get("invitationId"),
   (UUID)row.get("tripId"),
   (String)row.get("tripTitle"),
   (UUID)row.get("inviterUserId"),
   (String)row.get("inviterDisplayName"),
   (String)row.get("inviterAvatarUrl"),
   (UUID)row.get("inviteeUserId"),
   (String)row.get("inviteeDisplayName"),
   (String)row.get("inviteeAvatarUrl"),
   (String)row.get("status"),
   asLocalDateTime(row.get("createdAt")),
   asLocalDateTime(row.get("respondedAt"))
  );
 }

 private void requireLeader(UUID tripId,UUID userId) {
  lockAsLeader(tripId,userId);
 }

 private Map<String,Object> lockAsLeader(UUID tripId,UUID userId) {
  var trip=repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  if(!repo.detailForUser(tripId,userId).isPresent()) throw ApiException.notFound();
  if(!repo.isActiveLeader(tripId,userId)) throw ApiException.denied();
  return trip;
 }

 private Map<String,Object> lockInvitation(UUID invitationId) {
  // Trip identity is immutable. All lifecycle writers acquire Trip before invite.
  var preview=invitations.byId(invitationId).orElseThrow(ApiException::notFound);
  var trip=repo.tripForUpdate((UUID)preview.get("tripId")).orElseThrow(ApiException::notFound);
  if(trip.get("archivedAt")!=null) throw invitationClosed();
  return invitations.forUpdate(invitationId).orElseThrow(ApiException::notFound);
 }

 private TripDtos.TripDetail detailFromRow(Map<String,Object> row) {
  UUID tripId=(UUID)row.get("id");
  return new TripDtos.TripDetail(
   tripId,
   (UUID)row.get("ownerId"),
   (String)row.get("title"),
   (String)row.get("description"),
   (String)row.get("tripType"),
   (LocalDate)row.get("startDate"),
   (LocalDate)row.get("endDate"),
   (String)row.get("timezone"),
   (UUID)row.get("linkedConversationId"),
   Boolean.TRUE.equals(row.get("pinned")),
   ((Number)row.get("memberCount")).intValue(),
   asLocalDateTime(row.get("createdAt")),
   asLocalDateTime(row.get("updatedAt")),
   repo.members(tripId).stream().map(this::member).toList(),
   repo.stops(tripId).stream().map(stop -> stop(stop,planningTime.zone((String)row.get("timezone")))).toList(),
   repo.reminders(tripId).stream().map(this::reminder).toList(),
   invitations.pendingForTrip(tripId).stream().map(this::invitation).toList()
  );
 }

 private TripDtos.TripSummary summary(Map<String,Object> row) {
  return new TripDtos.TripSummary(
   (UUID)row.get("id"),
   (String)row.get("currentUserRole"),
   (String)row.get("title"),
   (String)row.get("description"),
   (String)row.get("tripType"),
   (LocalDate)row.get("startDate"),
   (LocalDate)row.get("endDate"),
   (String)row.get("timezone"),
   (UUID)row.get("linkedConversationId"),
   Boolean.TRUE.equals(row.get("pinned")),
   ((Number)row.get("memberCount")).intValue(),
   ((Number)row.get("stopCount")).intValue(),
   asLocalDateTime(row.get("createdAt")),
   asLocalDateTime(row.get("updatedAt"))
  );
 }

 private TripDtos.Member member(Map<String,Object> row) {
  return new TripDtos.Member(
   (UUID)row.get("userId"),
   (String)row.get("displayName"),
   (String)row.get("avatarUrl"),
   (String)row.get("role"),
   (String)row.get("status"),
   asLocalDateTime(row.get("joinedAt"))
  );
 }

 private TripDtos.Stop stop(Map<String,Object> row,ZoneId zone) {
  OffsetDateTime start=asUtc(row.get("plannedStartAt"));
  Integer duration=asInt(row.get("plannedDurationMin"));
  OffsetDateTime end=start==null || duration==null?null:start.plusMinutes(duration);
  return new TripDtos.Stop(
   (UUID)row.get("id"),
   ((Number)row.get("placeId")).longValue(),
   (String)row.get("name"),
   (String)row.get("category"),
   (String)row.get("categoryName"),
   (BigDecimal)row.get("latitude"),
   (BigDecimal)row.get("longitude"),
   (String)row.get("thumbnailUrl"),
   ((Number)row.get("dayNo")).intValue(),
   ((Number)row.get("orderNo")).intValue(),
   start,
   end,
   start==null?null:start.atZoneSameInstant(zone).toLocalDateTime(),
   end==null?null:end.atZoneSameInstant(zone).toLocalDateTime(),
   asInt(row.get("plannedDurationMin")),
   row.get("plannedStartAt")!=null && asInt(row.get("plannedDurationMin"))!=null,
   (String)row.get("note"),
   ((Number)row.get("checkinRadiusM")).intValue(),
   (String)row.get("status")
  );
 }

 private TripDtos.Reminder reminder(Map<String,Object> row) {
  return new TripDtos.Reminder(
   (UUID)row.get("id"),
   (UUID)row.get("tripStopId"),
   (UUID)row.get("recipientUserId"),
   (String)row.get("reminderType"),
   asLocalDateTime(row.get("remindAt")),
   (String)row.get("status")
  );
 }

 private static String cleanTitle(String value) {
  String title=value==null?"":value.trim();
  if(title.isEmpty()) throw ApiException.bad("Tên lịch trình không được để trống.");
  if(DEFAULT_TITLE.equalsIgnoreCase(title)) throw ApiException.bad("Hãy đổi tên lịch trình trước khi tạo.");
  return title;
 }

 private static String blankToNull(String value) {
  if(value==null) return null;
  String trimmed=value.trim();
  return trimmed.isEmpty()?null:trimmed;
 }

 private static String timezone(String value) {
  String tz=blankToNull(value);
  if(tz==null) return DEFAULT_TIMEZONE;
  try { ZoneId.of(tz); return tz; }
  catch(DateTimeException e) { throw ApiException.bad("Timezone không hợp lệ."); }
 }

 private static void validateDates(LocalDate start,LocalDate end) {
  if(start==null || end==null) throw ApiException.bad("Ngày bắt đầu và kết thúc là bắt buộc.");
  if(end.isBefore(start)) throw ApiException.bad("Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.");
 }

 private static Integer asInt(Object value) {
  if(value==null) return null;
  if(value instanceof Number number) return number.intValue();
  return Integer.valueOf(value.toString());
 }

 private static OffsetDateTime asUtc(Object value) {
  if(value==null) return null;
  if(value instanceof OffsetDateTime date) return date.withOffsetSameInstant(ZoneOffset.UTC);
  if(value instanceof Instant date) return date.atOffset(ZoneOffset.UTC);
  return asLocalDateTime(value).atOffset(ZoneOffset.UTC);
 }

 private List<StopCandidate> toCandidates(List<TripRepository.StopRow> rows) {
  return rows.stream().map(row -> new StopCandidate(
   row.id(),
   row.placeId(),
   row.dayNo(),
   row.orderNo(),
   row.plannedStartAt(),
   row.plannedDurationMin(),
   row.note(),
   row.checkinRadiusM(),
   row.status(),
   row.latitude(),
   row.longitude()
  )).toList();
 }

 private StopCandidate withOrder(StopCandidate stop,int dayNo,int orderNo) {
  return new StopCandidate(
   stop.id(),
   stop.placeId(),
   dayNo,
   orderNo,
   stop.plannedStartAt(),
   stop.plannedDurationMin(),
   stop.note(),
   stop.checkinRadiusM(),
   stop.status(),
   stop.latitude(),
   stop.longitude()
  );
 }

 private List<StopCandidate> normalizeOrders(Collection<StopCandidate> stops) {
  Map<Integer,List<StopCandidate>> byDay=new TreeMap<>();
  for(StopCandidate stop:stops) byDay.computeIfAbsent(stop.dayNo(),ignored -> new ArrayList<>()).add(stop);
  List<StopCandidate> normalized=new ArrayList<>();
  for(var entry:byDay.entrySet()) {
   List<StopCandidate> day=entry.getValue();
   day.sort(Comparator.comparingInt(StopCandidate::orderNo).thenComparing(StopCandidate::id));
   for(int i=0;i<day.size();i++) normalized.add(withOrder(day.get(i),entry.getKey(),i+1));
  }
  return normalized;
 }

 private void persistOrders(Collection<StopCandidate> stops) {
  for(StopCandidate stop:stops) repo.updateStopOrder(stop.id(),stop.dayNo(),stop.orderNo());
 }

 private List<StopCandidate> optimizeDay(List<StopCandidate> day) {
  if(day.size()<3) return day;
  List<StopCandidate> remaining=new ArrayList<>(day);
  List<StopCandidate> optimized=new ArrayList<>();
  StopCandidate current=remaining.remove(0);
  optimized.add(current);
  while(!remaining.isEmpty()) {
   StopCandidate anchor=current;
   StopCandidate next=remaining.stream()
    .filter(stop -> stop.placeId()!=anchor.placeId())
    .min(Comparator.comparingDouble(stop -> distanceKm(anchor,stop)))
    .orElseThrow(() -> new ApiException(
     400,
     "TRIP_STOP_OPTIMIZE_INVALID",
     "Không thể tối ưu vì kết quả sẽ làm hai địa điểm giống nhau đứng liền nhau."
    ));
   remaining.remove(next);
   optimized.add(next);
   current=next;
  }
  return normalizedOneDay(optimized);
 }

 private List<StopCandidate> normalizedOneDay(List<StopCandidate> stops) {
  if(stops.isEmpty()) return stops;
  int dayNo=stops.get(0).dayNo();
  List<StopCandidate> normalized=new ArrayList<>();
  for(int i=0;i<stops.size();i++) normalized.add(withOrder(stops.get(i),dayNo,i+1));
  return normalized;
 }

 private static double distanceKm(StopCandidate a,StopCandidate b) {
  double lat1=a.latitude()==null?0:a.latitude().doubleValue();
  double lon1=a.longitude()==null?0:a.longitude().doubleValue();
  double lat2=b.latitude()==null?0:b.latitude().doubleValue();
  double lon2=b.longitude()==null?0:b.longitude().doubleValue();
  double dLat=Math.toRadians(lat2-lat1);
  double dLon=Math.toRadians(lon2-lon1);
  double sLat1=Math.toRadians(lat1);
  double sLat2=Math.toRadians(lat2);
  double h=Math.sin(dLat/2)*Math.sin(dLat/2)
   +Math.cos(sLat1)*Math.cos(sLat2)*Math.sin(dLon/2)*Math.sin(dLon/2);
  return 6371.0*2*Math.atan2(Math.sqrt(h),Math.sqrt(1-h));
 }

 private static LocalDateTime asLocalDateTime(Object value) {
  if(value==null) return null;
  if(value instanceof LocalDateTime dateTime) return dateTime;
  if(value instanceof OffsetDateTime dateTime) return dateTime.toLocalDateTime();
  if(value instanceof Instant instant) return LocalDateTime.ofInstant(instant,ZoneOffset.UTC);
  throw new IllegalArgumentException("Unsupported date-time value: "+value.getClass().getName());
 }

 private static ApiException placeNotFound() {
  return new ApiException(404,"PLACE_NOT_FOUND","Địa điểm không tồn tại hoặc chưa sẵn sàng để thêm vào lịch trình.");
 }

 private static ApiException invitationClosed() {
  return new ApiException(409,"TRIP_INVITATION_CLOSED","Lời mời này không còn ở trạng thái chờ xử lý.");
 }

 private List<UUID> validatedSelectedMemberIds(UUID creatorId,List<UUID> selectedMemberIds) {
  if(selectedMemberIds==null || selectedMemberIds.isEmpty()) return List.of();
  LinkedHashSet<UUID> unique=new LinkedHashSet<>();
  for(UUID memberId:selectedMemberIds) {
   if(memberId==null) throw ApiException.bad("Danh sách thành viên không hợp lệ.");
   if(!memberId.equals(creatorId)) unique.add(memberId);
  }
  if(unique.isEmpty()) return List.of();
  Set<UUID> active=new HashSet<>(repo.activeUserIds(unique));
  for(UUID memberId:unique) {
   if(!active.contains(memberId)) throw new ApiException(404,"USER_NOT_FOUND","Không tìm thấy thành viên được chọn.");
  }
  return List.copyOf(unique);
 }

 private List<UUID> validatedInvitationMemberIds(UUID inviterId,List<UUID> selectedMemberIds) {
  if(selectedMemberIds==null || selectedMemberIds.isEmpty()) return List.of();
  LinkedHashSet<UUID> unique=new LinkedHashSet<>();
  for(UUID memberId:selectedMemberIds) {
   if(memberId==null) throw ApiException.bad("Danh sách thành viên không hợp lệ.");
   if(memberId.equals(inviterId)) throw ApiException.bad("Không thể tự mời chính mình vào lịch trình.");
   unique.add(memberId);
  }
  if(unique.isEmpty()) return List.of();
  Set<UUID> active=new HashSet<>(repo.activeUserIds(unique));
  for(UUID memberId:unique) {
   if(!active.contains(memberId)) throw new ApiException(404,"USER_NOT_FOUND","Không tìm thấy thành viên được chọn.");
  }
  return List.copyOf(unique);
 }

 private void afterCommit(Runnable action) {
  if(TransactionSynchronizationManager.isSynchronizationActive()) {
   TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
    @Override public void afterCommit() { action.run(); }
   });
  } else {
   action.run();
  }
 }

 private void notifyCreateMembersReady(UUID tripId,UUID creatorId,List<UUID> selectedMemberIds) {
  if(selectedMemberIds.isEmpty()) return;
  log.info(
   "Trip create member notification hook ready after commit: tripId={} creatorId={} selectedMemberCount={}",
   tripId,
   creatorId,
   selectedMemberIds.size()
  );
 }

 private void notifyInvitationsReady(UUID tripId,UUID actorId,List<UUID> inviteeIds) {
  if(inviteeIds.isEmpty()) return;
  log.info(
   "Trip invitation notification hook ready after commit: tripId={} actorId={} inviteeCount={} channel=IN_APP_INVITATION_ONLY",
   tripId,
   actorId,
   inviteeIds.size()
  );
 }

 private void notifyInvitationAccepted(UUID tripId,UUID invitationId,UUID inviteeId) {
  log.info(
   "Trip invitation accepted hook ready after commit: tripId={} invitationId={} inviteeId={}",
   tripId,
   invitationId,
   inviteeId
  );
 }
}
