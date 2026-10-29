package vn.gomate;

import com.fasterxml.jackson.databind.*;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import vn.gomate.location.repository.TripLocationMongoRepository;
import vn.gomate.message.repository.ConversationRepository;
import vn.gomate.message.service.MessageMongoService;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class TripLeaderLifecycleTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @MockitoBean MessageMongoService messages;
 @MockitoBean TripLocationMongoRepository locations;
 @MockitoSpyBean ConversationRepository conversations;

 @BeforeEach void setup() { when(messages.list(any(),anyInt(),any())).thenReturn(List.of()); }
 @AfterEach void cleanup() {
  reset(conversations);
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 @Test void L01to08_transferChangesBothRolesButKeepsChatAndDoesNotLeave() throws Exception {
  var a=user(); var b=user(); var outsider=user(); var pending=user(); var former=user();
  var trip=group(a,b); String id=trip.path("id").asText(); String chat=trip.path("linkedConversationId").asText();
  String url="/api/v1/trips/"+id;
  join(a,former,id);
  call(delete(url+"/members/me"),former,null,204);
  String pendingId=invite(a,pending,id);
  call(patch(url+"/leader"),b,Map.of("targetUserId",a.id),403);
  call(patch(url+"/leader"),outsider,Map.of("targetUserId",b.id),404);
  for(var invalid:List.of(a,pending,former,outsider)) call(patch(url+"/leader"),a,Map.of("targetUserId",invalid.id),422);
  call(delete(url+"/invitations/"+pendingId),a,null,200);
  call(patch(url+"/leader"),a,Map.of("targetUserId",pending.id),422);
  String declinedId=invite(a,pending,id);
  call(post("/api/v1/trip-invitations/"+declinedId+"/decline"),pending,null,200);
  call(patch(url+"/leader"),a,Map.of("targetUserId",pending.id),422);
  call(patch(url+"/leader"),a,Map.of(),400);
  call(delete(url+"/members/me"),a,null,422);
  var next=call(patch(url+"/leader"),a,Map.of("targetUserId",b.id),200);
  assertEquals(chat,next.path("linkedConversationId").asText());
  assertEquals(2,next.path("memberCount").asInt());
  assertRole(id,a,"MEMBER"); assertRole(id,b,"LEADER"); assertOneLeader(id);
  assertEquals("MEMBER",chatRole(chat,a)); assertEquals("LEADER",chatRole(chat,b));
  call(patch(url),a,Map.of("title","Denied after transfer"),403);
  call(patch(url),b,Map.of("title","New leader"),200);
  call(delete(url+"/members/me"),b,null,422);
  call(delete(url+"/members/me"),a,null,204);
  var personal=call(get(url),b,null,200);
  assertEquals("PERSONAL",personal.path("tripType").asText());
  assertEquals("CLOSED",chatStatus(chat)); assertOneLeader(id);
  var c=user(); var invitation=invite(b,c,id);
  var regroup=call(post("/api/v1/trip-invitations/"+invitation+"/accept"),c,null,200);
  assertNotEquals(chat,regroup.path("linkedConversationId").asText());
 }

 @Test void L09to21_archivePreservesHistoryClosesAuthorityAndIsIdempotent() throws Exception {
  var a=user(); var b=user(); var c=user(); var outsider=user();
  var trip=group(a,b); String id=trip.path("id").asText(); String chat=trip.path("linkedConversationId").asText();
  String url="/api/v1/trips/"+id; UUID tripId=UUID.fromString(id);
  String pending=invite(a,c,id);
  var accepted=db.one("SELECT id FROM trip_invitations WHERE trip_id=:id AND status='ACCEPTED'",args("id",tripId)).get("id");
  call(post(url+"/pin"),a,null,200); call(post(url+"/pin"),b,null,200);
  long history=count("trip_invitations",id); long inbox=db.count("SELECT COUNT(*) FROM notifications",Map.of());
  call(delete(url),b,null,403); call(delete(url),outsider,null,404);
  // Cleanup is after COMMIT, and failure cannot undo relational archive.
  doAnswer(i -> {
   assertNotNull(db.one("SELECT archived_at FROM trips WHERE id=:id",args("id",tripId)).get("archivedAt"));
   throw new IllegalStateException("Mongo fixture unavailable");
  }).when(locations).deleteByTrip(tripId);
  call(delete(url),a,null,204); call(delete(url),a,null,204);
  verify(locations,times(2)).deleteByTrip(tripId);
  assertEquals(1,db.count("SELECT COUNT(*) FROM trips WHERE id=:id",args("id",tripId)));
  assertEquals(2,count("trip_members",id)); assertEquals(history,count("trip_invitations",id));
  assertEquals(inbox,db.count("SELECT COUNT(*) FROM notifications",Map.of()));
  assertEquals("CANCELLED",db.one("SELECT status FROM trip_invitations WHERE id=:id",args("id",UUID.fromString(pending))).get("status"));
  assertEquals("ACCEPTED",db.one("SELECT status FROM trip_invitations WHERE id=:id",args("id",accepted)).get("status"));
  assertEquals("CLOSED",chatStatus(chat)); assertEquals(0,count("trip_pins",id));
  assertEquals(2,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:id",args("id",UUID.fromString(chat))));
  for(var actor:List.of(a,b)) {
   assertEquals(0,call(get("/api/v1/trips"),actor,null,200).size());
   call(get(url),actor,null,404);
   assertTrue(call(get("/api/v1/trips/pinned"),actor,null,200).path("trip").isNull());
   call(post(url+"/pin"),actor,null,404);
   call(delete(url+"/members/me"),actor,null,404);
   call(get(url+"/locations"),actor,null,404);
   call(put(url+"/location"),actor,Map.of("latitude",11.9,"longitude",108.4),404);
   call(get("/api/v1/conversations/"+chat),actor,null,404);
   call(post("/api/v1/conversations/"+chat+"/messages"),actor,Map.of("text","must not save"),404);
   assertEquals(0,call(get("/api/v1/conversations"),actor,null,200).size());
  }
  verify(messages,never()).saveText(eq(UUID.fromString(chat)),any(),any(),any());
  call(patch(url),a,Map.of("title","cannot revive"),404);
  call(patch(url+"/leader"),a,Map.of("targetUserId",b.id),404);
  call(post(url+"/invitations"),a,Map.of("inviteeUserId",c.id),404);
  call(post(url+"/members"),a,Map.of("selectedMemberIds",List.of(c.id)),404);
  call(post(url+"/stops"),a,Map.of("placeId",1),404);
  call(patch(url+"/stops/reorder"),a,Map.of("stops",List.of(Map.of("stopId",UUID.randomUUID(),"dayNo",1,"orderNo",1))),404);
  call(patch(url+"/stops/"+UUID.randomUUID()),a,Map.of("note","denied"),404);
  call(delete(url+"/stops/"+UUID.randomUUID()),a,null,404);
  call(post(url+"/stops/optimize"),a,null,404);
  call(delete(url+"/members/"+b.id),a,null,404);
  call(post("/api/v1/trip-invitations/"+pending+"/accept"),c,null,409);
  call(post("/api/v1/trip-invitations/"+accepted+"/accept"),b,null,409);
  var records=call(get("/api/v1/notifications"),c,null,200).path("items");
  var notice=records.get(0);
  assertEquals("CANCELLED",notice.path("invitationStatus").asText()); assertTrue(notice.path("tripId").isNull());
  var fresh=call(get("/api/v1/notifications/"+notice.path("id").asText()),c,null,200);
  assertTrue(fresh.path("tripId").isNull());
  var acceptedNotice=call(get("/api/v1/notifications"),b,null,200).path("items").get(0);
  assertEquals("ACCEPTED",acceptedNotice.path("invitationStatus").asText());
  assertTrue(acceptedNotice.path("tripId").isNull());
 }

 @Test void soloLeaderMustArchiveInsteadOfLeave() throws Exception {
  var a=user(); var trip=create(a); String id=trip.path("id").asText();
  call(delete("/api/v1/trips/"+id+"/members/me"),a,null,422);
  call(delete("/api/v1/trips/"+id),a,null,204);
  assertEquals(1,count("trip_members",id));
 }

 @Test void failedTransferRollsBackBothTripAndChatRoles() throws Exception {
  var a=user(); var b=user(); var trip=group(a,b);
  String id=trip.path("id").asText(); String chat=trip.path("linkedConversationId").asText();
  doThrow(new IllegalStateException("fixture role failure")).when(conversations).updateMemberRole(UUID.fromString(chat),b.id,"LEADER");
  call(patch("/api/v1/trips/"+id+"/leader"),a,Map.of("targetUserId",b.id),500);
  assertRole(id,a,"LEADER"); assertRole(id,b,"MEMBER");
  assertEquals("LEADER",chatRole(chat,a)); assertEquals("MEMBER",chatRole(chat,b)); assertOneLeader(id);
 }

 @Test void failedArchiveRollsBackRelationalClosureAndNeverCleansMongo() throws Exception {
  var a=user(); var b=user(); var c=user(); var trip=group(a,b);
  String id=trip.path("id").asText(); UUID chat=UUID.fromString(trip.path("linkedConversationId").asText());
  String invite=invite(a,c,id);
  call(post("/api/v1/trips/"+id+"/pin"),a,null,200);
  doThrow(new IllegalStateException("fixture archive failure")).when(conversations).archiveGroup(chat);
  call(delete("/api/v1/trips/"+id),a,null,500);
  call(get("/api/v1/trips/"+id),a,null,200);
  assertEquals("PENDING",db.one("SELECT status FROM trip_invitations WHERE id=:id",args("id",UUID.fromString(invite))).get("status"));
  assertEquals(1,count("trip_pins",id)); assertEquals("ACCEPTED",chatStatus(chat.toString()));
  verifyNoInteractions(locations);
 }

 @ParameterizedTest @ValueSource(strings={"twoTransfers","targetLeave","targetRemove","archiveTransfer","archiveAccept","archiveInvite","archiveLeave","archiveMutation"})
 void L22_L23_racesSerializeWithoutDeadlockOrRevival(String scenario) throws Exception {
  var a=user(); var b=user(); var c=user(); var pending=user();
  var trip=group(a,b); String id=trip.path("id").asText(); join(a,c,id);
  String invitation=invite(a,pending,id); String url="/api/v1/trips/"+id;
  var start=new CountDownLatch(1); var workers=Executors.newFixedThreadPool(2);
  boolean archive=scenario.startsWith("archive");
  try {
   var first=workers.submit(() -> {
    start.await();
    return raw(archive?delete(url):patch(url+"/leader"),a,archive?null:Map.of("targetUserId",b.id));
   });
   var second=workers.submit(() -> {
    start.await();
    return switch(scenario) {
     case "twoTransfers" -> raw(patch(url+"/leader"),a,Map.of("targetUserId",c.id));
     case "targetLeave","archiveLeave" -> raw(delete(url+"/members/me"),b,null);
     case "targetRemove" -> raw(delete(url+"/members/"+b.id),a,null);
     case "archiveTransfer" -> raw(patch(url+"/leader"),a,Map.of("targetUserId",b.id));
     case "archiveAccept" -> raw(post("/api/v1/trip-invitations/"+invitation+"/accept"),pending,null);
     case "archiveInvite" -> raw(post(url+"/invitations"),a,Map.of("inviteeUserId",user().id));
     default -> raw(patch(url),a,Map.of("title","race mutation"));
    };
   });
   start.countDown();
   var codes=List.of(first.get(20,TimeUnit.SECONDS),second.get(20,TimeUnit.SECONDS));
   assertTrue(codes.stream().allMatch(code -> Set.of(200,201,204,403,404,409,422).contains(code)),codes.toString());
   assertOneLeader(id);
   var saved=db.one("SELECT archived_at FROM trips WHERE id=:id",args("id",UUID.fromString(id)));
   if(saved.get("archivedAt")!=null) {
    assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id AND status='ACCEPTED'",args("id",UUID.fromString(id))));
    assertEquals(0,db.count("SELECT COUNT(*) FROM trip_invitations WHERE trip_id=:id AND status='PENDING'",args("id",UUID.fromString(id))));
   } else {
    assertEquals(1,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id AND status='ACCEPTED'",args("id",UUID.fromString(id))));
   }
   assertEquals(0,db.count("SELECT COUNT(*) FROM conversation_members cm JOIN conversations c ON c.id=cm.conversation_id JOIN trip_members tm ON tm.trip_id=c.linked_trip_id AND tm.user_id=cm.user_id WHERE c.linked_trip_id=:id AND c.status='ACCEPTED' AND cm.role<>tm.role",args("id",UUID.fromString(id))));
  } finally { workers.shutdownNow(); }
 }

 private void assertOneLeader(String id) { assertEquals(1,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:id AND role='LEADER' AND status='ACTIVE'",args("id",UUID.fromString(id)))); }
 private void assertRole(String id,User user,String role) { assertEquals(role,db.one("SELECT role FROM trip_members WHERE trip_id=:id AND user_id=:user",args("id",UUID.fromString(id),"user",user.id)).get("role")); }
 private String chatRole(String id,User user) { return (String)db.one("SELECT role FROM conversation_members WHERE conversation_id=:id AND user_id=:user",args("id",UUID.fromString(id),"user",user.id)).get("role"); }
 private String chatStatus(String id) { return (String)db.one("SELECT status FROM conversations WHERE id=:id",args("id",UUID.fromString(id))).get("status"); }
 private long count(String table,String id) { return db.count("SELECT COUNT(*) FROM "+table+" WHERE trip_id=:id",args("id",UUID.fromString(id))); }
 private JsonNode create(User a) throws Exception { return call(post("/api/v1/trips"),a,Map.of("title","Leader lifecycle fixture","startDate","2026-12-01","endDate","2026-12-02"),201); }
 private String invite(User a,User b,String id) throws Exception { return call(post("/api/v1/trips/"+id+"/invitations"),a,Map.of("inviteeUserId",b.id),201).path("invitationId").asText(); }
 private JsonNode join(User a,User b,String id) throws Exception { return call(post("/api/v1/trip-invitations/"+invite(a,b,id)+"/accept"),b,null,200); }
 private JsonNode group(User a,User b) throws Exception { return join(a,b,create(a).path("id").asText()); }
 private User user() {
  String suffix=UUID.randomUUID().toString().replace("-","");
  var session=auth.register(new AuthDtos.Register(suffix+"@example.invalid","TestPass123!","ll_"+suffix.substring(0,12)));
  return new User((UUID)((Map<?,?>)session.get("user")).get("id"),"Bearer "+session.get("accessToken"));
 }
 private int raw(MockHttpServletRequestBuilder req,User user,Object body) throws Exception {
  req.header("Authorization",user.token);
  if(body!=null) req.contentType("application/json").content(json.writeValueAsBytes(body));
  return mvc.perform(req).andReturn().getResponse().getStatus();
 }
 private JsonNode call(MockHttpServletRequestBuilder req,User user,Object body,int expected) throws Exception {
  req.header("Authorization",user.token);
  if(body!=null) req.contentType("application/json").content(json.writeValueAsBytes(body));
  var response=mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse();
  return response.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(response.getContentAsByteArray());
 }
 private record User(UUID id,String token) {}
}
