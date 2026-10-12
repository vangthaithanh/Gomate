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
import vn.gomate.common.ApiException;
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
class DirectMessageApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @MockitoBean MessageMongoService messages;

 @AfterEach
 void cleanup() {
  db.update("DELETE FROM conversation_members",Map.of());
  db.update("DELETE FROM conversations",Map.of());
  db.update("DELETE FROM user_follows",Map.of());
 }

 @Test
 void nonMutualDirectConversationStartsPendingAndRecipientAccepts() throws Exception {
  stubEmptyMessages();
  var requester=register("dm-requester");
  var recipient=register("dm-recipient");

  JsonNode opened=performJson(post("/api/v1/conversations/direct"),requester.token(),Map.of(
   "targetUserId",recipient.id().toString()
  ),201);
  String conversationId=opened.get("conversationId").asText();
  assertEquals("PENDING",opened.get("status").asText());
  assertTrue(opened.get("requester").asBoolean());

  performJson(post("/api/v1/conversations/"+conversationId+"/messages"),requester.token(),Map.of("text","Xin chao"),201);
  mvc.perform(post("/api/v1/conversations/"+conversationId+"/messages")
    .header("Authorization",recipient.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("text","Chao ban"))))
   .andExpect(status().isForbidden())
   .andExpect(jsonPath("$.code").value("PENDING_REQUEST_NOT_ACCEPTED"));

  JsonNode pending=performJson(get("/api/v1/message-requests"),recipient.token(),null,200);
  assertEquals(1,pending.size());
  assertEquals(conversationId,pending.get(0).get("conversationId").asText());

  JsonNode accepted=performJson(post("/api/v1/message-requests/"+conversationId+"/accept"),recipient.token(),null,200);
  assertEquals("ACCEPTED",accepted.get("status").asText());

  performJson(post("/api/v1/conversations/"+conversationId+"/messages"),recipient.token(),Map.of("text","Chao ban"),201);
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversations WHERE id=:id AND status='ACCEPTED'",args("id",UUID.fromString(conversationId))));
 }

 @Test
 void mutualFriendsOpenAcceptedConversationAndOtherUserCannotRead() throws Exception {
  stubEmptyMessages();
  var userA=register("dm-mutual-a");
  var userB=register("dm-mutual-b");
  var outsider=register("dm-outsider");
  makeMutual(userA.id(),userB.id());

  JsonNode opened=performJson(post("/api/v1/conversations/direct"),userA.token(),Map.of(
   "targetUserId",userB.id().toString()
  ),201);
  String conversationId=opened.get("conversationId").asText();
  assertEquals("ACCEPTED",opened.get("status").asText());

  mvc.perform(get("/api/v1/conversations/"+conversationId).header("Authorization",outsider.token()))
   .andExpect(status().isNotFound());

  performJson(post("/api/v1/conversations/"+conversationId+"/block"),userA.token(),null,200);
  mvc.perform(post("/api/v1/conversations/"+conversationId+"/messages")
    .header("Authorization",userB.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("text","blocked?"))))
   .andExpect(status().isForbidden())
   .andExpect(jsonPath("$.code").value("CONVERSATION_BLOCKED"));
 }

 @Test
 void invalidTargetSelfTargetAndMongoFailureAreControlled() throws Exception {
  stubEmptyMessages();
  var userA=register("dm-error-a");
  var userB=register("dm-error-b");

  mvc.perform(post("/api/v1/conversations/direct")
    .header("Authorization",userA.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("targetUserId",userA.id().toString()))))
   .andExpect(status().isBadRequest());

  mvc.perform(post("/api/v1/conversations/direct")
    .header("Authorization",userA.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("targetUserId",UUID.randomUUID().toString()))))
   .andExpect(status().isNotFound())
   .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));

  JsonNode opened=performJson(post("/api/v1/conversations/direct"),userA.token(),Map.of(
   "targetUserId",userB.id().toString()
  ),201);
  when(messages.saveText(any(UUID.class),any(UUID.class),anyString(),ArgumentMatchers.<Map<String,Object>>any()))
   .thenThrow(new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Mongo down"));

  mvc.perform(post("/api/v1/conversations/"+opened.get("conversationId").asText()+"/messages")
    .header("Authorization",userA.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("text","fail"))))
   .andExpect(status().isServiceUnavailable())
   .andExpect(jsonPath("$.code").value("MESSAGE_STORE_UNAVAILABLE"));
 }

 private void stubEmptyMessages() {
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

 private void makeMutual(UUID userA,UUID userB) {
  db.update("INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(:a,:b)",args("a",userA,"b",userB));
  db.update("INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(:b,:a)",args("a",userA,"b",userB));
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
