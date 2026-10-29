package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import vn.gomate.common.ApiException;
import vn.gomate.notification.repository.NotificationRepository;
import vn.gomate.trip.service.TripService;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TripInvitationInboxApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired TripService trips;
 @Autowired Db db;
 @MockitoSpyBean NotificationRepository notifications;

 @AfterEach void cleanup() {
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 @Test void inboxIsOwnedReadIsNotAcceptAndRepeatAcceptDoesNotDuplicate() throws Exception {
  var a=user(); var b=user(); var stranger=user();
  var trip=create(a,List.of(b.id()));
  String tripId=trip.get("id").asText();
  var item=inbox(b).get(0);
  String notificationId=item.get("id").asText();
  String invitationId=item.get("invitationId").asText();
  assertNotEquals(notificationId,invitationId);
  assertNotEquals(tripId,notificationId);
  assertEquals("PENDING",item.get("invitationStatus").asText());
  assertFalse(item.get("isRead").asBoolean());
  assertEquals(0,inbox(stranger).size());
  call(get("/api/v1/notifications/"+notificationId),stranger,null,404);
  call(patch("/api/v1/notifications/"+notificationId+"/read"),stranger,null,404);
  call(post("/api/v1/trip-invitations/"+invitationId+"/accept"),stranger,null,403);

  var read=call(patch("/api/v1/notifications/"+notificationId+"/read"),b,null,200);
  assertTrue(read.get("isRead").asBoolean());
  assertEquals("PENDING",read.get("invitationStatus").asText());
  call(get("/api/v1/trips/"+tripId),b,null,404);
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id",args("id",UUID.fromString(tripId))));

  var accepted=call(post("/api/v1/trip-invitations/"+invitationId+"/accept"),b,null,200);
  var again=call(post("/api/v1/trip-invitations/"+invitationId+"/accept"),b,null,200);
  assertEquals(accepted.get("linkedConversationId"),again.get("linkedConversationId"));
  assertEquals("ACCEPTED",inbox(b).get(0).get("invitationStatus").asText());
  var aInbox=inbox(a);
  assertEquals(1,aInbox.size());
  assertEquals("TRIP_INVITATION_ACCEPTED",aInbox.get(0).get("type").asText());
  assertEquals(b.id().toString(),aInbox.get(0).get("actorId").asText());
  call(get("/api/v1/trips/"+tripId),b,null,200);
  var summary=call(get("/api/v1/trips"),b,null,200).get(0);
  assertEquals("MEMBER",summary.get("currentUserRole").asText());
 }

 @Test void invalidCreateOrBulkInviteRollsBackEveryDurableRecord() throws Exception {
  var a=user(); var b=user();
  var before=db.count("SELECT COUNT(*) FROM trips",Map.of());
  call(post("/api/v1/trips"),a,Map.of("title","Invalid batch","startDate","2026-12-01","endDate","2026-12-02",
   "selectedMemberIds",List.of(b.id().toString(),UUID.randomUUID().toString())),404);
  assertEquals(before,db.count("SELECT COUNT(*) FROM trips",Map.of()));
  assertEquals(0,inbox(b).size());
  var trip=create(a,List.of());
  String tripId=trip.get("id").asText();
  call(post("/api/v1/trips/"+tripId+"/members"),a,Map.of("selectedMemberIds",List.of(b.id().toString(),UUID.randomUUID().toString())),404);
  assertEquals(0,inbox(b).size());
  assertEquals(0,db.count("SELECT COUNT(*) FROM trip_invitations WHERE trip_id=:id",args("id",UUID.fromString(tripId))));
 }

 @Test void notificationFailureRollsBackAcceptMembershipChatAndStatus() throws Exception {
  var a=user(); var b=user();
  var trip=create(a,List.of(b.id()));
  UUID tripId=UUID.fromString(trip.get("id").asText());
  UUID invitationId=UUID.fromString(inbox(b).get(0).get("invitationId").asText());
  doThrow(new IllegalStateException("simulated inbox failure")).when(notifications)
   .insertTripInvitation(eq(a.id()),eq(b.id()),eq(invitationId),eq(true));
  assertThrows(IllegalStateException.class,() -> trips.acceptInvitation(b.id(),invitationId));
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:id",args("id",tripId)));
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id",args("id",tripId)));
  assertEquals("PERSONAL",db.one("SELECT trip_type FROM trips WHERE id=:id",args("id",tripId)).get("tripType"));
  assertEquals("PENDING",inbox(b).get(0).get("invitationStatus").asText());
  assertEquals(0,inbox(a).size());
 }

 @Test void concurrentAcceptsShareExactlyOneConversation() throws Exception {
  var a=user(); var b=user(); var c=user();
  var trip=create(a,List.of(b.id(),c.id()));
  UUID tripId=UUID.fromString(trip.get("id").asText());
  UUID bInvite=UUID.fromString(inbox(b).get(0).get("invitationId").asText());
  UUID cInvite=UUID.fromString(inbox(c).get(0).get("invitationId").asText());
  var pool=Executors.newFixedThreadPool(2);
  try {
   var first=pool.submit(() -> trips.acceptInvitation(b.id(),bInvite));
   var second=pool.submit(() -> trips.acceptInvitation(c.id(),cInvite));
   assertEquals(first.get(15,TimeUnit.SECONDS).linkedConversationId(),second.get(15,TimeUnit.SECONDS).linkedConversationId());
  } finally { pool.shutdownNow(); }
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id",args("id",tripId)));
  assertEquals(3,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:id",args("id",tripId)));
  assertEquals(3,db.count("SELECT COUNT(*) FROM conversation_members cm JOIN conversations c ON c.id=cm.conversation_id WHERE c.linked_trip_id=:id",args("id",tripId)));
 }

 @Test void removedTripLeavesUnavailableInboxEntryWithoutAcceptActionState() throws Exception {
  var a=user(); var b=user();
  var trip=create(a,List.of(b.id()));
  var item=inbox(b).get(0);
  call(delete("/api/v1/trips/"+trip.get("id").asText()),a,null,204);
  var refreshed=call(get("/api/v1/notifications/"+item.get("id").asText()),b,null,200);
  assertEquals("CANCELLED",refreshed.get("invitationStatus").asText());
  assertTrue(refreshed.get("tripId").isNull());
  call(post("/api/v1/trip-invitations/"+item.get("invitationId").asText()+"/accept"),b,null,409);
 }

 @Test void leaderCancelsPendingInvitationWithoutRemovingHistoryAndCanReinvite() throws Exception {
  var a=user(); var b=user(); var stranger=user();
  var trip=create(a,List.of(b.id()));
  String tripId=trip.get("id").asText();
  var item=inbox(b).get(0);
  String invitationId=item.get("invitationId").asText();
  String url="/api/v1/trips/"+tripId+"/invitations/"+invitationId;
  call(delete(url),stranger,null,404);
  call(delete(url),b,null,404);
  call(delete("/api/v1/trips/"+create(a,List.of()).get("id").asText()+"/invitations/"+invitationId),a,null,404);
  var cancelled=call(delete(url),a,null,200);
  assertEquals(0,cancelled.get("pendingInvitations").size());
  assertEquals("PERSONAL",cancelled.get("tripType").asText());
  assertEquals(1,cancelled.get("members").size());
  call(delete(url),a,null,200);
  var notification=call(get("/api/v1/notifications/"+item.get("id").asText()),b,null,200);
  assertEquals("CANCELLED",notification.get("invitationStatus").asText());
  assertEquals(0,call(get("/api/v1/trip-invitations/incoming"),b,null,200).size());
  assertEquals(1,call(get("/api/v1/trip-invitations/incoming?status=CANCELLED"),b,null,200).size());
  call(post("/api/v1/trip-invitations/"+invitationId+"/accept"),b,null,409);
  call(post("/api/v1/trip-invitations/"+invitationId+"/decline"),b,null,409);
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id",args("id",UUID.fromString(tripId))));
  assertNull(db.one("SELECT responded_at FROM trip_invitations WHERE id=:id",args("id",UUID.fromString(invitationId))).get("respondedAt"));
  var again=call(post("/api/v1/trips/"+tripId+"/invitations"),a,Map.of("inviteeUserId",b.id()),201);
  assertNotEquals(invitationId,again.get("invitationId").asText());
  // Retrying cancellation of the old ID must not cancel the new invitation.
  call(delete(url),a,null,200);
  assertEquals(1,call(get("/api/v1/trip-invitations/incoming"),b,null,200).size());
 }

 @Test void acceptedOrDeclinedInvitationCannotBeCancelledAndMemberCannotCancelOthers() throws Exception {
  var a=user(); var b=user(); var c=user();
  var trip=create(a,List.of(b.id(),c.id()));
  String tripId=trip.get("id").asText();
  String bInvite=inbox(b).get(0).get("invitationId").asText();
  String cInvite=inbox(c).get(0).get("invitationId").asText();
  var accepted=call(post("/api/v1/trip-invitations/"+bInvite+"/accept"),b,null,200);
  call(delete("/api/v1/trips/"+tripId+"/invitations/"+bInvite),a,null,409);
  call(delete("/api/v1/trips/"+tripId+"/invitations/"+cInvite),b,null,403);
  var cancelled=call(delete("/api/v1/trips/"+tripId+"/invitations/"+cInvite),a,null,200);
  assertEquals(accepted.get("linkedConversationId"),cancelled.get("linkedConversationId"));
  assertEquals(2,cancelled.get("members").size());
  assertEquals("GROUP",cancelled.get("tripType").asText());
  var reinvite=call(post("/api/v1/trips/"+tripId+"/invitations"),a,Map.of("inviteeUserId",c.id()),201);
  String newId=reinvite.get("invitationId").asText();
  call(post("/api/v1/trip-invitations/"+newId+"/decline"),c,null,200);
  call(delete("/api/v1/trips/"+tripId+"/invitations/"+newId),a,null,409);
 }

 @Test void concurrentAcceptAndCancelHaveOneWinnerWithoutPartialMembership() throws Exception {
  var a=user(); var b=user();
  UUID tripId=UUID.fromString(create(a,List.of(b.id())).get("id").asText());
  UUID invitationId=UUID.fromString(inbox(b).get(0).get("invitationId").asText());
  var pool=Executors.newFixedThreadPool(2);
  var start=new CountDownLatch(1);
  try {
   var accept=pool.submit(() -> { start.await(); try { trips.acceptInvitation(b.id(),invitationId); return 200; } catch(ApiException e) { return e.status; } });
   var cancel=pool.submit(() -> { start.await(); try { trips.cancelInvitation(a.id(),tripId,invitationId); return 200; } catch(ApiException e) { return e.status; } });
   start.countDown();
   var statuses=List.of(accept.get(15,TimeUnit.SECONDS),cancel.get(15,TimeUnit.SECONDS));
   assertEquals(1,statuses.stream().filter(s -> s==200).count());
   assertEquals(1,statuses.stream().filter(s -> s==409).count());
  } finally { pool.shutdownNow(); }
  String status=(String)db.one("SELECT status FROM trip_invitations WHERE id=:id",args("id",invitationId)).get("status");
  boolean accepted="ACCEPTED".equals(status);
  assertTrue(accepted || "CANCELLED".equals(status));
  assertEquals(accepted?2:1,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:id",args("id",tripId)));
  assertEquals(accepted?1:0,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id",args("id",tripId)));
  assertEquals(accepted?1:0,inbox(a).size());
 }

 private JsonNode create(User actor,List<UUID> invitees) throws Exception {
  return call(post("/api/v1/trips"),actor,Map.of("title","Inbox integration","startDate","2026-12-01","endDate","2026-12-02",
   "selectedMemberIds",invitees.stream().map(UUID::toString).toList()),201);
 }
 private JsonNode inbox(User user) throws Exception { return call(get("/api/v1/notifications"),user,null,200).get("items"); }
 private JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,User user,Object body,int expected) throws Exception {
  req.header("Authorization",user.token());
  if(body!=null) req.contentType("application/json").content(json.writeValueAsBytes(body));
  byte[] bytes=mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse().getContentAsByteArray();
  return bytes.length==0?json.createObjectNode():json.readTree(bytes);
 }
 private User user() {
  String suffix=UUID.randomUUID().toString().replace("-","");
  var session=auth.register(new AuthDtos.Register("inbox-"+suffix+"@example.com","TestPass123!","inbox_"+suffix.substring(0,8)));
  return new User((UUID)((Map<?,?>)session.get("user")).get("id"),"Bearer "+session.get("accessToken"));
 }
 private record User(UUID id,String token) {}
}
