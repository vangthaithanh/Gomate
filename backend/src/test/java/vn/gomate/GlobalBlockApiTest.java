package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.relationship.block.*;
import vn.gomate.relationship.service.SocialRelationshipService;
import vn.gomate.message.service.*;
import vn.gomate.social.post.*;
import vn.gomate.social.comment.*;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class GlobalBlockApiTest {
 @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired AuthService auth; @Autowired Db db;
 @Autowired GlobalBlockService blocks; @Autowired GlobalBlockPolicy policy;
 @Autowired SocialRelationshipService relationships; @Autowired PostService posts;
 @Autowired PostFeedService feed; @Autowired CommentService comments; @Autowired PostActivityService activity;
 @Autowired ConversationService chats;
 @Autowired vn.gomate.message.repository.ConversationRepository chatRows;
 @Autowired vn.gomate.notification.service.NotificationService inbox;
 @MockitoBean MessageMongoService messages;
 record User(UUID id,String token,String name) {}
 User user() {String name="block_"+UUID.randomUUID().toString().replace("-","").substring(0,15);var s=auth.register(new AuthDtos.Register(name+"@example.invalid","TestPass123!",name));return new User((UUID)((Map<?,?>)s.get("user")).get("id"),"Bearer "+s.get("accessToken"),name);}
 JsonNode call(MockHttpServletRequestBuilder r,User u,Object body,int status) throws Exception {
  r.header("Authorization",u.token);if(body!=null) r.contentType("application/json").content(json.writeValueAsBytes(body));
  var response=mvc.perform(r).andExpect(status().is(status)).andReturn().getResponse();return response.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(response.getContentAsByteArray());
 }
 String block(User u) {return "/api/v1/users/"+u.id+"/block";}
 long seedPost(User u) {UUID media=UUID.randomUUID();db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,'hash','IMAGE','READY',:pid,:thumb,'png','image/png',4,2,2)",args("id",media,"owner",u.id,"pid",media.toString(),"thumb",media+"_cover"));return posts.publish(u.id,new PostDtos.Publish(UUID.randomUUID(),"GlobalBlockFixture","EVERYONE",new ArrayList<>(List.of(media)),List.of("blockfixture"),new ArrayList<>(),null)).id();}
 @Test void directedIdempotentAndPrincipalOnlyWithSafeProfileShell() throws Exception {
  var a=user();var b=user();var c=user();
  mvc.perform(put(block(b))).andExpect(status().isUnauthorized());
  call(put(block(a)),a,null,400);call(put("/api/v1/users/"+UUID.randomUUID()+"/block"),a,null,404);
  call(put(block(b)),a,Map.of("actorId",c.id),200);call(put(block(b)),a,null,200);
  assertTrue(policy.byMe(a.id,b.id));assertFalse(policy.byMe(c.id,b.id));
  assertEquals(1,call(get("/api/v1/users/me/blocked"),a,null,200).path("total").asInt());
  var shell=call(get("/api/v1/users/"+b.id),a,null,200);assertTrue(shell.path("isBlockedByMe").asBoolean());assertTrue(shell.path("bio").isNull());
  call(get("/api/v1/users/"+a.id),b,null,404);
  assertEquals(0,call(get("/api/v1/users/search?q="+a.name),b,null,200).path("total").asInt());
  call(put(block(a)),b,null,200);call(delete(block(b)),a,null,200);
  assertFalse(policy.byMe(a.id,b.id));assertTrue(policy.byMe(b.id,a.id));call(get("/api/v1/users/"+b.id),a,null,404);
  call(delete(block(a)),b,null,200);call(get("/api/v1/users/"+a.id),b,null,200);
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",c.id));call(put(block(c)),a,null,404);
 }
 @Test void followsRevokedPendingCancelledAndNeverRestored() throws Exception {
  var a=user();var b=user();relationships.follow(a.id,b.id);relationships.follow(b.id,a.id);
  blocks.set(a.id,b.id,true);assertFalse(relationships.isMutualFriend(a.id,b.id));
  assertEquals(404,assertThrows(ApiException.class,()->relationships.follow(b.id,a.id)).status);
  blocks.set(a.id,b.id,false);assertFalse(relationships.isFollowing(a.id,b.id));assertFalse(relationships.isFollowing(b.id,a.id));
  db.update("UPDATE user_settings SET account_visibility='PRIVATE' WHERE user_id=:id",args("id",b.id));relationships.follow(a.id,b.id);
  UUID request=(UUID)db.one("SELECT id FROM follow_requests WHERE requester_id=:a AND target_id=:b AND status='PENDING'",args("a",a.id,"b",b.id)).get("id");
  blocks.set(b.id,a.id,true);assertEquals("CANCELLED",db.one("SELECT status FROM follow_requests WHERE id=:id",args("id",request)).get("status"));
  assertEquals(404,assertThrows(ApiException.class,()->relationships.respond(b.id,request,true)).status);
  blocks.set(b.id,a.id,false);assertFalse(relationships.isFollowing(a.id,b.id));
 }
 @Test void directFacadeAndGlobalApiAreSameTruthWithoutLegacyVeto() throws Exception {
  var a=user();var b=user();relationships.follow(a.id,b.id);relationships.follow(b.id,a.id);
  when(messages.list(any(),anyInt(),nullable(String.class))).thenReturn(List.of());
  UUID id=UUID.randomUUID();UUID low=a.id.compareTo(b.id)<0?a.id:b.id,high=low.equals(a.id)?b.id:a.id;
  db.update("INSERT INTO conversations(id,type,status,user_low_id,user_high_id,requester_id,recipient_id,created_by) VALUES(:id,'DIRECT','ACCEPTED',:low,:high,:a,:b,:a)",args("id",id,"low",low,"high",high,"a",a.id,"b",b.id));
  for(var u:List.of(a,b)) db.update("INSERT INTO conversation_members(conversation_id,user_id,role,status,blocked) VALUES(:id,:u,'MEMBER','ACTIVE',TRUE)",args("id",id,"u",u.id));
  // Old physical flags intentionally TRUE: new authority must ignore them after migration.
  call(post("/api/v1/conversations/"+id+"/block"),a,null,200);
  assertTrue(policy.byMe(a.id,b.id));assertTrue(call(get("/api/v1/users/"+b.id),a,null,200).path("isBlockedByMe").asBoolean());
  var peer=call(get("/api/v1/conversations/"+id),b,null,200).path("conversation");assertFalse(peer.has("blockedByPeer"));assertFalse(peer.path("canSend").asBoolean());
  call(delete(block(b)),a,null,200);assertFalse(policy.either(a.id,b.id));
  assertTrue(call(get("/api/v1/conversations/"+id),b,null,200).path("conversation").path("canSend").asBoolean());
  call(put(block(a)),b,null,200);call(delete("/api/v1/conversations/"+id+"/block"),a,null,200);assertTrue(policy.byMe(b.id,a.id));
  assertEquals(2,db.count("SELECT COUNT(*) FROM conversation_members WHERE conversation_id=:id AND blocked=TRUE",args("id",id)));
  assertEquals("ACCEPTED",db.one("SELECT status FROM conversations WHERE id=:id",args("id",id)).get("status"));
 }
 @Test void pendingDirectStaysPendingUntilRecipientExplicitlyAcceptsAfterGlobalUnblock() throws Exception {
  var a=user();var b=user();UUID id=UUID.randomUUID();
  UUID low=a.id.compareTo(b.id)<0?a.id:b.id,high=low.equals(a.id)?b.id:a.id;
  chatRows.createDirect(id,a.id,b.id,low,high,"PENDING");
  blocks.set(a.id,b.id,true);
  assertEquals(403,assertThrows(ApiException.class,()->chats.accept(id,b.id)).status);
  assertEquals("PENDING",db.one("SELECT status FROM conversations WHERE id=:id",args("id",id)).get("status"));
  assertFalse(call(get("/api/v1/conversations/"+id),b,null,200).path("conversation").path("canAccept").asBoolean());
  blocks.set(a.id,b.id,false);
  assertEquals("PENDING",db.one("SELECT status FROM conversations WHERE id=:id",args("id",id)).get("status"));
  assertTrue(call(get("/api/v1/conversations/"+id),b,null,200).path("conversation").path("canAccept").asBoolean());
  assertEquals("ACCEPTED",chats.accept(id,b.id).status());assertFalse(relationships.isMutualFriend(a.id,b.id));
 }
 @Test void postReadFeedSearchActivityAndBinaryRangeDenyBothWaysWithoutDeletingHistory() throws Exception {
  var a=user();var b=user();long id=seedPost(a);feed.set(b.id,id,true,true);feed.set(b.id,id,false,true);
  long comment=((Number)comments.create(b.id,id,new CommentDtos.Create(UUID.randomUUID(),"Historical comment",null,List.of())).get("id")).longValue();
  UUID media=(UUID)db.one("SELECT id FROM post_media WHERE post_id=:id",args("id",id)).get("id");
  blocks.set(a.id,b.id,true);
  for(String path:List.of("/posts/"+id,"/users/"+a.id+"/posts","/posts/"+id+"/media/"+media,"/posts/"+id+"/media/"+media+"/thumbnail","/posts/"+id+"/comments","/posts/"+id+"/likes")) call(get("/api/v1"+path).header("Range","bytes=0-1"),b,null,404);
  call(put("/api/v1/posts/"+id+"/like"),b,null,404);call(put("/api/v1/posts/"+id+"/save"),b,null,404);
  assertTrue(feed.feed(b.id,50,null).items().stream().noneMatch(p->p.id()==id));
  assertTrue(java.util.stream.StreamSupport.stream(call(get("/api/v1/search/posts?q=GlobalBlockFixture"),b,null,200).path("items").spliterator(),false).noneMatch(item->item.path("id").asLong()==id));
  assertTrue(activity.list(b.id,"COMMENTS",50,null).items().isEmpty());
  assertEquals(1,db.count("SELECT COUNT(*) FROM comments WHERE id=:id AND publication_status='ACTIVE'",args("id",comment)));
  assertEquals(1,db.count("SELECT COUNT(*) FROM post_likes WHERE user_id=:u AND post_id=:p",args("u",b.id,"p",id)));
  blocks.set(a.id,b.id,false);assertEquals(id,posts.detail(b.id,id).id());
 }
 @Test void thirdPartyThreadsLikersAndTagsRespectViewerBlockWithoutErasingData() throws Exception {
  var a=user();var b=user();var c=user();long id=seedPost(c);feed.set(b.id,id,true,true);
  long root=((Number)comments.create(b.id,id,new CommentDtos.Create(UUID.randomUUID(),"Root by B",null,List.of())).get("id")).longValue();
  comments.create(c.id,id,new CommentDtos.Create(UUID.randomUUID(),"Reply by C",root,List.of()));
  blocks.set(a.id,b.id,true);
  assertTrue(comments.list(a.id,id,null,20,null).items().isEmpty());assertTrue(feed.likers(a.id,id,20,null).items().isEmpty());
  assertEquals(404,assertThrows(ApiException.class,()->comments.authorize(a.id,root)).status);
  assertEquals(0,posts.detail(a.id,id).commentCount());assertEquals(2,posts.detail(c.id,id).commentCount());
  assertEquals(2,db.count("SELECT COUNT(*) FROM comments WHERE post_id=:id",args("id",id)));
 }
 @Test void noNewInteractionNotificationWhileBlockedAndNoUnblockBackfill() {
  var a=user();var b=user();long id=seedPost(a);blocks.set(a.id,b.id,true);
  inbox.recordPostInteraction(a.id,b.id,id,null,false);
  inbox.recordPostInteraction(b.id,a.id,id,null,false);
  assertEquals(0,db.count("SELECT COUNT(*) FROM notifications WHERE actor_id IN (:ids)",args("ids",List.of(a.id,b.id))));
  blocks.set(a.id,b.id,false);assertEquals(0,db.count("SELECT COUNT(*) FROM notifications WHERE actor_id IN (:ids)",args("ids",List.of(a.id,b.id))));
 }
 @Test void blockRacingFollowCannotResurrectAnEdge() throws Exception {
  var a=user();var b=user();var pool=Executors.newFixedThreadPool(4);
  try {var tasks=new ArrayList<Callable<Void>>();for(int i=0;i<12;i++){boolean block=i%2==0;tasks.add(()->{if(block) blocks.set(a.id,b.id,true);else try{relationships.follow(b.id,a.id);}catch(ApiException e){assertEquals(404,e.status);}return null;});}for(var result:pool.invokeAll(tasks))result.get(15,TimeUnit.SECONDS);assertTrue(policy.either(a.id,b.id));assertFalse(relationships.isFollowing(b.id,a.id));}finally{pool.shutdownNow();}
 }
}
