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
 @Autowired vn.gomate.relationship.service.SocialRelationshipService relationships;
 @Autowired vn.gomate.user.service.UserService users;
 @Autowired vn.gomate.message.service.ConversationService conversations;
 @Autowired vn.gomate.message.repository.ConversationRepository conversationRepo;
 @Autowired org.springframework.transaction.PlatformTransactionManager transactionManager;

 @AfterEach
 @org.junit.jupiter.api.BeforeEach
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
  assertEquals("DRAFT",opened.get("status").asText());
  assertTrue(opened.get("conversationId").isNull());
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
  assertTrue(opened.get("requester").asBoolean());
  String conversationId=first(requester,recipient,"Xin chao").get("conversation").get("conversationId").asText();
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

  JsonNode opened=first(userA,userB,"Mutual").get("conversation");
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
  when(messages.saveText(any(UUID.class),any(UUID.class),anyString(),ArgumentMatchers.<Map<String,Object>>any(),any(UUID.class),anyString()))
   .thenThrow(new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Mongo down"));

  mvc.perform(post("/api/v1/conversations/direct/messages")
    .header("Authorization",userA.token())
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("text","fail","targetUserId",userB.id(),"clientRequestId",UUID.randomUUID()))))
   .andExpect(status().isServiceUnavailable())
   .andExpect(jsonPath("$.code").value("MESSAGE_STORE_UNAVAILABLE"));
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
 }

 @Test
 void privatePendingIsNotMutualAndAcceptedFollowKeepsDirectMessageRules() throws Exception {
  stubEmptyMessages();
  var owner=register("private-dm-owner");
  var viewer=register("private-dm-viewer");
  users.updateProfile(owner.id(),new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,null,null,null,null,true));
  relationships.follow(viewer.id(),owner.id());
  performJson(post("/api/v1/conversations/direct"),viewer.token(),Map.of("targetUserId",owner.id()),403);
  assertFalse(users.publicProfile(viewer.id(),owner.id()).canInitiateMessage());
  UUID requestId=(UUID)db.one("SELECT id FROM follow_requests WHERE requester_id=:a AND target_id=:b AND status='PENDING'",
   args("a",viewer.id(),"b",owner.id())).get("id");
  relationships.respond(owner.id(),requestId,true);
  JsonNode pending=first(viewer,owner,"One way").get("conversation");
  assertEquals("PENDING",pending.get("status").asText());
  relationships.follow(owner.id(),viewer.id());
  // Follow approval does not accept an existing independent DM request.
  JsonNode stillPending=performJson(get("/api/v1/conversations/"+pending.get("conversationId").asText()),viewer.token(),null,200);
  assertEquals("PENDING",stillPending.get("conversation").get("status").asText());
  assertTrue(relationships.isMutualFriend(owner.id(),viewer.id()));
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
  when(messages.saveText(any(UUID.class),any(UUID.class),anyString(),ArgumentMatchers.<Map<String,Object>>any(),any(UUID.class),anyString()))
   .thenAnswer(i -> new MessageDtos.MessageItem(MessageMongoService.textMessageId(i.getArgument(1),i.getArgument(4),i.getArgument(5)),i.getArgument(0),i.getArgument(1),"TEXT",i.getArgument(2),i.getArgument(3),Instant.now()));
 }

 private JsonNode first(TestUser sender,TestUser target,String text) throws Exception {
  return performJson(post("/api/v1/conversations/direct/messages"),sender.token(),Map.of("targetUserId",target.id(),"clientRequestId",UUID.randomUUID(),"text",text),201);
 }

 @Test void recipientPrivacyMatrixUsesAcceptedEdgesAndNotSenderPrivacy() throws Exception {
  stubEmptyMessages();
  var a=register("matrix-a");var b=register("matrix-b");
  assertTrue(users.publicProfile(a.id(),b.id()).canInitiateMessage());
  privacy(b,true);
  assertFalse(users.publicProfile(a.id(),b.id()).canInitiateMessage());
  performJson(post("/api/v1/conversations/direct/messages"),a.token(),Map.of("targetUserId",b.id(),"clientRequestId",UUID.randomUUID(),"text","bypass"),403);
  relationships.follow(a.id(),b.id());
  assertFalse(users.publicProfile(a.id(),b.id()).canInitiateMessage());
  var request=relationships.requests(b.id(),0,50).items().get(0);
  relationships.respond(b.id(),request.id(),false);
  assertFalse(users.publicProfile(a.id(),b.id()).canInitiateMessage());
  // PRIVATE sender can contact a PUBLIC recipient; opening is still write-free.
  assertTrue(users.publicProfile(b.id(),a.id()).canInitiateMessage());
  var sent=first(b,a,"Private sender").get("conversation");
  assertEquals("PENDING",sent.get("status").asText());
  assertTrue(conversations.listAccepted(a.id(),0,50).isEmpty());
  assertEquals(1,conversations.listPending(a.id(),0,50).size());
  assertTrue(conversations.listPending(b.id(),0,50).isEmpty());
 }

 @Test void onlyRecipientResolvesPendingAndAcceptKeepsHistoryAndNeverFollows() throws Exception {
  stubEmptyMessages();var a=register("resolve-a");var b=register("resolve-b");var c=register("resolve-c");
  var sent=first(a,b,"History");UUID id=UUID.fromString(sent.get("conversation").get("conversationId").asText());
  assertEquals(403,assertThrows(ApiException.class,()->conversations.accept(id,a.id())).status);
  assertEquals(403,assertThrows(ApiException.class,()->conversations.deletePending(id,a.id())).status);
  assertEquals(404,assertThrows(ApiException.class,()->conversations.accept(id,c.id())).status);
  when(messages.list(eq(id),anyInt(),any())).thenReturn(List.of(json.treeToValue(sent.get("message"),MessageDtos.MessageItem.class)));
  assertEquals("PENDING",conversations.detail(id,b.id(),30,null).conversation().status());
  assertEquals("ACCEPTED",conversations.accept(id,b.id()).status());
  assertEquals(id,conversations.accept(id,b.id()).conversationId());
  assertEquals(403,assertThrows(ApiException.class,()->conversations.accept(id,a.id())).status);
  assertEquals(1,conversations.detail(id,b.id(),30,null).messages().size());
  assertFalse(relationships.isFollowing(a.id(),b.id()));
  assertEquals(422,assertThrows(ApiException.class,()->conversations.deletePending(id,b.id())).status);
 }

 @Test void acceptedContinuesAfterUnfollowPrivateButProfileInitiationRemainsDenied() throws Exception {
  stubEmptyMessages();var a=register("accepted-a");var b=register("accepted-b");makeMutual(a.id(),b.id());
  var sent=first(a,b,"Start");UUID id=UUID.fromString(sent.get("conversation").get("conversationId").asText());
  relationships.unfollow(a.id(),b.id());relationships.unfollow(b.id(),a.id());privacy(b,true);
  assertFalse(users.publicProfile(a.id(),b.id()).canInitiateMessage());
  assertEquals(403,assertThrows(ApiException.class,()->conversations.openDirect(a.id(),b.id())).status);
  assertNotNull(conversations.sendText(id,a.id(),new MessageDtos.SendTextRequest("Continue",null)));
  assertEquals("ACCEPTED",conversations.listAccepted(a.id(),0,20).get(0).status());
  conversations.setBlocked(id,b.id(),true);
  assertEquals(403,assertThrows(ApiException.class,()->conversations.sendText(id,a.id(),new MessageDtos.SendTextRequest("Blocked",null))).status);
  conversations.setBlocked(id,b.id(),false);
  assertNotNull(conversations.sendText(id,a.id(),new MessageDtos.SendTextRequest("Unblocked",null)));
 }

 @Test void rejectIsIdempotentAndOnlyFirstResendReopensSamePair() throws Exception {
  stubEmptyMessages();var a=register("reject-a");var b=register("reject-b");
  UUID id=UUID.fromString(first(a,b,"Original").get("conversation").get("conversationId").asText());
  conversations.deletePending(id,b.id());conversations.deletePending(id,b.id());
  assertEquals("DRAFT",conversations.openDirect(a.id(),b.id()).status());
  assertEquals("REMOVED",db.one("SELECT status FROM conversations WHERE id=:id",args("id",id)).get("status"));
  privacy(b,true);
  assertThrows(ApiException.class,()->conversations.sendDirect(a.id(),new MessageDtos.DirectSendRequest(b.id(),UUID.randomUUID(),"Denied resend",null)));
  privacy(b,false);
  assertEquals(id,conversations.sendDirect(a.id(),new MessageDtos.DirectSendRequest(b.id(),UUID.randomUUID(),"Resend",null)).conversation().conversationId());
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
 }

 @Test void mutualAndOpenNeverCreateEmptyRowsAndRetryReusesPairAndMessageKey() {
  stubEmptyMessages();var a=register("retry-a");var b=register("retry-b");makeMutual(a.id(),b.id());
  for(int i=0;i<3;i++) assertEquals("DRAFT",conversations.openDirect(a.id(),b.id()).status());
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
  var req=new MessageDtos.DirectSendRequest(b.id(),UUID.randomUUID(),"Retry",null);
  var first=conversations.sendDirect(a.id(),req);var retry=conversations.sendDirect(a.id(),req);
  assertEquals(first.conversation().conversationId(),retry.conversation().conversationId());
  assertEquals(first.message().messageId(),retry.message().messageId());
  assertEquals(1,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
  assertEquals(2,db.count("SELECT COUNT(*) FROM conversation_members",Map.of()));
 }

 @Test void failedCommitCompensatesOnlyItsNewMessageAndRollsBackMetadata() {
  stubEmptyMessages();var a=register("commit-a");var b=register("commit-b");
  when(messages.saveText(any(),any(),anyString(),any(),any(),anyString())).thenAnswer(i -> {
   org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(new org.springframework.transaction.support.TransactionSynchronization() {
    @Override public void beforeCommit(boolean readOnly) {throw new org.springframework.dao.DataIntegrityViolationException("Injected commit failure");}
   });
   return new MessageDtos.MessageItem("attempt",i.getArgument(0),a.id(),"TEXT","fail",null,Instant.now());
  });
  var req=new MessageDtos.DirectSendRequest(b.id(),UUID.randomUUID(),"fail",null);
  assertEquals(503,assertThrows(ApiException.class,()->conversations.sendDirect(a.id(),req)).status);
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
  assertEquals(0,db.count("SELECT COUNT(*) FROM conversation_members",Map.of()));
  verify(messages).removeUncommitted(eq(MessageMongoService.textMessageId(a.id(),req.clientRequestId(),"DIRECT:"+b.id())),any(UUID.class),eq(a.id()));
 }

 @Test void simultaneousMutualFirstSendsSerializeToOnePair() throws Exception {
  stubEmptyMessages();var a=register("race-a");var b=register("race-b");makeMutual(a.id(),b.id());
  var pool=java.util.concurrent.Executors.newFixedThreadPool(2);
  var start=new java.util.concurrent.CountDownLatch(1);
  try {
   var one=pool.submit(()->{start.await();return conversations.sendDirect(a.id(),new MessageDtos.DirectSendRequest(b.id(),UUID.randomUUID(),"A",null));});
   var two=pool.submit(()->{start.await();return conversations.sendDirect(b.id(),new MessageDtos.DirectSendRequest(a.id(),UUID.randomUUID(),"B",null));});
   start.countDown();
   assertEquals(one.get(15,java.util.concurrent.TimeUnit.SECONDS).conversation().conversationId(),two.get(15,java.util.concurrent.TimeUnit.SECONDS).conversation().conversationId());
   assertEquals(1,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
  } finally {pool.shutdownNow();}
 }

 @Test void acceptDeleteRaceCannotResurrectOrCreateAnotherThread() throws Exception {
  stubEmptyMessages();var a=register("resolve-race-a");var b=register("resolve-race-b");
  UUID id=UUID.fromString(first(a,b,"Request").get("conversation").get("conversationId").asText());
  var pool=java.util.concurrent.Executors.newFixedThreadPool(2);
  try {
   var accept=pool.submit(()->{try {conversations.accept(id,b.id());} catch(ApiException e) {assertEquals(422,e.status);}});
   var reject=pool.submit(()->{try {conversations.deletePending(id,b.id());} catch(ApiException e) {assertEquals(422,e.status);}});
   accept.get(15,java.util.concurrent.TimeUnit.SECONDS);reject.get(15,java.util.concurrent.TimeUnit.SECONDS);
   assertEquals(1,db.count("SELECT COUNT(*) FROM conversations WHERE id=:id AND status IN ('ACCEPTED','REMOVED')",args("id",id)));
  } finally {pool.shutdownNow();}
 }

 private void privacy(TestUser user,boolean value) {
  users.updateProfile(user.id(),new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,null,null,null,null,value));
 }

 @Test void privacyCommitBeforeConcurrentFirstSendDeniesStalePublicUi() throws Exception {
  stubEmptyMessages();var a=register("privacy-race-a");var b=register("privacy-race-b");
  var locked=new java.util.concurrent.CountDownLatch(1);var release=new java.util.concurrent.CountDownLatch(1);
  var started=new java.util.concurrent.CountDownLatch(1);
  var pool=java.util.concurrent.Executors.newFixedThreadPool(2);
  try {
   var privacy=pool.submit(()->new org.springframework.transaction.support.TransactionTemplate(transactionManager).executeWithoutResult(tx->{
    conversationRepo.lockShareSender(b.id());privacy(b,true);locked.countDown();await(release);
   }));
   assertTrue(locked.await(5,java.util.concurrent.TimeUnit.SECONDS));
   var send=pool.submit(()->{started.countDown();return assertThrows(ApiException.class,()->conversations.sendDirect(a.id(),new MessageDtos.DirectSendRequest(b.id(),UUID.randomUUID(),"Stale public",null)));});
   assertTrue(started.await(5,java.util.concurrent.TimeUnit.SECONDS));release.countDown();
   privacy.get(10,java.util.concurrent.TimeUnit.SECONDS);assertEquals(403,send.get(10,java.util.concurrent.TimeUnit.SECONDS).status);
   assertEquals(0,db.count("SELECT COUNT(*) FROM conversations",Map.of()));
  } finally {release.countDown();pool.shutdownNow();}
 }

 @Test void blockCommitSerializesBeforeConcurrentAcceptedSend() throws Exception {
  stubEmptyMessages();var a=register("block-race-a");var b=register("block-race-b");makeMutual(a.id(),b.id());
  UUID id=UUID.fromString(first(a,b,"Start").get("conversation").get("conversationId").asText());
  var locked=new java.util.concurrent.CountDownLatch(1);var release=new java.util.concurrent.CountDownLatch(1);
  var pool=java.util.concurrent.Executors.newFixedThreadPool(2);
  try {
   var block=pool.submit(()->new org.springframework.transaction.support.TransactionTemplate(transactionManager).executeWithoutResult(tx->{
    conversationRepo.lockDirectPair(a.id(),b.id());conversations.setBlocked(id,b.id(),true);locked.countDown();await(release);
   }));
   assertTrue(locked.await(5,java.util.concurrent.TimeUnit.SECONDS));
   var send=pool.submit(()->assertThrows(ApiException.class,()->conversations.sendText(id,a.id(),new MessageDtos.SendTextRequest("Race",null))));
   release.countDown();block.get(10,java.util.concurrent.TimeUnit.SECONDS);assertEquals(403,send.get(10,java.util.concurrent.TimeUnit.SECONDS).status);
   verify(messages,never()).saveText(eq(id),eq(a.id()),eq("Race"),any());
  } finally {release.countDown();pool.shutdownNow();}
 }

 private static void await(java.util.concurrent.CountDownLatch latch) {
  try {if(!latch.await(5,java.util.concurrent.TimeUnit.SECONDS)) throw new IllegalStateException("Test latch timeout");}
  catch(InterruptedException e) {Thread.currentThread().interrupt();throw new IllegalStateException(e);}
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
