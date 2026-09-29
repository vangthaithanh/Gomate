package vn.gomate.trip.repository;

import java.time.*;
import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class TripRepository {
 private final Db db;
 public TripRepository(Db db) { this.db=db; }

 public void insertTrip(UUID id,UUID ownerId,String title,String description,LocalDate startDate,LocalDate endDate,String timezone) {
  db.update("""
   INSERT INTO trips(id,owner_id,title,description,trip_type,status,start_date,end_date,timezone)
   VALUES(:id,:ownerId,:title,:description,'PERSONAL','DRAFT',:startDate,:endDate,:timezone)
   """,args("id",id,"ownerId",ownerId,"title",title,"description",description,"startDate",startDate,"endDate",endDate,"timezone",timezone));
 }

 public void insertLeader(UUID tripId,UUID userId) {
  db.update("""
   INSERT INTO trip_members(trip_id,user_id,role,status)
   VALUES(:tripId,:userId,'LEADER','ACTIVE')
   """,args("tripId",tripId,"userId",userId));
 }

 public List<Map<String,Object>> listForUser(UUID userId) {
  return db.list("""
   SELECT t.id,t.title,t.description,t.trip_type,t.status,t.start_date,t.end_date,t.timezone,
          t.created_at,t.updated_at,COUNT(s.id) AS stop_count
   FROM trips t
   JOIN trip_members m ON m.trip_id=t.id
   LEFT JOIN trip_stops s ON s.trip_id=t.id
   WHERE m.user_id=:userId AND m.status='ACTIVE'
   GROUP BY t.id,t.title,t.description,t.trip_type,t.status,t.start_date,t.end_date,t.timezone,t.created_at,t.updated_at
   ORDER BY t.created_at DESC,t.id
   """,args("userId",userId));
 }

 public Optional<Map<String,Object>> detailForUser(UUID tripId,UUID userId) {
  return db.list("""
   SELECT t.id,t.owner_id,t.title,t.description,t.trip_type,t.status,t.start_date,t.end_date,t.timezone,
          t.started_at,t.completed_at,t.created_at,t.updated_at
   FROM trips t
   JOIN trip_members m ON m.trip_id=t.id
   WHERE t.id=:tripId AND m.user_id=:userId AND m.status='ACTIVE'
   """,args("tripId",tripId,"userId",userId)).stream().findFirst();
 }

 public Optional<Map<String,Object>> tripForUpdate(UUID tripId) {
  return db.list("SELECT * FROM trips WHERE id=:tripId FOR UPDATE",args("tripId",tripId)).stream().findFirst();
 }

 public boolean isActiveLeader(UUID tripId,UUID userId) {
  return db.count("""
   SELECT COUNT(*) FROM trip_members
   WHERE trip_id=:tripId AND user_id=:userId AND role='LEADER' AND status='ACTIVE'
   """,args("tripId",tripId,"userId",userId))==1;
 }

 public void updateTrip(UUID tripId,String title,String description,LocalDate startDate,LocalDate endDate,String status,String timezone) {
  db.update("""
   UPDATE trips
   SET title=:title,
       description=:description,
       start_date=:startDate,
       end_date=:endDate,
       status=:status,
       timezone=:timezone,
       started_at=CASE WHEN :status='ACTIVE' AND started_at IS NULL THEN CURRENT_TIMESTAMP ELSE started_at END,
       completed_at=CASE WHEN :status='COMPLETED' AND completed_at IS NULL THEN CURRENT_TIMESTAMP ELSE completed_at END,
       updated_at=CURRENT_TIMESTAMP
   WHERE id=:tripId
   """,args("tripId",tripId,"title",title,"description",description,"startDate",startDate,"endDate",endDate,"status",status,"timezone",timezone));
 }

 public void deleteTrip(UUID tripId) {
  db.update("DELETE FROM trips WHERE id=:tripId",args("tripId",tripId));
 }

 public boolean activePlaceExists(long placeId) {
  return db.count("SELECT COUNT(*) FROM places WHERE id=:placeId AND status='ACTIVE'",args("placeId",placeId))==1;
 }

 public int nextOrder(UUID tripId,int dayNo) {
  var rows=db.list("SELECT COALESCE(MAX(order_no),0)+1 AS next_order FROM trip_stops WHERE trip_id=:tripId AND day_no=:dayNo",args("tripId",tripId,"dayNo",dayNo));
  return ((Number)rows.get(0).get("nextOrder")).intValue();
 }

 public UUID insertStop(UUID tripId,long placeId,int dayNo,int orderNo,OffsetDateTime plannedStartAt,Integer plannedDurationMin,String note,int checkinRadiusM) {
  UUID id=UUID.randomUUID();
  db.update("""
   INSERT INTO trip_stops(id,trip_id,place_id,day_no,order_no,planned_start_at,planned_duration_min,note,checkin_radius_m,status)
   VALUES(:id,:tripId,:placeId,:dayNo,:orderNo,:plannedStartAt,:plannedDurationMin,:note,:checkinRadiusM,'PLANNED')
   """,args("id",id,"tripId",tripId,"placeId",placeId,"dayNo",dayNo,"orderNo",orderNo,"plannedStartAt",plannedStartAt,"plannedDurationMin",plannedDurationMin,"note",note,"checkinRadiusM",checkinRadiusM));
  return id;
 }

 public Optional<UUID> stopTripId(UUID stopId) {
  return db.list("SELECT trip_id FROM trip_stops WHERE id=:stopId",args("stopId",stopId)).stream()
   .findFirst().map(row -> (UUID)row.get("tripId"));
 }

 public void deleteStop(UUID stopId) {
  db.update("DELETE FROM trip_stops WHERE id=:stopId",args("stopId",stopId));
 }

 public List<UUID> stopIds(UUID tripId) {
  return db.list("SELECT id FROM trip_stops WHERE trip_id=:tripId ORDER BY day_no,order_no,id",args("tripId",tripId))
   .stream().map(row -> (UUID)row.get("id")).toList();
 }

 public void moveStopsToTemporaryOrders(UUID tripId) {
  db.update("""
   UPDATE trip_stops
   SET order_no=order_no+1000000,updated_at=CURRENT_TIMESTAMP
   WHERE trip_id=:tripId
   """,args("tripId",tripId));
 }

 public void updateStopOrder(UUID stopId,int dayNo,int orderNo) {
  db.update("""
   UPDATE trip_stops
   SET day_no=:dayNo,order_no=:orderNo,updated_at=CURRENT_TIMESTAMP
   WHERE id=:stopId
   """,args("stopId",stopId,"dayNo",dayNo,"orderNo",orderNo));
 }

 public List<Map<String,Object>> members(UUID tripId) {
  return db.list("""
   SELECT user_id,role,status,joined_at,location_sharing_enabled
   FROM trip_members
   WHERE trip_id=:tripId
   ORDER BY CASE role WHEN 'LEADER' THEN 0 ELSE 1 END,joined_at,user_id
   """,args("tripId",tripId));
 }

 public List<Map<String,Object>> stops(UUID tripId) {
  return db.list("""
   SELECT s.id,s.place_id,p.name,c.code AS category,c.name AS category_name,
          p.latitude,p.longitude,
          (SELECT pm.url FROM place_media pm
           WHERE pm.place_id=p.id AND pm.media_type='IMAGE'
           ORDER BY pm.sort_order,pm.id LIMIT 1) AS thumbnail_url,
          s.day_no,s.order_no,s.planned_start_at,s.planned_duration_min,
          s.note,s.checkin_radius_m,s.status
   FROM trip_stops s
   JOIN places p ON p.id=s.place_id
   JOIN place_categories c ON c.id=p.category_id
   WHERE s.trip_id=:tripId
   ORDER BY s.day_no,s.order_no,s.id
   """,args("tripId",tripId));
 }

 public List<Map<String,Object>> reminders(UUID tripId) {
  return db.list("""
   SELECT id,trip_stop_id,recipient_user_id,reminder_type,remind_at,status
   FROM trip_reminders
   WHERE trip_id=:tripId
   ORDER BY remind_at,id
   """,args("tripId",tripId));
 }
}
