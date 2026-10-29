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
import vn.gomate.location.realtime.TripLocationStreamHub;
import vn.gomate.message.repository.ConversationRepository;
import vn.gomate.message.service.MessageMongoService;
import vn.gomate.notification.push.NotificationPushDelivery;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class TripCompletionCancellationTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @MockitoBean MessageMongoService messages;
 @MockitoBean TripLocationMongoRepository locations;
 @MockitoBean NotificationPushDelivery pushes;
 @MockitoSpyBean ConversationRepository conversations;
 @MockitoSpyBean TripLocationStreamHub streams;

 @BeforeEach void setup() { when(messages.list(any(),anyInt(),any())).thenReturn(List.of()); }
 @AfterEach void cleanup() {
  reset(conversations,streams);
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 // Replaces obsolete status-transition assertions with pin-centric lifecycle coverage.
 @Test void unpinRetainsTripMembersStopsInvitesAndChat() throws Exception {
  var a=user(); var b=user(); var c=user(); String id=group(a,b),url=path(id);
  String chat=call(get(url),a,null,200).path("linkedConversationId").asText();
  String invite=invite(a,c,id); long place=place();
  call(post(url+"/stops"),a,Map.of("placeId",place),201);
  call(post(url+"/pin"),a,null,200); call(post(url+"/pin"),b,null,200);
  call(delete(url+"/pin"),a,null,204);
  var detail=call(get(url),a,null,200);
  assertFalse(detail.has("status")); assertFalse(detail.has("startedAt")); assertFalse(detail.has("completedAt"));
  assertEquals(chat,detail.path("linkedConversationId").asText());
  assertEquals(2,detail.path("members").size()); assertEquals(1,detail.path("stops").size());
  assertEquals(1,detail.path("pendingInvitations").size());
  assertEquals(id,call(get("/api/v1/trips/pinned"),b,null,200).path("trip").path("id").asText());
  assertEquals("PENDING",db.one("SELECT status FROM trip_invitations WHERE id=:id",args("id",UUID.fromString(invite))).get("status"));
  assertEquals("ACCEPTED",db.one("SELECT status FROM conversations WHERE id=:id",args("id",UUID.fromString(chat))).get("status"));
  call(patch(url),a,Map.of("title","Still editable"),200);
  call(post("/api/v1/trip-invitations/"+invite+"/accept"),c,null,200);
  assertTrue(call(get("/api/v1/trips/pinned"),c,null,200).path("trip").isNull());
 }

 @ParameterizedTest @ValueSource(strings={"start","complete","cancel","location-sharing"})
 void oldLifecycleEndpointsAreAbsent(String suffix) throws Exception {
  var a=user(); String id=create(a);
  call(post(path(id)+"/"+suffix),a,null,404);
  call(patch(path(id)),a,Map.of("status","ACTIVE"),400);
 }

 @Test void pinNeverCreatesChatOrInvitationsAndPastDatesDoNotCloseTrip() throws Exception {
  var a=user(); String id=create(a);
  call(post(path(id)+"/pin"),a,null,200); call(post(path(id)+"/pin"),a,null,200);
  assertEquals(1,count("trip_pins",id));
  assertEquals(0,count("trip_invitations",id));
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id",args("id",UUID.fromString(id))));
  assertFalse(call(get(path(id)),a,null,200).has("status"));
 }

 @Test void crossTripRemovalNeverClearsOtherPin() throws Exception {
  var a=user(); var b=user(); String first=group(a,b),second=group(b,a);
  call(post(path(second)+"/pin"),b,null,200);
  call(delete(path(first)+"/members/"+b.id),a,null,200);
  assertEquals(second,call(get("/api/v1/trips/pinned"),b,null,200).path("trip").path("id").asText());
  verify(locations).deleteByMember(UUID.fromString(first),b.id);
  verify(locations,never()).deleteByTrip(UUID.fromString(second));
 }

 @Test void leaderTransferDoesNotPinOrCloseChat() throws Exception {
  var a=user(); var b=user(); String id=group(a,b);
  call(post(path(id)+"/pin"),a,null,200);
  String chat=call(get(path(id)),a,null,200).path("linkedConversationId").asText();
  call(patch(path(id)+"/leader"),a,Map.of("targetUserId",b.id),200);
  assertEquals(id,call(get("/api/v1/trips/pinned"),a,null,200).path("trip").path("id").asText());
  assertTrue(call(get("/api/v1/trips/pinned"),b,null,200).path("trip").isNull());
  assertEquals(chat,call(get(path(id)),b,null,200).path("linkedConversationId").asText());
 }

 @Test void deleteKeepsApprovedSoftArchiveAndChatHistoryNotAnUnpin() throws Exception {
  var a=user(); var b=user(); var c=user(); String id=group(a,b),url=path(id); UUID trip=UUID.fromString(id);
  UUID chat=UUID.fromString(call(get(url),a,null,200).path("linkedConversationId").asText());
  String invitation=invite(a,c,id);
  call(post(url+"/pin"),a,null,200); call(post(url+"/pin"),b,null,200);
  call(delete(url),b,null,403);
  doThrow(new IllegalStateException("SSE fixture")).when(streams).invalidate(trip);
  call(delete(url),a,null,204); call(delete(url),a,null,204);
  call(get(url),a,null,404);
  assertNotNull(db.one("SELECT archived_at FROM trips WHERE id=:id",args("id",trip)).get("archivedAt"));
  assertEquals("CLOSED",db.one("SELECT status FROM conversations WHERE id=:id",args("id",chat)).get("status"));
  assertEquals(2,count("trip_members",id));
  assertEquals(2,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:id",args("id",chat)));
  assertEquals(0,count("trip_pins",id));
  assertEquals("CANCELLED",db.one("SELECT status FROM trip_invitations WHERE id=:id",args("id",UUID.fromString(invitation))).get("status"));
  verify(messages,never()).saveText(eq(chat),any(),any(),any());
  call(get("/api/v1/conversations/"+chat),a,null,404);
 }

 @Test void relationalDeleteRollbackAndUnpinNeverNeedsMongoDeletion() throws Exception {
  var a=user(); var b=user(); String id=group(a,b),url=path(id);
  UUID chat=UUID.fromString(call(get(url),a,null,200).path("linkedConversationId").asText());
  call(post(url+"/pin"),b,null,200);
  doThrow(new IllegalStateException("relational fixture")).when(conversations).archiveGroup(chat);
  call(delete(url),a,null,500);
  assertEquals(1,count("trip_pins",id)); call(get(url),a,null,200);
  verify(locations,never()).deleteByTrip(any());
  reset(conversations);
  doThrow(new IllegalStateException("Mongo fixture")).when(locations).deleteByMember(UUID.fromString(id),b.id);
  call(delete(url+"/pin"),b,null,204);
  assertEquals(0,count("trip_pins",id));
  verify(locations,never()).deleteByMember(any(),any());
  assertEquals("ACCEPTED",db.one("SELECT status FROM conversations WHERE id=:id",args("id",chat)).get("status"));
 }

 @ParameterizedTest @ValueSource(strings={"samePin","switchPin","acceptAndPin","inviteAndUnpin"})
 void concurrentUserActionsKeepSinglePinAndMembershipAuthority(String scenario) throws Exception {
  var a=user(); var b=user(); String id=create(a),other=create(a),invitation=invite(a,b,id);
  var gate=new CountDownLatch(1); var pool=Executors.newFixedThreadPool(2);
  try {
   var first=pool.submit(() -> { gate.await(); return raw(post(path(id)+"/pin"),a,null); });
   var second=pool.submit(() -> {
    gate.await();
    return switch(scenario) {
     case "switchPin" -> raw(post(path(other)+"/pin"),a,null);
     case "acceptAndPin" -> raw(post("/api/v1/trip-invitations/"+invitation+"/accept"),b,null);
     case "inviteAndUnpin" -> raw(delete(path(other)+"/pin"),a,null);
     default -> raw(post(path(id)+"/pin"),a,null);
    };
   });
   gate.countDown();
   assertEquals(200,first.get(20,TimeUnit.SECONDS));
   assertTrue(Set.of(200,204).contains(second.get(20,TimeUnit.SECONDS)));
   assertEquals(1,db.count("SELECT COUNT(*) FROM trip_pins WHERE user_id=:user",args("user",a.id)));
   assertEquals(0,db.count("SELECT COUNT(*) FROM trip_pins WHERE user_id=:user",args("user",b.id)));
   call(get(path(id)),a,null,200);
  } finally { pool.shutdownNow(); }
 }

 private long place() {
  db.update("INSERT INTO place_categories(code,name,active) VALUES('lifecycle_fixture','Lifecycle fixture',TRUE) ON CONFLICT DO NOTHING",Map.of());
  long category=((Number)db.one("SELECT id FROM place_categories WHERE code='lifecycle_fixture'",Map.of()).get("id")).longValue();
  db.update("INSERT INTO places(name,category_id,province,latitude,longitude,status,source_type) VALUES('Lifecycle fixture',:cat,'Test',11.94,108.44,'ACTIVE','ADMIN')",args("cat",category));
  return ((Number)db.one("SELECT MAX(id) AS id FROM places WHERE category_id=:cat",args("cat",category)).get("id")).longValue();
 }
 private String path(String id) { return "/api/v1/trips/"+id; }
 private long count(String table,String id) { return db.count("SELECT COUNT(*) FROM "+table+" WHERE trip_id=:id",args("id",UUID.fromString(id))); }
 private String create(User a) throws Exception {
  String id=call(post("/api/v1/trips"),a,Map.of("title","Lifecycle fixture","startDate","2026-12-01","endDate","2026-12-02"),201).path("id").asText();
  // Historical fixture via storage, not a now-invalid backdated create request.
  db.update("UPDATE trips SET start_date='2020-01-01',end_date='2020-01-02' WHERE id=:id",args("id",UUID.fromString(id)));
  return id;
 }
 private String invite(User a,User b,String id) throws Exception { return call(post(path(id)+"/invitations"),a,Map.of("inviteeUserId",b.id),201).path("invitationId").asText(); }
 private String group(User a,User b) throws Exception { String id=create(a); call(post("/api/v1/trip-invitations/"+invite(a,b,id)+"/accept"),b,null,200); return id; }
 private User user() {
  String suffix=UUID.randomUUID().toString().replace("-","");
  var session=auth.register(new AuthDtos.Register(suffix+"@example.invalid","TestPass123!","life_"+suffix.substring(0,12)));
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
