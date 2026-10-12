package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentMatchers;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.AuthDtos;
import vn.gomate.auth.AuthService;
import vn.gomate.common.Db;
import vn.gomate.message.dto.MessageDtos;
import vn.gomate.message.service.MessageMongoService;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class GroupTripChatApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @MockitoBean MessageMongoService messages;

 @AfterEach
 void cleanup() {
  db.update("DELETE FROM conversation_members",Map.of());
  db.update("DELETE FROM conversations",Map.of());
  db.update("DELETE FROM trip_reminders",Map.of());
  db.update("DELETE FROM trip_stops",Map.of());
  db.update("DELETE FROM trip_members",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 @Test
 void groupTripCreatesExactlyOneLinkedGroupConversationAndAllowsText() throws Exception {
  stubMessages();
  var leader=register("group-leader");
  var member=register("group-member");
  var outsider=register("group-outsider");

  JsonNode trip=performJson(post("/api/v1/trips"),leader.token(),Map.of(
   "title","Đà Lạt 2026",
   "description","Group foundation",
   "selectedMemberIds",List.of(member.id().toString()),
   "startDate","2026-12-01",
   "endDate","2026-12-03"
  ),201);

  UUID tripId=UUID.fromString(trip.get("id").asText());
  UUID conversationId=UUID.fromString(trip.get("linkedConversationId").asText());
  assertEquals("GROUP",trip.get("tripType").asText());
  assertEquals(2,trip.get("memberCount").asInt());
  assertEquals("LEADER",trip.get("members").get(0).get("role").asText());
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:tripId AND user_id=:userId AND role='MEMBER'",args("tripId",tripId,"userId",member.id())));
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:tripId AND type='GROUP'",args("tripId",tripId)));
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:conversationId AND user_id=:userId AND role='LEADER'",args("conversationId",conversationId,"userId",leader.id())));
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:conversationId AND user_id=:userId AND role='MEMBER'",args("conversationId",conversationId,"userId",member.id())));

  JsonNode conversations=performJson(get("/api/v1/conversations"),leader.token(),null,200);
  assertEquals(1,conversations.size());
  assertEquals("GROUP",conversations.get(0).get("type").asText());
  assertEquals(tripId.toString(),conversations.get(0).get("linkedTripId").asText());
  assertEquals("Đà Lạt 2026",conversations.get(0).get("displayName").asText());
  assertEquals(2,conversations.get(0).get("memberCount").asInt());

  JsonNode sent=performJson(post("/api/v1/conversations/"+conversationId+"/messages"),leader.token(),Map.of("text","Xin chào nhóm"),201);
  assertEquals(conversationId.toString(),sent.get("conversationId").asText());
  assertEquals("Xin chào nhóm",sent.get("text").asText());

  mvc.perform(get("/api/v1/conversations/"+conversationId).header("Authorization",outsider.token()))
   .andExpect(status().isNotFound());
  mvc.perform(post("/api/v1/conversations/"+conversationId+"/messages")
    .header("Authorization",outsider.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("text","No access"))))
   .andExpect(status().isNotFound());
 }

 @Test
 void tripAndGroupChatRenameUseTripNameAuthority() throws Exception {
  stubMessages();
  var leader=register("rename-leader");
  var member=register("rename-member");

  JsonNode trip=performJson(post("/api/v1/trips"),leader.token(),Map.of(
   "title","Đà Lạt 2026",
   "selectedMemberIds",List.of(member.id().toString()),
   "startDate","2026-12-01",
   "endDate","2026-12-03"
  ),201);
  String tripId=trip.get("id").asText();
  String conversationId=trip.get("linkedConversationId").asText();

  JsonNode renamedTrip=performJson(patch("/api/v1/trips/"+tripId),leader.token(),Map.of(
   "title","Đà Lạt cuối năm"
  ),200);
  assertEquals("Đà Lạt cuối năm",renamedTrip.get("title").asText());
  JsonNode conversationAfterTripRename=performJson(get("/api/v1/conversations/"+conversationId),leader.token(),null,200)
   .get("conversation");
  assertEquals("Đà Lạt cuối năm",conversationAfterTripRename.get("displayName").asText());

  JsonNode renamedChat=performJson(patch("/api/v1/conversations/"+conversationId+"/name"),leader.token(),Map.of(
   "name","Đà Lạt nhóm mình"
  ),200);
  assertEquals("Đà Lạt nhóm mình",renamedChat.get("displayName").asText());
  JsonNode tripAfterChatRename=performJson(get("/api/v1/trips/"+tripId),leader.token(),null,200);
  assertEquals("Đà Lạt nhóm mình",tripAfterChatRename.get("title").asText());
 }

 @Test
 void createTripDerivesTypeFromPersistedSelectedMembersAndIgnoresClientTripType() throws Exception {
  stubMessages();
  var leader=register("derive-leader");
  var b=register("derive-b");
  var c=register("derive-c");

  JsonNode personal=performJson(post("/api/v1/trips"),leader.token(),Map.of(
   "title","Trip cá nhân test",
   "tripType","GROUP",
   "selectedMemberIds",List.of(),
   "startDate","2026-12-01",
   "endDate","2026-12-02"
  ),201);
  UUID personalTripId=UUID.fromString(personal.get("id").asText());
  assertEquals("PERSONAL",personal.get("tripType").asText());
  assertEquals(1,personal.get("memberCount").asInt());
  assertTrue(personal.get("linkedConversationId").isNull());
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:tripId",args("tripId",personalTripId)));
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:tripId",args("tripId",personalTripId)));

  JsonNode group=performJson(post("/api/v1/trips"),leader.token(),Map.of(
   "title","Trip nhóm test",
   "tripType","PERSONAL",
   "selectedMemberIds",List.of(b.id().toString(),b.id().toString(),c.id().toString()),
   "startDate","2026-12-03",
   "endDate","2026-12-05"
  ),201);
  UUID groupTripId=UUID.fromString(group.get("id").asText());
  UUID conversationId=UUID.fromString(group.get("linkedConversationId").asText());
  assertEquals("GROUP",group.get("tripType").asText());
  assertEquals(3,group.get("memberCount").asInt());
  assertEquals(3,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:tripId",args("tripId",groupTripId)));
  assertEquals(3,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:conversationId",args("conversationId",conversationId)));
 }

 @Test
 void leaderCanAddMembersToExistingPersonalTripAndConvertItToGroup() throws Exception {
  stubMessages();
  var leader=register("add-member-leader");
  var b=register("add-member-b");
  var c=register("add-member-c");

  JsonNode personal=performJson(post("/api/v1/trips"),leader.token(),Map.of(
   "title","Trip sẽ thành nhóm",
   "startDate","2026-12-01",
   "endDate","2026-12-02"
  ),201);
  String tripId=personal.get("id").asText();
  assertEquals("PERSONAL",personal.get("tripType").asText());
  assertTrue(personal.get("linkedConversationId").isNull());

  JsonNode suggestions=performJson(get("/api/v1/users/search?q=&page=0&size=20"),leader.token(),null,200);
  assertTrue(suggestions.get("items").size()>=2);

  JsonNode group=performJson(post("/api/v1/trips/"+tripId+"/members"),leader.token(),Map.of(
   "selectedMemberIds",List.of(b.id().toString(),b.id().toString(),c.id().toString())
  ),200);

  UUID groupTripId=UUID.fromString(tripId);
  UUID conversationId=UUID.fromString(group.get("linkedConversationId").asText());
  assertEquals("GROUP",group.get("tripType").asText());
  assertEquals(3,group.get("memberCount").asInt());
  assertEquals(3,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:tripId AND status='ACTIVE'",args("tripId",groupTripId)));
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversations WHERE linked_trip_id=:tripId AND type='GROUP'",args("tripId",groupTripId)));
  assertEquals(3,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:conversationId",args("conversationId",conversationId)));

  JsonNode secondRun=performJson(post("/api/v1/trips/"+tripId+"/members"),leader.token(),Map.of(
   "selectedMemberIds",List.of(b.id().toString(),c.id().toString())
  ),200);
  assertEquals(3,secondRun.get("memberCount").asInt());
  assertEquals(3,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:tripId AND status='ACTIVE'",args("tripId",groupTripId)));
  assertEquals(3,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:conversationId",args("conversationId",conversationId)));
 }

 @Test
 void createTripRejectsDefaultTitleAndInvalidSelectedMemberWithoutPartialRows() throws Exception {
  stubMessages();
  var leader=register("invalid-leader");
  UUID missing=UUID.randomUUID();

  mvc.perform(post("/api/v1/trips")
    .header("Authorization",leader.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of(
     "title","  Lịch trình  ",
     "startDate","2026-12-01",
     "endDate","2026-12-02"
    ))))
   .andExpect(status().isBadRequest());

  mvc.perform(post("/api/v1/trips")
    .header("Authorization",leader.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of(
     "title","Trip lỗi member",
     "selectedMemberIds",List.of(missing.toString()),
     "startDate","2026-12-01",
     "endDate","2026-12-02"
    ))))
   .andExpect(status().isNotFound());

  assertEquals(0,db.count("SELECT COUNT(*) FROM trips WHERE owner_id=:userId",args("userId",leader.id())));
  assertEquals(0,db.count("SELECT COUNT(*) FROM trip_members WHERE user_id=:userId",args("userId",leader.id())));
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE created_by=:userId AND type='GROUP'",args("userId",leader.id())));
 }

 private void stubMessages() {
  when(messages.latest(any(UUID.class))).thenReturn(null);
  when(messages.unreadCount(any(UUID.class),any(UUID.class),ArgumentMatchers.any())).thenReturn(0L);
  when(messages.list(any(UUID.class),anyInt(),ArgumentMatchers.any())).thenReturn(List.of());
  when(messages.count(any(UUID.class))).thenReturn(0L);
  when(messages.saveText(any(UUID.class),any(UUID.class),anyString(),ArgumentMatchers.<Map<String,Object>>any()))
   .thenAnswer(invocation -> new MessageDtos.MessageItem(
    UUID.randomUUID().toString(),
    invocation.getArgument(0),
    invocation.getArgument(1),
    "TEXT",
    invocation.getArgument(2),
    invocation.getArgument(3),
    Instant.now()
   ));
 }

 private JsonNode performJson(
  org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,
  String token,
  Object body,
  int expectedStatus
 ) throws Exception {
  request.header("Authorization",token);
  if(body!=null) request.contentType("application/json").content(json.writeValueAsBytes(body));
  var result=mvc.perform(request)
   .andExpect(status().is(expectedStatus))
   .andReturn();
  byte[] bytes=result.getResponse().getContentAsByteArray();
  return bytes.length==0?json.createObjectNode():json.readTree(bytes);
 }

 private TestUser register(String prefix) {
  String suffix=UUID.randomUUID().toString().replace("-","");
  String email=prefix+"_"+suffix+"@example.com";
  Map<String,Object> session=auth.register(new AuthDtos.Register(email,"TestPass123!",prefix+"_"+suffix.substring(0,8)));
  @SuppressWarnings("unchecked")
  UUID userId=(UUID)((Map<String,Object>)session.get("user")).get("id");
  return new TestUser(userId,"Bearer "+session.get("accessToken"));
 }

 private record TestUser(UUID id,String token) {}
}
