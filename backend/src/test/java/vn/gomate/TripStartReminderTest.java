package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.*;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import vn.gomate.trip.service.*;
import vn.gomate.notification.push.NotificationPushDelivery;
import vn.gomate.notification.realtime.NotificationStreamHub;
import vn.gomate.location.repository.TripLocationMongoRepository;
import vn.gomate.message.service.MessageMongoService;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class TripStartReminderTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired Db db;
 @Autowired AuthService auth;
 @Autowired TripPlanningTime time;
 @Autowired TripStartReminderService reminders;
 @Autowired TripTestClockConfiguration.PlanningClock clock;
 @Autowired PlatformTransactionManager transactions;
 @MockitoBean MessageMongoService messages;
 @MockitoBean TripLocationMongoRepository locations;
 @MockitoBean NotificationPushDelivery push;
 @MockitoSpyBean NotificationStreamHub streams;
 @BeforeEach void setup() { clock.at("2026-10-25T03:00:00Z"); }
 @AfterEach void cleanup() {
  clock.reset(); reset(streams);
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }
 @Test void dateOnlyCreatesExactLocalTwentySlotsAndNoStartDayNotification() throws Exception {
  var a=user(); var t=create(a,"2026-10-28");
  assertFalse(t.has("plannedStartTime"));
  assertEquals(t,call(get(path(t)),a,null,200));
  var rows=db.list("SELECT * FROM trip_reminders WHERE trip_id=:t ORDER BY remind_at",args("t",uuid(t)));
  assertEquals(2,rows.size());
  for(int i=0;i<2;i++) {
   var row=rows.get(i);
   assertEquals(2-i,((Number)row.get("daysBefore")).intValue());
   assertEquals(LocalDate.of(2026,10,26+i),row.get("reminderDate"));
   assertEquals(Instant.parse("2026-10-"+(26+i)+"T13:00:00Z"),TripStartReminderService.instant(row.get("remindAt")));
   assertNull(row.get("offsetMinutes")); assertNull(row.get("plannedStartAt"));
  }
  clock.at("2026-10-26T12:59:59Z"); fireAll(); assertEquals(0,inbox());
  clock.at("2026-10-26T13:00:00Z"); fireAll(); assertEquals(1,inbox());
  var first=call(get("/api/v1/notifications"),a,null,200).path("items").get(0);
  assertEquals(2,first.path("reminderDaysBefore").asInt());
  assertEquals("2026-10-28",first.path("tripStartDate").asText());
  assertTrue(first.path("message").asText().contains("28/10/2026"));
  assertFalse(first.path("message").asText().contains("phút"));
  clock.at("2026-10-27T13:00:00Z"); fireAll(); fireAll(); assertEquals(2,inbox());
  clock.at("2026-10-28T13:00:00Z"); fireAll(); assertEquals(2,inbox());
 }
 @ParameterizedTest @ValueSource(strings={"plannedStartTime","clearStartTime"})
 void removedHourFieldsRejectedWithoutChangingStoredLegacyHour(String field) throws Exception {
  var a=user(); var body=body("2026-10-28"); body.put(field,field.equals("clearStartTime")?true:"08:00");
  call(post("/api/v1/trips"),a,body,400);
  var t=create(a,"2026-10-28");
  db.update("UPDATE trips SET planned_start_time='08:15' WHERE id=:id",args("id",uuid(t)));
  call(patch(path(t)),a,Map.of(field,body.get(field)),400);
  call(patch(path(t)),a,Map.of("title","Renamed date trip"),200);
  assertNotNull(db.one("SELECT planned_start_time FROM trips WHERE id=:id",args("id",uuid(t))).get("plannedStartTime"));
 }
 @Test void dateGuardsHistoricalEditAndNamedTimezoneArePreserved() throws Exception {
  var a=user();call(post("/api/v1/trips"),a,body("2026-10-24"),400);
  var body=body("2026-10-28");body.put("endDate","2026-10-27");call(post("/api/v1/trips"),a,body,400);
  body=body("2026-10-28");body.put("timezone","not/a-zone");call(post("/api/v1/trips"),a,body,400);
  var t=create(a,"2026-10-25");assertEquals(0,pending(uuid(t)));
  db.update("UPDATE trips SET start_date='2020-01-01',end_date='2020-01-02' WHERE id=:id",args("id",uuid(t)));
  call(patch(path(t)),a,Map.of("title","Historical metadata still editable"),200);
  call(patch(path(t)),a,Map.of("startDate","2020-01-01","endDate","2020-01-02"),200);
  var context=call(get("/api/v1/trips/time-context?timezone=America/New_York"),a,null,200);
  assertEquals("2026-10-24",context.path("today").asText());
 }
 @ParameterizedTest @ValueSource(strings={"2026-10-26T13:00:00Z","2026-10-26T14:00:00Z","2026-10-27T12:59:59Z"})
 void createAfterFirstDeadlineSchedulesOnlyFutureD1(String now) throws Exception {
  clock.at(now);var t=create(user(),"2026-10-28");assertEquals(1,pending(uuid(t)));
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_reminders WHERE trip_id=:t AND days_before=1",args("t",uuid(t))));
 }
 @Test void createAfterBothDeadlinesDoesNotCatchUp() throws Exception {
  clock.at("2026-10-27T13:00:01Z");var t=create(user(),"2026-10-28");assertEquals(0,pending(uuid(t)));fireAll();assertEquals(0,inbox());
 }
 @Test void downtimeCancelsYesterdayButDeliversOnlyTodaysSlotAndSurvivesRepeatedWorkers() throws Exception {
  var t=create(user(),"2026-10-28");
  clock.at("2026-10-27T14:00:00Z");fireAll();fireAll();
  assertEquals(1,inbox());assertEquals(1,statusCount(uuid(t),"SENT"));assertEquals(1,statusCount(uuid(t),"CANCELLED"));
 }
 @Test void sameDateLateDeliveryAllowedButMidnightAndStartDayAreNot() throws Exception {
  create(user(),"2026-10-28");clock.at("2026-10-26T16:59:59Z");fireAll();assertEquals(1,inbox());
  clock.at("2026-10-27T17:00:00Z");fireAll();assertEquals(1,inbox());
 }
 @Test void pendingMemberExcludedLateAcceptGetsOnlyD1AndMemberCannotEdit() throws Exception {
  var a=user();var b=user();var c=user();var draft=body("2026-10-28");draft.put("selectedMemberIds",List.of(b.id,c.id));
  var t=call(post("/api/v1/trips"),a,draft,201);assertEquals(2,pending(uuid(t)));
  call(patch(path(t)),b,Map.of("startDate","2026-10-29"),404);
  for(var invite:t.path("pendingInvitations"))if(invite.path("inviteeUserId").asText().equals(c.id.toString()))
   call(post("/api/v1/trip-invitations/"+invite.path("invitationId").asText()+"/decline"),c,null,200);
  clock.at("2026-10-26T13:01:00Z"); accept(t,b);
  call(patch(path(t)),b,Map.of("title","Not permitted"),403);
  fireAll();assertEquals(1,inbox());
  assertEquals(0,db.count("SELECT COUNT(*) FROM notifications WHERE type='TRIP_START_REMINDER' AND user_id=:id",args("id",b.id)));
  clock.at("2026-10-27T13:00:00Z");fireAll();assertEquals(3,inbox());
  assertEquals(0,db.count("SELECT COUNT(*) FROM trip_reminders WHERE recipient_user_id=:id",args("id",c.id)));
 }
 @ParameterizedTest @ValueSource(strings={"leave","remove","archive"})
 void lifecycleRevokesUnsentAndHistoricalNotificationTarget(String mode) throws Exception {
  var a=user();var b=user();var t=group(a,b);clock.at("2026-10-26T13:00:00Z");fireAll();assertEquals(2,inbox());
  switch(mode) {
   case "leave" -> call(delete(path(t)+"/members/me"),b,null,204);
   case "remove" -> call(delete(path(t)+"/members/"+b.id),a,null,200);
   default -> call(delete(path(t)),a,null,204);
  }
  clock.at("2026-10-27T13:00:00Z");fireAll();assertEquals(mode.equals("archive")?2:3,inbox());
  var notices=call(get("/api/v1/notifications"),b,null,200).path("items");
  for(var n:notices) if(n.path("type").asText().equals("TRIP_START_REMINDER"))assertTrue(n.path("tripId").isNull());
 }
 @Test void pinViewUnpinSwitchAndLeadershipNeverSuppressD1() throws Exception {
  var a=user();var b=user();var t=group(a,b);clock.at("2026-10-26T13:00:00Z");fireAll();assertEquals(2,inbox());
  call(post(path(t)+"/pin"),a,null,200);call(get(path(t)),b,null,200);
  call(get("/api/v1/notifications"),a,null,200);
  call(delete(path(t)+"/pin"),a,null,204);
  var other=create(b,"2026-10-30");call(post(path(other)+"/pin"),b,null,200);
  call(patch(path(t)+"/leader"),a,Map.of("targetUserId",b.id),200);
  clock.at("2026-10-27T13:00:00Z");fireAll();assertEquals(4,inbox());
  assertEquals(other.path("id"),call(get("/api/v1/trips/pinned"),b,null,200).path("trip").path("id"));
 }
 @Test void dateAndZoneEditPreserveSentBodyAndAvoidSameLocalDayRepeat() throws Exception {
  var a=user();var t=create(a,"2026-10-28");clock.at("2026-10-26T13:00:00Z");fireAll();
  var notice=db.one("SELECT id,body FROM notifications WHERE type='TRIP_START_REMINDER'",Map.of());
  call(patch(path(t)),a,Map.of("startDate","2026-10-27","endDate","2026-10-27","title","New title"),200);
  fireAll();assertEquals(1,inbox());
  // A zone change could put another 20:00 later on the same local calendar date.
  call(patch(path(t)),a,Map.of("timezone","America/New_York"),200);
  clock.at("2026-10-27T00:01:00Z");fireAll();assertEquals(1,inbox());
  call(patch(path(t)),a,Map.of("startDate","2026-10-30","endDate","2026-10-30"),200);
  clock.at("2026-10-29T00:00:00Z");fireAll();assertEquals(2,inbox());
  assertEquals(notice.get("body"),db.one("SELECT body FROM notifications WHERE id=:id",args("id",notice.get("id"))).get("body"));
 }
 @Test void duplicateWorkersAndTransportFailureStillCommitOneNotice() throws Exception {
  var a=user();var t=create(a,"2026-10-28");clock.at("2026-10-26T13:00:00Z");
  doThrow(new IllegalStateException("test push outage")).when(push).enqueue(any(),any());
  var candidates=reminders.due();var pool=Executors.newFixedThreadPool(2);
  try { var jobs=new ArrayList<Future<?>>();for(int i=0;i<2;i++)jobs.add(pool.submit(() -> candidates.forEach(r -> reminders.fire((UUID)r.get("id"),(UUID)r.get("tripId")))));for(var j:jobs)j.get(20,TimeUnit.SECONDS); }
  finally { pool.shutdownNow(); }
  assertEquals(1,inbox());assertEquals(1,statusCount(uuid(t),"SENT"));
 }
 @Test void rollbackDoesNotPublishOrMarkSentAndLockedAccountIsRechecked() throws Exception {
  var a=user();var t=create(a,"2026-10-28");clock.at("2026-10-26T13:00:00Z");clearInvocations(streams,push);
  new TransactionTemplate(transactions).executeWithoutResult(s -> { fireAll();assertEquals(1,inbox());verify(streams,never()).publish(any(),any());verify(push,never()).enqueue(any(),any());s.setRollbackOnly(); });
  assertEquals(0,inbox());assertEquals(2,pending(uuid(t)));
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",a.id));fireAll();assertEquals(0,inbox());
 }
 @ParameterizedTest @ValueSource(strings={"edit","remove","archive"})
 void lifecycleAndSchedulerRaceSerializeOnTrip(String mode) throws Exception {
  var a=user();var b=user();var t=group(a,b);clock.at("2026-10-26T13:00:00Z");
  var candidate=db.one("SELECT id,trip_id FROM trip_reminders WHERE trip_id=:t AND recipient_user_id=:u AND days_before=2",args("t",uuid(t),"u",b.id));
  var pool=Executors.newFixedThreadPool(2);var gate=new CountDownLatch(1);
  try {
   var fire=pool.submit(() -> {gate.await();reminders.fire((UUID)candidate.get("id"),uuid(t));return true;});
   var change=pool.submit(() -> {gate.await();return switch(mode) {
    case "edit" -> call(patch(path(t)),a,Map.of("startDate","2026-10-29","endDate","2026-10-29"),200);
    case "remove" -> call(delete(path(t)+"/members/"+b.id),a,null,200);
    default -> call(delete(path(t)),a,null,204);
   };});gate.countDown();fire.get(20,TimeUnit.SECONDS);change.get(20,TimeUnit.SECONDS);
  } finally {pool.shutdownNow();}
  var sent=inbox();assertTrue(sent<=1);reminders.fire((UUID)candidate.get("id"),uuid(t));assertEquals(sent,inbox());
 }
 @Test void calendarTimezoneDstAndUtcMidnightAreNotFixedFortyEightHours() {
  assertEquals(Instant.parse("2026-11-01T00:00:00Z"),time.remindAt(LocalDate.of(2026,11,2),2,"America/New_York"));
  assertEquals(Instant.parse("2026-11-02T01:00:00Z"),time.remindAt(LocalDate.of(2026,11,2),1,"America/New_York"));
  assertEquals(Instant.parse("2026-10-26T07:00:00Z"),time.remindAt(LocalDate.of(2026,10,28),2,"Pacific/Auckland"));
  assertEquals(Instant.parse("2026-10-27T03:00:00Z"),time.remindAt(LocalDate.of(2026,10,28),2,"America/Los_Angeles"));
 }
 @Test void legacyMinuteRowsAreNeverSelectedByTheNewScheduler() throws Exception {
  var a=user();var t=create(a,"2026-10-28");var old=UUID.randomUUID();
  db.update("INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,offset_minutes,planned_start_at,remind_at) VALUES(:id,:t,:u,'TRIP_START',60,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",args("id",old,"t",uuid(t),"u",a.id));
  assertTrue(reminders.due().isEmpty());
  clock.at("2026-10-26T13:00:00Z");fireAll();assertEquals(1,inbox());
  assertEquals(0,db.count("SELECT COUNT(*) FROM notifications WHERE entity_id=:id",args("id",old.toString())));
 }
 private JsonNode create(User user,String date) throws Exception { return call(post("/api/v1/trips"),user,body(date),201); }
 private JsonNode group(User a,User b) throws Exception {var draft=body("2026-10-28");draft.put("selectedMemberIds",List.of(b.id));var t=call(post("/api/v1/trips"),a,draft,201);accept(t,b);return t;}
 private void accept(JsonNode t,User b) throws Exception {for(var invite:t.path("pendingInvitations"))if(invite.path("inviteeUserId").asText().equals(b.id.toString()))call(post("/api/v1/trip-invitations/"+invite.path("invitationId").asText()+"/accept"),b,null,200);}
 private void fireAll() {for(var r:reminders.due())reminders.fire((UUID)r.get("id"),(UUID)r.get("tripId"));}
 private long inbox() {return db.count("SELECT COUNT(*) FROM notifications WHERE type='TRIP_START_REMINDER'",Map.of());}
 private long pending(UUID t) {return statusCount(t,"PENDING");}
 private long statusCount(UUID t,String status) {return db.count("SELECT COUNT(*) FROM trip_reminders WHERE trip_id=:t AND status=:s",args("t",t,"s",status));}
 private UUID uuid(JsonNode t) {return UUID.fromString(t.path("id").asText());}
 private String path(JsonNode t) {return "/api/v1/trips/"+t.path("id").asText();}
 private Map<String,Object> body(String date) {var b=new HashMap<String,Object>();b.put("title","Date reminder fixture");b.put("startDate",date);b.put("endDate",date);b.put("timezone","Asia/Ho_Chi_Minh");return b;}
 private User user() {String key=UUID.randomUUID().toString().replace("-","");var s=auth.register(new AuthDtos.Register(key+"@example.invalid","TestPass123!","r_"+key.substring(0,12)));return new User((UUID)((Map<?,?>)s.get("user")).get("id"),"Bearer "+s.get("accessToken"));}
 private JsonNode call(MockHttpServletRequestBuilder request,User user,Object body,int code) throws Exception {request.header("Authorization",user.token);if(body!=null)request.contentType("application/json").content(json.writeValueAsBytes(body));var r=mvc.perform(request).andExpect(status().is(code)).andReturn().getResponse();return r.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(r.getContentAsByteArray());}
 private record User(UUID id,String token) {}
}
