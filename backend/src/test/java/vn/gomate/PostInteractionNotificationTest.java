package vn.gomate;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.*;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.notification.dto.NotificationDtos;
import vn.gomate.notification.service.*;
import vn.gomate.notification.realtime.*;
import vn.gomate.notification.push.*;
import vn.gomate.social.comment.*;
import vn.gomate.social.post.*;
import vn.gomate.user.service.UserService;
import vn.gomate.user.dto.UserDtos;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PostInteractionNotificationTest {
 @Autowired AuthService auth; @Autowired Db db; @Autowired ObjectMapper json; @Autowired MockMvc mvc;
 @Autowired PostService posts; @Autowired PostFeedService feed; @Autowired CommentService comments;
 @Autowired NotificationService inbox; @Autowired NotificationPostTargetService targets;
 @Autowired PlatformTransactionManager transactions; @Autowired UserService users;
 @MockitoSpyBean NotificationStreamHub streams;
 @MockitoSpyBean NotificationPushDelivery push;
 @MockitoBean FcmGateway fcm;

 record User(UUID id,String bearer) {}
 User user() {
  String key="pn"+UUID.randomUUID().toString().replace("-","").substring(0,16);
  var s=auth.register(new AuthDtos.Register(key+"@example.invalid","TestPass123!",key));
  return new User((UUID)((Map<?,?>)s.get("user")).get("id"),"Bearer "+s.get("accessToken"));
 }
 long post(User owner) {
  UUID id=UUID.randomUUID();
  db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,'hash','IMAGE','READY',:pid,:thumb,'png','image/png',4,2,2)",args("id",id,"owner",owner.id,"pid",id.toString(),"thumb",id+"_cover"));
  return posts.publish(owner.id,new PostDtos.Publish(UUID.randomUUID(),"Private caption never in notification","EVERYONE",new ArrayList<>(List.of(id)),List.of(),new ArrayList<>(),null)).id();
 }
 CommentDtos.Create request(Long parent) { return new CommentDtos.Create(UUID.randomUUID(),"Private comment never in notification",parent,List.of()); }
 long comment(User user,long post,Long parent) { return ((Number)comments.create(user.id,post,request(parent)).get("id")).longValue(); }
 List<NotificationDtos.Item> notices(User user) { return inbox.list(user.id,0,50).items(); }
 void register(User user,String token) throws Exception {
  mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/notification-devices").header("Authorization",user.bearer).contentType("application/json")
   .content(json.writeValueAsBytes(Map.of("installationId",UUID.randomUUID(),"token",token,"platform","ANDROID")))).andExpect(status().isNoContent());
 }
 @BeforeEach void prepare() {
  when(fcm.send(any(),any(),any(),any())).thenReturn(FcmGateway.Result.SENT);
  when(fcm.send(any(),any(),any(),any(),any())).thenReturn(FcmGateway.Result.SENT);
 }

 @Test void likeRetryUnlikeRelikeAndConcurrentWorkersKeepOneStableReadNotification() throws Exception {
  var owner=user();var a=user();var b=user();long p=post(owner);
  var executor=Executors.newFixedThreadPool(5);
  try {
   var work=new ArrayList<Callable<Object>>();for(int i=0;i<10;i++) work.add(()->feed.set(a.id,p,true,true));
   for(var f:executor.invokeAll(work)) f.get(15,TimeUnit.SECONDS);
  } finally {executor.shutdownNow();}
  var first=notices(owner).get(0);
  assertEquals(1,notices(owner).size());assertEquals("POST_LIKE",first.type());assertEquals(a.id,first.actorId());assertEquals(p,first.postId());
  assertNull(first.invitationId());assertNull(first.commentId());assertEquals(0,notices(a).size());
  inbox.markRead(owner.id,first.id());feed.set(a.id,p,true,false);feed.set(a.id,p,true,true);
  assertEquals(first.id(),notices(owner).get(0).id());assertTrue(notices(owner).get(0).isRead());
  feed.set(b.id,p,true,true);feed.set(owner.id,p,true,true);
  assertEquals(2,notices(owner).size());
 }

 @Test void rootReplyAndReplyToReplyChooseOnlyActualRecipientAndNeverSelf() {
  var owner=user();var a=user();var b=user();long p=post(owner);
  long root=comment(a,p,null);long reply=comment(b,p,root);long nested=comment(owner,p,reply);
  var rootNotice=notices(owner).get(0);assertEquals(root,rootNotice.commentId());assertEquals("POST_COMMENT",rootNotice.type());
  var replyNotice=notices(a).get(0);assertEquals(reply,replyNotice.commentId());assertEquals("POST_REPLY",replyNotice.type());
  var nestedNotice=notices(b).get(0);assertEquals(nested,nestedNotice.commentId());assertEquals("POST_REPLY",nestedNotice.type());
  comment(owner,p,null);comment(a,p,root);comment(b,p,reply);
  assertEquals(1,notices(owner).size());assertEquals(1,notices(a).size());assertEquals(1,notices(b).size());
  assertEquals(root,targets.resolve(b.id,nestedNotice.id()).rootCommentId());
  assertTrue(targets.resolve(b.id,nestedNotice.id()).commentAvailable());
 }

 @Test void concurrentCommentRetryIsOneCommittedEventAndOneComment() throws Exception {
  var owner=user();var a=user();long p=post(owner);var req=request(null);var executor=Executors.newFixedThreadPool(5);
  try {
   var work=new ArrayList<Callable<Map<String,Object>>>();for(int i=0;i<10;i++) work.add(()->comments.create(a.id,p,req));
   var ids=new HashSet<Long>();for(var f:executor.invokeAll(work)) ids.add(((Number)f.get(15,TimeUnit.SECONDS).get("id")).longValue());
   assertEquals(1,ids.size());assertEquals(1,notices(owner).size());
   comments.create(a.id,p,req);assertEquals(1,notices(owner).size());
   assertThrows(ApiException.class,()->comments.create(a.id,p,new CommentDtos.Create(req.clientRequestId(),"changed",null,List.of())));
  } finally {executor.shutdownNow();}
 }

 @Test void noTransportBeforeCommitOrAfterRollbackAndOutageKeepsDurableInbox() {
  var owner=user();var a=user();long p=post(owner);var tx=new TransactionTemplate(transactions);
  clearInvocations(streams,push);
  tx.executeWithoutResult(status->{
   feed.set(a.id,p,true,true);comment(a,p,null);
   verify(streams,never()).publish(eq(owner.id),any());verify(push,never()).enqueue(eq(owner.id),any());
   status.setRollbackOnly();
  });
  assertTrue(notices(owner).isEmpty());verify(streams,never()).publish(eq(owner.id),any());
  doThrow(new IllegalStateException("SSE unavailable")).when(streams).publish(eq(owner.id),any());
  assertDoesNotThrow(()->feed.set(a.id,p,true,true));assertEquals(1,notices(owner).size());
  verify(push).enqueue(eq(owner.id),any());
 }

 @Test void inboxOwnershipFreshPermissionAndDeletedCommentOrPostAreControlled() throws Exception {
  var owner=user();var a=user();long p=post(owner);long root=comment(a,p,null);var n=notices(owner).get(0);
  assertEquals(404,assertThrows(ApiException.class,()->inbox.detail(a.id,n.id())).status);
  mvc.perform(get("/api/v1/notifications/"+n.id()+"/post-target").header("Authorization",a.bearer)).andExpect(status().isNotFound());
  mvc.perform(get("/api/v1/notifications/"+n.id()+"/post-target").header("Authorization",owner.bearer)).andExpect(status().isOk());
  comments.delete(a.id,root);assertFalse(targets.resolve(owner.id,n.id()).commentAvailable());
  assertEquals(p,targets.resolve(owner.id,n.id()).postId());
  posts.delete(owner.id,p);assertEquals(404,assertThrows(ApiException.class,()->targets.resolve(owner.id,n.id())).status);
  assertEquals(n.id(),inbox.detail(owner.id,n.id()).id());
 }

 @Test void replyNotificationDoesNotGrantAccessAfterPrivacyAudienceOrFollowChange() {
  var owner=user();var a=user();long p=post(owner);long root=comment(a,p,null);comment(owner,p,root);var n=notices(a).get(0);
  assertTrue(targets.resolve(a.id,n.id()).commentAvailable());
  users.updateProfile(owner.id,new UserDtos.ProfileUpdate(null,null,null,null,null,true));
  assertEquals(404,assertThrows(ApiException.class,()->targets.resolve(a.id,n.id())).status);
  assertEquals(1,notices(a).size());
  users.updateProfile(owner.id,new UserDtos.ProfileUpdate(null,null,null,null,null,false));
  posts.audience(owner.id,p,"ONLY_ME");assertEquals(404,assertThrows(ApiException.class,()->targets.resolve(a.id,n.id())).status);
  posts.audience(owner.id,p,"EVERYONE");assertTrue(targets.resolve(a.id,n.id()).commentAvailable());
 }

 @Test void readsSavesReportsAndCommentLikesNeverCreateExtraNotifications() {
  var owner=user();var a=user();long p=post(owner);long c=comment(a,p,null);int before=notices(owner).size();
  feed.feed(a.id,20,null);posts.detail(a.id,p);comments.list(a.id,p,null,20,null);
  feed.set(a.id,p,false,true);feed.set(a.id,p,false,false);comments.like(owner.id,c,true);comments.like(owner.id,c,false);
  inbox.list(owner.id,0,30);assertEquals(before,notices(owner).size());
 }

 @Test void likeHasSseButNeverFcmAndCommentReplyUseGenericSocialChannelAndExistingEligibility() throws Exception {
  var owner=user();var a=user();long p=post(owner);String token="social-"+UUID.randomUUID();register(owner,token);
  feed.set(a.id,p,true,true);var like=notices(owner).get(0);
  verify(streams).publish(eq(owner.id),argThat(s->like.id().equals(s.notificationId())));
  verify(fcm,after(250).never()).send(any(),eq(owner.id),eq(like.id()),any());
  verify(fcm,never()).send(any(),eq(owner.id),eq(like.id()),any(),any());
  long root=comment(a,p,null);var n=notices(owner).stream().filter(i->"POST_COMMENT".equals(i.type())).findFirst().orElseThrow();
  await().atMost(Duration.ofSeconds(3)).untilAsserted(()->verify(fcm).send(eq(token),eq(owner.id),eq(n.id()),eq("Bạn có bình luận mới"),eq("gomate_social_v1")));
  assertFalse(n.message().contains("Private"));assertNull(n.tripId());
  register(a,"reply-"+token);long reply=comment(owner,p,root);var r=notices(a).get(0);
  await().atMost(Duration.ofSeconds(3)).untilAsserted(()->verify(fcm).send(any(),eq(a.id),eq(r.id()),eq("Bạn có phản hồi bình luận mới"),eq("gomate_social_v1")));
  db.update("UPDATE user_settings SET notifications_enabled=FALSE WHERE user_id=:id",args("id",owner.id));
  comment(a,p,null);var disabled=notices(owner).stream().filter(i->"POST_COMMENT".equals(i.type()) && !n.id().equals(i.id())).findFirst().orElseThrow();
  verify(fcm,after(250).never()).send(any(),any(),eq(disabled.id()),any(),any());
  assertEquals(3,notices(owner).size());assertEquals(reply,r.commentId());
 }

 @Test void globalBlockDropsQueuedSocialDeliveryAndHistoricalTapRechecksCurrentAccess() throws Exception {
  var owner=user();var actor=user();long p=post(owner);comment(actor,p,null);
  var notice=notices(owner).get(0);
  // Register after initial event so only our explicit replay can attempt delivery.
  register(owner,"block-queued-"+UUID.randomUUID());
  mvc.perform(put("/api/v1/users/"+actor.id+"/block").header("Authorization",owner.bearer)).andExpect(status().isOk());
  var signal=new NotificationSignal(UUID.randomUUID(),"CREATED",notice.id(),java.time.Instant.now());
  org.springframework.test.util.ReflectionTestUtils.invokeMethod(push,"deliver",owner.id,signal);
  verify(fcm,never()).send(any(),eq(owner.id),eq(notice.id()),any(),any());
  assertEquals(notice.id(),inbox.detail(owner.id,notice.id()).id());
  assertEquals(404,assertThrows(ApiException.class,()->targets.resolve(actor.id,notice.id())).status);
  var stream=mvc.perform(get("/api/v1/notifications/stream").header("Authorization",owner.bearer)).andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.request().asyncStarted()).andReturn();
  streams.publish(owner.id,signal);
  // A later ordinary UPDATED event provides a FIFO transport completion barrier.
  var barrier=new NotificationSignal(UUID.randomUUID(),"ACCESS_CHANGED",null,java.time.Instant.now());
  streams.publish(owner.id,barrier);
  await().atMost(Duration.ofSeconds(3)).until(()->stream.getResponse().getContentAsString().contains(barrier.eventId().toString()));
  assertFalse(stream.getResponse().getContentAsString().contains(notice.id().toString()));
  stream.getRequest().getAsyncContext().complete();
 }

 @Test void fcmFailureReadSyncAndIdempotentNotificationRaceKeepRows() throws Exception {
  var owner=user();var a=user();long p=post(owner);String token="outage-"+UUID.randomUUID();register(owner,token);
  when(fcm.send(eq(token),any(),any(),any(),any())).thenThrow(new IllegalStateException("FCM down"));
  comment(a,p,null);var n=notices(owner).get(0);
  await().atMost(Duration.ofSeconds(3)).untilAsserted(()->verify(fcm).send(eq(token),eq(owner.id),eq(n.id()),any(),any()));
  mvc.perform(patch("/api/v1/notifications/"+n.id()+"/read").header("Authorization",a.bearer)).andExpect(status().isNotFound());
  inbox.markRead(owner.id,n.id());assertEquals(0,inbox.list(owner.id,0,30).unreadCount());
  assertTrue(inbox.detail(owner.id,n.id()).isRead());
  verify(streams).publish(eq(owner.id),argThat(s->"UPDATED".equals(s.eventKind()) && n.id().equals(s.notificationId())));
  var executor=Executors.newFixedThreadPool(4);
  try {
   var tasks=new ArrayList<Callable<Object>>();for(int i=0;i<8;i++) tasks.add(()->{inbox.recordPostInteraction(owner.id,a.id,p,null,false);return null;});
   for(var result:executor.invokeAll(tasks)) result.get(10,TimeUnit.SECONDS);
  } finally {executor.shutdownNow();}
  assertEquals(2,notices(owner).size());
 }
}
