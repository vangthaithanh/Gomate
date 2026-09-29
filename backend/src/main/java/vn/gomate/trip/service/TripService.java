package vn.gomate.trip.service;

import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.repository.TripRepository;

@Service
public class TripService {
 private static final String DEFAULT_TIMEZONE="Asia/Ho_Chi_Minh";
 private final TripRepository repo;
 public TripService(TripRepository repo) { this.repo=repo; }

 @Transactional
 public TripDtos.TripDetail create(UUID userId,TripDtos.CreateTripRequest req) {
  validateDates(req.startDate(),req.endDate());
  UUID tripId=UUID.randomUUID();
  repo.insertTrip(tripId,userId,cleanTitle(req.title()),blankToNull(req.description()),req.startDate(),req.endDate(),timezone(req.timezone()));
  repo.insertLeader(tripId,userId);
  return detail(userId,tripId);
 }

 public List<TripDtos.TripSummary> list(UUID userId) {
  return repo.listForUser(userId).stream().map(this::summary).toList();
 }

 public TripDtos.TripDetail detail(UUID userId,UUID tripId) {
  var trip=repo.detailForUser(tripId,userId).orElseThrow(ApiException::notFound);
  return detailFromRow(trip);
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
 public void delete(UUID userId,UUID tripId) {
  requireLeader(tripId,userId);
  repo.deleteTrip(tripId);
 }

 @Transactional
 public TripDtos.TripDetail addStop(UUID userId,UUID tripId,TripDtos.AddStopRequest req) {
  requireLeader(tripId,userId);
  if(!repo.activePlaceExists(req.placeId())) throw placeNotFound();
  int dayNo=req.dayNo()==null?1:req.dayNo();
  int orderNo=req.orderNo()==null?repo.nextOrder(tripId,dayNo):req.orderNo();
  int radius=req.checkinRadiusM()==null?150:req.checkinRadiusM();
  repo.insertStop(tripId,req.placeId(),dayNo,orderNo,req.plannedStartAt(),req.plannedDurationMin(),blankToNull(req.note()),radius);
  return detail(userId,tripId);
 }

 @Transactional
 public void deleteStop(UUID userId,UUID tripId,UUID stopId) {
  requireLeader(tripId,userId);
  var actualTripId=repo.stopTripId(stopId).orElseThrow(ApiException::notFound);
  if(!tripId.equals(actualTripId)) throw ApiException.notFound();
  repo.deleteStop(stopId);
 }

 @Transactional
 public TripDtos.TripDetail reorderStops(UUID userId,UUID tripId,TripDtos.ReorderStopsRequest req) {
  requireLeader(tripId,userId);
  List<UUID> existing=repo.stopIds(tripId);
  Set<UUID> expected=new HashSet<>(existing);
  Set<UUID> provided=new HashSet<>();
  Set<String> positions=new HashSet<>();
  for(var item:req.stops()) {
   if(!provided.add(item.stopId())) throw ApiException.bad("Một stop bị gửi trùng trong danh sách sắp xếp.");
   if(!expected.contains(item.stopId())) throw ApiException.bad("Stop không thuộc lịch trình này.");
   if(!positions.add(item.dayNo()+":"+item.orderNo())) throw ApiException.bad("Thứ tự stop bị trùng.");
  }
  if(provided.size()!=existing.size()) throw ApiException.bad("Cần gửi đủ toàn bộ stop hiện có khi sắp xếp lại.");
  repo.moveStopsToTemporaryOrders(tripId);
  for(var item:req.stops()) repo.updateStopOrder(item.stopId(),item.dayNo(),item.orderNo());
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
   ((Number)row.get("stopCount")).intValue(),
   asLocalDateTime(row.get("createdAt")),
   asLocalDateTime(row.get("updatedAt"))
  );
 }

 private TripDtos.Member member(Map<String,Object> row) {
  return new TripDtos.Member(
   (UUID)row.get("userId"),
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
   asInt(row.get("plannedDurationMin")),
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
}
