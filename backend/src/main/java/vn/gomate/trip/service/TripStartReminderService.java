package vn.gomate.trip.service;

import java.time.*;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.trip.repository.*;
import vn.gomate.notification.service.NotificationService;

@Service
public class TripStartReminderService {
 private final TripRepository trips;
 private final TripReminderRepository reminders;
 private final TripPlanningTime time;
 private final NotificationService notifications;
 public TripStartReminderService(TripRepository trips,TripReminderRepository reminders,TripPlanningTime time,NotificationService notifications) {
  this.trips=trips; this.reminders=reminders; this.time=time; this.notifications=notifications;
 }
 // Caller holds the Trip lock, before reminder rows. All lifecycle writers use this order.
 public void sync(UUID tripId) { sync(tripId,null); }
 public void syncMember(UUID tripId,UUID userId) { sync(tripId,userId); }
 private void sync(UUID tripId,UUID onlyUser) {
  var trip=trips.tripForUpdate(tripId).orElseThrow();
  reminders.cancel(tripId,onlyUser);
  if(trip.get("archivedAt")!=null) return;
  LocalDate start=(LocalDate)trip.get("startDate");
  String timezone=(String)trip.get("timezone");
  ZoneId zone=time.zone(timezone);
  Instant now=time.now();
  for(var member:trips.activeTripMembers(tripId)) {
   UUID user=(UUID)member.get("userId");
   if(onlyUser!=null && !onlyUser.equals(user)) continue;
   if(!reminders.eligible(tripId,user)) continue;
   for(int days:new int[]{2,1}) {
    Instant due=time.remindAt(start,days,timezone);
    if(due!=null && due.isAfter(now) && !reminders.sentOnDate(tripId,user,start.minusDays(days),zone))
     reminders.schedule(tripId,user,days,start,zone.getId(),due);
   }
  }
 }
 public void cancel(UUID tripId,UUID userId) { reminders.cancel(tripId,userId); }
 public List<Map<String,Object>> due() { return reminders.due(time.now()); }

 @Transactional
 public void fire(UUID id,UUID tripId) {
  var trip=trips.tripForUpdate(tripId).orElseThrow();
  var reminder=reminders.lock(id);
  if(!"PENDING".equals(reminder.get("status"))) return;
  Instant now=time.now();
  if(instant(reminder.get("remindAt")).isAfter(now)) return;
  UUID user=(UUID)reminder.get("recipientUserId");
  LocalDate start=(LocalDate)trip.get("startDate");
  ZoneId zone=time.zone((String)trip.get("timezone"));
  LocalDate date=(LocalDate)reminder.get("reminderDate");
  Integer days=reminder.get("daysBefore")==null?null:((Number)reminder.get("daysBefore")).intValue();
  Instant expected=days==null?null:time.remindAt(start,days,zone.getId());
  if(expected==null || !start.equals(reminder.get("tripStartDate"))
    || !start.minusDays(days).equals(date)
    || !zone.getId().equals(reminder.get("reminderTimezone"))
    || !expected.equals(instant(reminder.get("remindAt")))
    || !LocalDate.ofInstant(now,zone).equals(date)
    || reminders.sentOnDate(tripId,user,date,zone) || !reminders.eligible(tripId,user)) {
   reminders.cancelId(id); return;
  }
  notifications.recordTripDateReminder(user,id,(String)trip.get("title"),days,start);
  reminders.sent(id,now);
 }
 public static Instant instant(Object value) {
  if(value instanceof OffsetDateTime t) return t.toInstant();
  if(value instanceof Instant t) return t;
  return ((LocalDateTime)value).toInstant(ZoneOffset.UTC);
 }
}
