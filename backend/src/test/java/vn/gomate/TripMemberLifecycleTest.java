package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.time.Instant;
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
import vn.gomate.message.dto.MessageDtos;
import vn.gomate.message.repository.ConversationRepository;
import vn.gomate.message.service.MessageMongoService;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class TripMemberLifecycleTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @MockitoBean MessageMongoService messages;
 @MockitoBean TripLocationMongoRepository locations;
 @MockitoSpyBean ConversationRepository conversations;
 private final Map<UUID,List<MessageDtos.MessageItem>> history=new ConcurrentHashMap<>();

 @BeforeEach void setup() {
  when(messages.list(any(),anyInt(),any())).thenAnswer(i -> history.getOrDefault(i.getArgument(0),List.of()));
  when(messages.count(any())).thenAnswer(i -> (long)history.getOrDefault(i.getArgument(0),List.of()).size());
  when(messages.saveText(any(),any(),anyString(),any())).thenAnswer(i -> {
   var item=new MessageDtos.MessageItem(UUID.randomUUID().toString(),i.getArgument(0),i.getArgument(1),"TEXT",i.getArgument(2),i.getArgument(3),Instant.now());
   history.computeIfAbsent(i.getArgument(0),id -> new ArrayList<>()).add(item);
   return item;
  });
 }
 @AfterEach void cleanup() {
  reset(conversations);
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 @ParameterizedTest @ValueSource(booleans={false,true})
 void M01_M03_M08to13_M15_M16_lastMemberLifecycleNeverReusesChat(boolean leaderRemoves) throws Exception {
  var a=user(); var b=user(); var c=user();
  var trip=group(a,b);
  UUID id=UUID.fromString(trip.get("id").asText());
  UUID c1=UUID.fromString(trip.get("linkedConversationId").asText());
  call(post("/api/v1/conversations/"+c1+"/messages"),a,Map.of("text","retained history"),201);
  call(post("/api/v1/trips/"+id+"/pin"),b,null,200);
  call(post("/api/v1/trips/"+id+"/pin"),a,null,200);
  long invitationCount=count("trip_invitations",id);
  remove(a,b,id,leaderRemoves);
  var personal=call(get("/api/v1/trips/"+id),a,null,200);
  assertEquals("PERSONAL",personal.path("tripType").asText());
  assertEquals(1,personal.path("memberCount").asInt());
  assertTrue(personal.path("linkedConversationId").isNull());
  assertTrue(personal.path("pinned").asBoolean());
  assertEquals(0,activeChats(id));
  assertEquals("CLOSED",db.one("SELECT status FROM conversations WHERE id=:id",args("id",c1)).get("status"));
  assertEquals(1,history.get(c1).size());
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:id AND user_id=:user",args("id",c1,"user",b.id)));
  assertEquals(0,db.count("SELECT COUNT(*) FROM trip_pins WHERE user_id=:user",args("user",b.id)));
  assertEquals(invitationCount,count("trip_invitations",id));
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_invitations WHERE trip_id=:id AND status='ACCEPTED'",args("id",id)));
  call(get("/api/v1/trips/"+id),b,null,404);
  call(get("/api/v1/conversations/"+c1),b,null,404);
  call(post("/api/v1/conversations/"+c1+"/messages"),b,Map.of("text","denied"),404);
  call(get("/api/v1/trips/"+id+"/locations"),b,null,404);
  call(put("/api/v1/trips/"+id+"/location"),b,Map.of("latitude",11.9,"longitude",108.4),404);
  verify(locations).deleteByMember(id,b.id);
  verify(locations,never()).upsert(any(),any(),anyDouble(),anyDouble(),any(),any(),any());
  verify(locations,never()).findByTrip(any());
  call(post("/api/v1/trips/"+id+"/pin"),b,null,404);
  call(delete("/api/v1/trips/"+id+"/members/me"),b,null,404);
  call(delete("/api/v1/trips/"+id+"/members/"+b.id),a,null,404);
  assertEquals(0,call(get("/api/v1/conversations"),a,null,200).size());
  var invite=call(post("/api/v1/trips/"+id+"/invitations"),a,Map.of("inviteeUserId",c.id),201);
  var next=call(post("/api/v1/trip-invitations/"+invite.path("invitationId").asText()+"/accept"),c,null,200);
  UUID c2=UUID.fromString(next.path("linkedConversationId").asText());
  assertNotEquals(c1,c2);
  assertEquals("GROUP",next.path("tripType").asText());
  assertEquals(1,activeChats(id));
  assertEquals(2,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id",args("id",id)));
  for(var viewer:List.of(a,c)) {
   call(get("/api/v1/conversations/"+c1),viewer,null,404);
   call(get("/api/v1/conversations/"+c1+"/messages"),viewer,null,404);
   call(post("/api/v1/conversations/"+c1+"/messages"),viewer,Map.of("text","no inherited history"),404);
   call(post("/api/v1/conversations/"+c1+"/read"),viewer,null,404);
   call(patch("/api/v1/conversations/"+c1+"/name"),viewer,Map.of("name","no rename through archive"),404);
  }
  call(get("/api/v1/conversations/"+c2),c,null,200);
  assertEquals(1,history.get(c1).size());
  // An old ACCEPTED invitation never becomes a fresh membership grant.
  String oldInvite=db.one("SELECT id FROM trip_invitations WHERE trip_id=:id AND invitee_user_id=:user AND status='ACCEPTED'",args("id",id,"user",b.id)).get("id").toString();
  call(post("/api/v1/trip-invitations/"+oldInvite+"/accept"),b,null,404);
 }

 @Test void M02_M04to07_permissionsAndNonLastRemoval() throws Exception {
  var a=user(); var b=user(); var c=user(); var outsider=user();
  var trip=group(a,b); String id=trip.path("id").asText(); String chat=trip.path("linkedConversationId").asText();
  var invitation=call(post("/api/v1/trips/"+id+"/invitations"),a,Map.of("inviteeUserId",c.id),201);
  call(post("/api/v1/trip-invitations/"+invitation.path("invitationId").asText()+"/accept"),c,null,200);
  call(delete("/api/v1/trips/"+id+"/members/"+c.id),b,null,403);
  call(delete("/api/v1/trips/"+id+"/members/me"),a,null,422);
  call(delete("/api/v1/trips/"+id+"/members/"+a.id),a,null,422);
  call(delete("/api/v1/trips/"+id+"/members/me"),outsider,null,404);
  call(delete("/api/v1/trips/"+id+"/members/"+b.id),outsider,null,404);
  call(delete("/api/v1/trips/"+id+"/members/"+outsider.id),a,null,404);
  var after=call(delete("/api/v1/trips/"+id+"/members/"+b.id),a,null,200);
  assertEquals("GROUP",after.path("tripType").asText());
  assertEquals(chat,after.path("linkedConversationId").asText());
  assertEquals(2,after.path("memberCount").asInt());
  assertEquals(2,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:id",args("id",UUID.fromString(chat))));
  call(post("/api/v1/conversations/"+chat+"/messages"),b,Map.of("text","removed"),404);
  // Rejoining a still-active lifecycle uses a new invitation, not old acceptance.
  var reinvite=call(post("/api/v1/trips/"+id+"/invitations"),a,Map.of("inviteeUserId",b.id),201);
  var rejoined=call(post("/api/v1/trip-invitations/"+reinvite.path("invitationId").asText()+"/accept"),b,null,200);
  assertEquals(chat,rejoined.path("linkedConversationId").asText());
 }

 @ParameterizedTest @ValueSource(booleans={false,true})
 void M08_M09_transactionRollsBackBothMembershipsOnChatFailure(boolean leaderRemoves) throws Exception {
  var a=user(); var b=user(); var trip=group(a,b);
  UUID id=UUID.fromString(trip.path("id").asText()); UUID chat=UUID.fromString(trip.path("linkedConversationId").asText());
  call(post("/api/v1/trips/"+id+"/pin"),b,null,200);
  doThrow(new IllegalStateException("fixture failure")).when(conversations).removeMember(chat,b.id);
  call(delete("/api/v1/trips/"+id+"/members/"+(leaderRemoves?b.id:"me")),leaderRemoves?a:b,null,500);
  assertEquals(2,count("trip_members",id));
  assertEquals(2,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:id",args("id",chat)));
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_pins WHERE user_id=:id",args("id",b.id)));
  assertEquals(1,activeChats(id));
 }

 @Test void M14_concurrentLeaveAndRemoveHaveOneEffectiveResult() throws Exception {
  var a=user(); var b=user(); var trip=group(a,b); String id=trip.path("id").asText();
  var start=new CountDownLatch(1); var workers=Executors.newFixedThreadPool(2);
  try {
   var leave=workers.submit(() -> { start.await(); return raw(delete("/api/v1/trips/"+id+"/members/me"),b,null); });
   var remove=workers.submit(() -> { start.await(); return raw(delete("/api/v1/trips/"+id+"/members/"+b.id),a,null); });
   start.countDown();
   var codes=List.of(leave.get(15,TimeUnit.SECONDS),remove.get(15,TimeUnit.SECONDS));
   assertTrue(codes.equals(List.of(204,404)) || codes.equals(List.of(404,200)),codes.toString());
   assertEquals(1,count("trip_members",UUID.fromString(id)));
   assertEquals(0,activeChats(UUID.fromString(id)));
  } finally { workers.shutdownNow(); }
 }

 private void remove(User a,User b,UUID tripId,boolean leader) throws Exception {
  call(delete("/api/v1/trips/"+tripId+"/members/"+(leader?b.id:"me")),leader?a:b,null,leader?200:204);
 }
 private long count(String table,UUID trip) { return db.count("SELECT COUNT(*) FROM "+table+" WHERE trip_id=:id",args("id",trip)); }
 private long activeChats(UUID trip) { return db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:id AND status='ACCEPTED'",args("id",trip)); }
 private JsonNode group(User a,User b) throws Exception {
  var trip=call(post("/api/v1/trips"),a,Map.of("title","Lifecycle fixture","startDate","2026-12-01","endDate","2026-12-02","selectedMemberIds",List.of(b.id)),201);
  return call(post("/api/v1/trip-invitations/"+trip.path("pendingInvitations").get(0).path("invitationId").asText()+"/accept"),b,null,200);
 }
 private User user() {
  String suffix=UUID.randomUUID().toString().replace("-","");
  var session=auth.register(new AuthDtos.Register(suffix+"@example.invalid","TestPass123!","ml_"+suffix.substring(0,12)));
  return new User((UUID)((Map<?,?>)session.get("user")).get("id"),"Bearer "+session.get("accessToken"));
 }
 private int raw(MockHttpServletRequestBuilder request,User user,Object body) throws Exception {
  request.header("Authorization",user.token);
  if(body!=null) request.contentType("application/json").content(json.writeValueAsBytes(body));
  return mvc.perform(request).andReturn().getResponse().getStatus();
 }
 private JsonNode call(MockHttpServletRequestBuilder request,User user,Object body,int statusCode) throws Exception {
  request.header("Authorization",user.token);
  if(body!=null) request.contentType("application/json").content(json.writeValueAsBytes(body));
  var response=mvc.perform(request).andExpect(status().is(statusCode)).andReturn().getResponse();
  return response.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(response.getContentAsByteArray());
 }
 private record User(UUID id,String token) {}
}
