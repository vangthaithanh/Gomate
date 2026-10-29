package vn.gomate.trip.repository;

import java.time.*;
import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class TripReminderRepository {
 private final Db db;
 public TripReminderRepository(Db db) { this.db=db; }
 public List<Map<String,Object>> forTrip(UUID tripId) {
  return db.list("SELECT * FROM trip_reminders WHERE trip_id=:trip AND reminder_type='TRIP_START' AND days_before IS NOT NULL",args("trip",tripId));
 }
 public void schedule(UUID tripId,UUID user,int days,LocalDate start,String zone,Instant due) {
  var date=start.minusDays(days);
  var values=args("trip",tripId,"user",user,"days",days,"start",start,"date",date,"zone",zone,"due",due.atOffset(ZoneOffset.UTC));
  var existing=forKey(tripId,user,date);
  if(existing.isPresent()) {
   values.put("id",existing.get().get("id"));
   db.update("""
    UPDATE trip_reminders SET remind_at=:due,days_before=:days,trip_start_date=:start,
     reminder_timezone=:zone,status='PENDING' WHERE id=:id AND status<>'SENT'
    """,values);
  } else {
   values.put("id",UUID.randomUUID());
   db.update("""
    INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,days_before,
     trip_start_date,reminder_date,reminder_timezone,remind_at)
    VALUES(:id,:trip,:user,'TRIP_START',:days,:start,:date,:zone,:due)
    """,values);
  }
 }
 private Optional<Map<String,Object>> forKey(UUID trip,UUID user,LocalDate date) {
  return db.list("SELECT id,status FROM trip_reminders WHERE trip_id=:trip AND recipient_user_id=:user AND reminder_type='TRIP_START' AND reminder_date=:date",
   args("trip",trip,"user",user,"date",date)).stream().findFirst();
 }
 public boolean sentOnDate(UUID trip,UUID user,LocalDate date,ZoneId zone) {
  return db.count("""
   SELECT COUNT(*) FROM trip_reminders WHERE trip_id=:trip AND recipient_user_id=:user
    AND reminder_type='TRIP_START' AND status='SENT'
    AND COALESCE(sent_at,remind_at)>=:start AND COALESCE(sent_at,remind_at)<:end
   """,args("trip",trip,"user",user,"start",date.atStartOfDay(zone).toOffsetDateTime(),
    "end",date.plusDays(1).atStartOfDay(zone).toOffsetDateTime()))>0;
 }
 public void cancel(UUID trip,UUID user) {
  db.update("UPDATE trip_reminders SET status='CANCELLED' WHERE trip_id=:trip AND reminder_type='TRIP_START' AND days_before IS NOT NULL AND status='PENDING'"+
   (user==null?"":" AND recipient_user_id=:user"),args("trip",trip,"user",user));
 }
 public void cancelId(UUID id) { db.update("UPDATE trip_reminders SET status='CANCELLED' WHERE id=:id AND status='PENDING'",args("id",id)); }
 public List<Map<String,Object>> due(Instant now) {
  return db.list("""
   SELECT id,trip_id FROM trip_reminders WHERE status='PENDING' AND reminder_type='TRIP_START'
    AND days_before IS NOT NULL AND remind_at<=:now ORDER BY remind_at,id LIMIT 100
   """,args("now",now.atOffset(ZoneOffset.UTC)));
 }
 public Map<String,Object> lock(UUID id) { return db.one("SELECT * FROM trip_reminders WHERE id=:id FOR UPDATE",args("id",id)); }
 public void sent(UUID id,Instant now) { db.update("UPDATE trip_reminders SET status='SENT',sent_at=:now WHERE id=:id AND status='PENDING'",args("id",id,"now",now.atOffset(ZoneOffset.UTC))); }
 public boolean eligible(UUID trip,UUID user) {
  return db.count("""
   SELECT COUNT(*) FROM trips t JOIN trip_members m ON m.trip_id=t.id JOIN users u ON u.id=m.user_id
   WHERE t.id=:trip AND t.archived_at IS NULL AND m.user_id=:user AND m.status='ACTIVE' AND u.status='ACTIVE'
   """,args("trip",trip,"user",user))==1;
 }
}
