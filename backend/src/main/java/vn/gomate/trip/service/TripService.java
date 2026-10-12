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
import vn.gomate.message.repository.ConversationRepository;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.model.TripStopSequenceItem;
import vn.gomate.trip.repository.TripRepository;

@Service
public class TripService {
 private static final Logger log=LoggerFactory.getLogger(TripService.class);
 private static final String DEFAULT_TIMEZONE="Asia/Ho_Chi_Minh";
 private static final String DEFAULT_TITLE="Lịch trình";
 private final TripRepository repo;
 private final ConversationRepository conversations;
 private final TripStopSequenceValidator stopSequenceValidator;
 public TripService(TripRepository repo,ConversationRepository conversations,TripStopSequenceValidator stopSequenceValidator) {
  this.repo=repo;
  this.conversations=conversations;
  this.stopSequenceValidator=stopSequenceValidator;
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

 private record StopTime(OffsetDateTime plannedStartAt,Integer plannedDurationMin) {}

 @Transactional
 public TripDtos.TripDetail create(UUID userId,TripDtos.CreateTripRequest req) {
  validateDates(req.startDate(),req.endDate());
  UUID tripId=UUID.randomUUID();
  String title=cleanTitle(req.title());
  List<UUID> selectedMemberIds=validatedSelectedMemberIds(userId,req.selectedMemberIds());
  List<UUID> effectiveMembers=new ArrayList<>();
  effectiveMembers.add(userId);
  effectiveMembers.addAll(selectedMemberIds);
  String tripType=effectiveMembers.size()>1?"GROUP":"PERSONAL";
  repo.insertTrip(tripId,userId,title,blankToNull(req.description()),tripType,req.startDate(),req.endDate(),timezone(req.timezone()));
  repo.insertLeader(tripId,userId);
  for(UUID memberId:selectedMemberIds) {
   repo.insertMember(tripId,memberId,"MEMBER",userId);
  }
  if("GROUP".equals(tripType)) {
   UUID conversationId=UUID.randomUUID();
   conversations.createGroupForTrip(conversationId,tripId,userId);
   for(UUID memberId:effectiveMembers) {
    conversations.addMember(conversationId,memberId,memberId.equals(userId)?"LEADER":"MEMBER");
   }
   afterCommit(() -> notifyCreateMembersReady(tripId,userId,selectedMemberIds));
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
 public TripDtos.TripDetail pin(UUID userId,UUID tripId) {
  if(!repo.isActiveMember(tripId,userId)) throw ApiException.notFound();
  repo.pinTrip(userId,tripId);
  return detail(userId,tripId);
 }

 @Transactional
 public void unpin(UUID userId,UUID tripId) {
  if(!repo.isActiveMember(tripId,userId)) throw ApiException.notFound();
  repo.unpinTrip(userId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail update(UUID userId,UUID tripId,TripDtos.UpdateTripRequest req) {
  requireLeader(tripId,userId);
  var current=repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  String title=req.title()==null?(String)current.get("title"):cleanTitle(req.title());
  String description=req.description()==null?(String)current.get("description"):blankToNull(req.description());
  LocalDate startDate=req.startDate()==null?(LocalDate)current.get("startDate"):req.startDate();
  LocalDate endDate=req.endDate()==null?(LocalDate)current.get("endDate"):req.endDate();
  String status=req.status()==null?(String)current.get("status"):req.status();
  String timezone=req.timezone()==null?(String)current.get("timezone"):timezone(req.timezone());
  validateDates(startDate,endDate);
  validateStatus(status);
 repo.updateTrip(tripId,title,description,startDate,endDate,status,timezone);
  return detail(userId,tripId);
 }

 @Transactional
 public TripDtos.TripDetail addMembers(UUID userId,UUID tripId,TripDtos.AddMembersRequest req) {
  requireLeader(tripId,userId);
  repo.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  List<UUID> selectedMemberIds=validatedSelectedMemberIds(userId,req.selectedMemberIds());
  if(selectedMemberIds.isEmpty()) return detail(userId,tripId);

  Set<UUID> existing=new HashSet<>(repo.activeTripUserIds(tripId));
  List<UUID> newMembers=new ArrayList<>();
  for(UUID memberId:selectedMemberIds) {
   if(existing.add(memberId)) {
    repo.insertMember(tripId,memberId,"MEMBER",userId);
    newMembers.add(memberId);
   }
  }

  if(newMembers.isEmpty()) return detail(userId,tripId);

  repo.updateTripType(tripId,"GROUP");
  UUID conversationId=repo.groupConversationId(tripId).orElseGet(() -> {
   UUID created=UUID.randomUUID();
   conversations.createGroupForTrip(created,tripId,userId);
   return created;
  });

  for(UUID memberId:existing) {
   if(!conversations.participant(conversationId,memberId)) {
    conversations.addMember(conversationId,memberId,memberId.equals(userId)?"LEADER":"MEMBER");
   }
  }

  afterCommit(() -> notifyAddMembersReady(tripId,userId,newMembers));
  return detail(userId,tripId);
 }

 @Transactional
 public void delete(UUID userId,UUID tripId) {
  requireLeader(tripId,userId);
  repo.deleteTrip(tripId);
 }

 @Transactional
 public TripDtos.TripDetail addStop(UUID userId,UUID tripId,TripDtos.AddStopRequest req) {
  requireLeader(tripId,userId);
  if(!repo.activePlaceExists(req.placeId())) throw placeNotFound();
  int dayNo=req.dayNo()==null?1:req.dayNo();
  List<StopCandidate> current=toCandidates(repo.stopRows(tripId));
  int dayCount=(int)current.stream().filter(stop -> stop.dayNo()==dayNo).count();
  int orderNo=req.orderNo()==null?dayCount+1:Math.max(1,Math.min(req.orderNo(),dayCount+1));
  UUID stopId=UUID.randomUUID();
  int radius=req.checkinRadiusM()==null?150:req.checkinRadiusM();
  StopTime time=normalizeTime(req.plannedStartAt(),req.plannedEndAt(),req.plannedDurationMin(),true);
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
   time.plannedStartAt(),
   time.plannedDurationMin(),
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
  requireLeader(tripId,userId);
  var actualTripId=repo.stopTripId(stopId).orElseThrow(ApiException::notFound);
  if(!tripId.equals(actualTripId)) throw ApiException.notFound();
  List<StopCandidate> current=toCandidates(repo.stopRows(tripId));
  StopCandidate existing=current.stream().filter(stop -> stop.id().equals(stopId)).findFirst().orElseThrow(ApiException::notFound);
  long placeId=req.placeId()==null?existing.placeId():req.placeId();
  if(placeId!=existing.placeId() && !repo.activePlaceExists(placeId)) throw placeNotFound();
  int dayNo=req.dayNo()==null?existing.dayNo():req.dayNo();
  int orderNo=req.orderNo()==null?existing.orderNo():req.orderNo();
  boolean touchesTime=Boolean.TRUE.equals(req.clearTime())
   || req.plannedStartAt()!=null
   || req.plannedEndAt()!=null
   || req.plannedDurationMin()!=null;
  StopTime time=touchesTime
   ? normalizeTime(req.plannedStartAt(),req.plannedEndAt(),req.plannedDurationMin(),true)
   : new StopTime(existing.plannedStartAt(),existing.plannedDurationMin());
  String note=req.note()==null?existing.note():blankToNull(req.note());
  int radius=req.checkinRadiusM()==null?existing.checkinRadiusM():req.checkinRadiusM();
  List<StopCandidate> candidate=normalizeOrders(current.stream().map(stop -> {
   if(!stop.id().equals(stopId)) return stop;
   return new StopCandidate(
    stop.id(),
    placeId,
    dayNo,
    orderNo,
    time.plannedStartAt(),
    time.plannedDurationMin(),
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

 private void requireLeader(UUID tripId,UUID userId) {
  if(!repo.detailForUser(tripId,userId).isPresent()) throw ApiException.notFound();
  if(!repo.isActiveLeader(tripId,userId)) throw ApiException.denied();
 }

 private TripDtos.TripDetail detailFromRow(Map<String,Object> row) {
  UUID tripId=(UUID)row.get("id");
  return new TripDtos.TripDetail(
   tripId,
   (UUID)row.get("ownerId"),
   (String)row.get("title"),
   (String)row.get("description"),
   (String)row.get("tripType"),
   (String)row.get("status"),
   (LocalDate)row.get("startDate"),
   (LocalDate)row.get("endDate"),
   (String)row.get("timezone"),
   (UUID)row.get("linkedConversationId"),
   Boolean.TRUE.equals(row.get("pinned")),
   ((Number)row.get("memberCount")).intValue(),
   asLocalDateTime(row.get("startedAt")),
   asLocalDateTime(row.get("completedAt")),
   asLocalDateTime(row.get("createdAt")),
   asLocalDateTime(row.get("updatedAt")),
   repo.members(tripId).stream().map(this::member).toList(),
   repo.stops(tripId).stream().map(this::stop).toList(),
   repo.reminders(tripId).stream().map(this::reminder).toList()
  );
 }

 private TripDtos.TripSummary summary(Map<String,Object> row) {
  return new TripDtos.TripSummary(
   (UUID)row.get("id"),
   (String)row.get("title"),
   (String)row.get("description"),
   (String)row.get("tripType"),
   (String)row.get("status"),
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
   asLocalDateTime(row.get("joinedAt")),
   (Boolean)row.get("locationSharingEnabled")
  );
 }

 private TripDtos.Stop stop(Map<String,Object> row) {
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
   asLocalDateTime(row.get("plannedStartAt")),
   plannedEnd(row.get("plannedStartAt"),row.get("plannedDurationMin")),
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

 private static void validateStatus(String status) {
  if(!Set.of("DRAFT","PLANNED","ACTIVE","COMPLETED","CANCELLED").contains(status)) throw ApiException.bad("Trạng thái lịch trình không hợp lệ.");
 }

 private static Integer asInt(Object value) {
  if(value==null) return null;
  if(value instanceof Number number) return number.intValue();
  return Integer.valueOf(value.toString());
 }

 private static LocalDateTime plannedEnd(Object plannedStartAt,Object durationValue) {
  LocalDateTime start=asLocalDateTime(plannedStartAt);
  Integer duration=asInt(durationValue);
  if(start==null || duration==null) return null;
  return start.plusMinutes(duration);
 }

 private StopTime normalizeTime(OffsetDateTime start,OffsetDateTime end,Integer durationMin,boolean touched) {
  if(!touched || start==null) return new StopTime(null,null);
  if(end!=null) {
   long minutes=Duration.between(start,end).toMinutes();
   if(minutes<=0) throw ApiException.bad("Giờ kết thúc phải sau giờ bắt đầu.");
   return new StopTime(start,(int)minutes);
  }
  return new StopTime(start,durationMin);
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

 private void notifyAddMembersReady(UUID tripId,UUID actorId,List<UUID> memberIds) {
  if(memberIds.isEmpty()) return;
  log.info(
   "Trip add member notification hook ready after commit: tripId={} actorId={} addedMemberCount={}",
   tripId,
   actorId,
   memberIds.size()
  );
 }
}
