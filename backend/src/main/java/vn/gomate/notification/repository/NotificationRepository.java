package vn.gomate.notification.repository;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class NotificationRepository {
 private final Db db;
 public NotificationRepository(Db db) { this.db=db; }

 public UUID insertPostInteraction(UUID recipient,UUID actor,String type,String entity,String event,String body,String data) {
  UUID id=UUID.randomUUID();
  int inserted=db.update("""
   INSERT INTO notifications(id,user_id,type,actor_id,entity_type,entity_id,title,body,data)
   VALUES(:id,:recipient,:type,:actor,:entity,:event,'Tương tác bài viết',:body,CAST(:data AS JSONB))
   ON CONFLICT DO NOTHING
   """,args("id",id,"recipient",recipient,"type",type,"actor",actor,"entity",entity,"event",event,"body",body,"data",data));
  return inserted==1?id:null;
 }

 public UUID insertTripInvitation(UUID recipientId,UUID actorId,UUID invitationId,boolean accepted) {
  String type=accepted?"TRIP_INVITATION_ACCEPTED":"TRIP_INVITATION";
  if(db.count("""
   SELECT COUNT(*) FROM notifications
   WHERE user_id=:userId AND type=:type AND entity_type='TRIP_INVITATION' AND entity_id=:entityId
   """,args("userId",recipientId,"type",type,"entityId",invitationId.toString()))>0) return null;
  UUID id=UUID.randomUUID();
  db.update("""
   INSERT INTO notifications(id,user_id,type,actor_id,entity_type,entity_id,title,body)
   VALUES(:id,:userId,:type,:actorId,'TRIP_INVITATION',:entityId,:title,:body)
   """,args("id",id,"userId",recipientId,"type",type,"actorId",actorId,
    "entityId",invitationId.toString(),"title",accepted?"Lời mời đã được chấp nhận":"Lời mời lịch trình",
    "body",accepted?"đã chấp nhận lời mời tham gia lịch trình":"mời bạn tham gia lịch trình"));
  return id;
 }

 public UUID insertTripDateReminder(UUID recipientId,UUID reminderId,String tripTitle,int days,java.time.LocalDate start) {
  if(db.count("SELECT COUNT(*) FROM notifications WHERE user_id=:user AND type='TRIP_START_REMINDER' AND entity_type='TRIP_REMINDER' AND entity_id=:entity",
   args("user",recipientId,"entity",reminderId.toString()))>0) return null;
  UUID id=UUID.randomUUID();
  String date=start.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"));
  String body=days==2?"Bạn có lịch trình ‘"+tripTitle+"’ bắt đầu vào "+date+". Hãy chuẩn bị cho chuyến đi.":
   "Nhắc lần hai: lịch trình ‘"+tripTitle+"’ bắt đầu vào ngày mai ("+date+"). Hãy chuẩn bị cho chuyến đi.";
  db.update("""
   INSERT INTO notifications(id,user_id,type,entity_type,entity_id,title,body)
   VALUES(:id,:user,'TRIP_START_REMINDER','TRIP_REMINDER',:entity,'Nhắc lịch trình dự kiến',:body)
   """,args("id",id,"user",recipientId,"entity",reminderId.toString(),"body",body));
  return id;
 }

 public List<Map<String,Object>> forInvitation(UUID invitationId) {
  return db.list("SELECT id,user_id FROM notifications WHERE entity_type='TRIP_INVITATION' AND entity_id=:id",
   args("id",invitationId.toString()));
 }

 public List<Map<String,Object>> list(UUID userId,int limit,int offset) {
  return rows("WHERE n.user_id=:userId ORDER BY n.created_at DESC,n.id DESC LIMIT :limit OFFSET :offset",
   args("userId",userId,"limit",limit,"offset",offset));
 }

 public Optional<Map<String,Object>> byId(UUID userId,UUID id) {
  return rows("WHERE n.user_id=:userId AND n.id=:id",args("userId",userId,"id",id)).stream().findFirst();
 }

 public long count(UUID userId,boolean unreadOnly) {
  return db.count("SELECT COUNT(*) FROM notifications WHERE user_id=:userId"+(unreadOnly?" AND is_read=FALSE":""),args("userId",userId));
 }

 public int markRead(UUID userId,UUID id) {
  return db.update("UPDATE notifications SET is_read=TRUE WHERE user_id=:userId AND id=:id",args("userId",userId,"id",id));
 }

 public void markAllRead(UUID userId) {
  db.update("UPDATE notifications SET is_read=TRUE WHERE user_id=:userId AND is_read=FALSE",args("userId",userId));
 }

 private List<Map<String,Object>> rows(String where,Map<String,Object> params) {
  return db.list("""
   SELECT n.id,n.type,n.actor_id,
    COALESCE(NULLIF(p.full_name,''),p.nickname,'Người dùng') AS actor_name,
    p.avatar_url,n.body AS message,n.is_read,n.created_at AS occurred_at,
    ti.id AS invitation_id,COALESCE(ti.status,'UNAVAILABLE') AS invitation_status,
    CASE WHEN n.type='TRIP_START_REMINDER' THEN
      CASE WHEN rt.archived_at IS NULL AND rm.status='ACTIVE' AND ru.status='ACTIVE' THEN rt.id ELSE NULL END
     ELSE CASE WHEN t.archived_at IS NULL THEN t.id ELSE NULL END END AS trip_id,
    COALESCE(rt.title,t.title) AS trip_name,
    r.id AS reminder_id,r.offset_minutes AS reminder_offset_minutes,r.planned_start_at,
    r.days_before AS reminder_days_before,r.trip_start_date,r.reminder_date,r.reminder_timezone,
    n.title,n.data
   FROM notifications n
   LEFT JOIN user_profiles p ON p.user_id=n.actor_id
   LEFT JOIN trip_invitations ti ON n.entity_type='TRIP_INVITATION' AND CAST(ti.id AS VARCHAR(80))=n.entity_id
   LEFT JOIN trips t ON t.id=ti.trip_id
   LEFT JOIN trip_reminders r ON n.entity_type='TRIP_REMINDER' AND CAST(r.id AS VARCHAR(80))=n.entity_id AND r.recipient_user_id=n.user_id
   LEFT JOIN trips rt ON rt.id=r.trip_id
   LEFT JOIN trip_members rm ON rm.trip_id=rt.id AND rm.user_id=n.user_id
   LEFT JOIN users ru ON ru.id=rm.user_id
   """+where,params);
 }
}
