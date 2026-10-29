package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.social.post.*;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PostFeedApiTest {
 @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired AuthService auth; @Autowired Db db;
 @Autowired vn.gomate.relationship.service.SocialRelationshipService relationships;
 @Autowired vn.gomate.user.service.UserService users;
 @Autowired PostService posts; @Autowired PostFeedService feeds;
 @org.springframework.test.context.bean.override.mockito.MockitoSpyBean PostFeedRepository readRepo;
 record User(UUID id,String token) {}
 User user() {var key="feed"+UUID.randomUUID().toString().replace("-","").substring(0,15);var s=auth.register(new AuthDtos.Register(key+"@example.com","TestPass123!",key));return new User((UUID)((Map<?,?>)s.get("user")).get("id"),"Bearer "+s.get("accessToken"));}
 JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,User u,int expected) throws Exception {
  var response=mvc.perform(req.header("Authorization",u.token)).andExpect(status().is(expected)).andReturn().getResponse();
  return response.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(response.getContentAsByteArray());
 }
 long post(User u,String audience) {
  var media=UUID.randomUUID();
  db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,'hash','IMAGE','READY',:pid,:thumb,'png','image/png',4,2,2)",args("id",media,"owner",u.id,"pid",media.toString(),"thumb",media+"_cover"));
  long id=posts.publish(u.id,new PostDtos.Publish(UUID.randomUUID(),"P2 test",audience,Arrays.asList(media),List.of("Dalat"),new ArrayList<>(),null)).id();
  db.update("UPDATE posts SET created_at=:time WHERE id=:id",args("id",id,"time",OffsetDateTime.now(ZoneOffset.UTC).plusYears(50)));
  return id;
 }
 Set<Long> ids(User u) {return feeds.feed(u.id,50,null).items().stream().map(PostDtos.Detail::id).collect(java.util.stream.Collectors.toSet());}
 void privacy(User u,boolean value) {users.updateProfile(u.id,new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,null,null,null,null,value));}
 @Test void likersShowCurrentPublicNamesAndReadDoesNotWriteOrNotify() throws Exception {
  var owner=user();var a=user();var viewer=user();long id=post(owner,"EVERYONE");
  var empty=call(get("/api/v1/posts/"+id+"/likes"),viewer,200);assertEquals(0,empty.get("items").size());
  feeds.set(a.id,id,true,true);
  db.update("UPDATE user_profiles SET full_name='Xuân Thu' WHERE user_id=:id",args("id",a.id));
  long notices=db.count("SELECT COUNT(*) FROM notifications",Map.of());
  var page=call(get("/api/v1/posts/"+id+"/likes"),viewer,200);
  assertEquals(1,page.get("items").size());assertEquals(a.id.toString(),page.get("items").get(0).get("userId").asText());
  assertEquals("Xuân Thu",page.get("items").get(0).get("displayName").asText());
  assertFalse(page.toString().contains("email"));assertFalse(page.toString().contains("password"));
  assertEquals(notices,db.count("SELECT COUNT(*) FROM notifications",Map.of()));
  feeds.set(a.id,id,true,false);assertTrue(feeds.likers(viewer.id,id,20,null).items().isEmpty());
  mvc.perform(get("/api/v1/posts/"+id+"/likes")).andExpect(status().isUnauthorized());
 }
 @Test void likersCursorBindsViewerAndPostAndTiedTimesHaveNoDuplicates() throws Exception {
  var owner=user();var viewer=user();var other=user();long id=post(owner,"EVERYONE"),different=post(owner,"EVERYONE");
  for(int i=0;i<4;i++) feeds.set(user().id,id,true,true);
  db.update("UPDATE post_likes SET created_at=:time WHERE post_id=:id",args("time",OffsetDateTime.parse("2026-10-23T00:00:00Z"),"id",id));
  var first=feeds.likers(viewer.id,id,1,null);assertNotNull(first.nextCursor());
  var seen=new HashSet<UUID>();String cursor=null;
  do {var page=feeds.likers(viewer.id,id,1,cursor);assertTrue(seen.add(page.items().get(0).userId()));cursor=page.nextCursor();} while(cursor!=null);
  assertEquals(4,seen.size());
  assertEquals(400,assertThrows(ApiException.class,()->feeds.likers(other.id,id,1,first.nextCursor())).status);
  assertEquals(400,assertThrows(ApiException.class,()->feeds.likers(viewer.id,different,1,first.nextCursor())).status);
  for(String suffix:List.of("?size=0","?size=51","?cursor=bad")) call(get("/api/v1/posts/"+id+"/likes"+suffix),viewer,400);
 }
 @Test void likersRecheckAudiencePrivacyPendingAcceptedAndDeletedPost() throws Exception {
  var owner=user();var liker=user();var viewer=user();long id=post(owner,"EVERYONE");feeds.set(liker.id,id,true,true);
  privacy(owner,true);relationships.follow(viewer.id,owner.id);
  call(get("/api/v1/posts/"+id+"/likes"),viewer,404);
  var req=relationships.requests(owner.id,0,50).items().stream().filter(r->r.requesterId().equals(viewer.id)).findFirst().orElseThrow();
  relationships.respond(owner.id,req.id(),true);assertEquals(1,feeds.likers(viewer.id,id,20,null).items().size());
  relationships.unfollow(viewer.id,owner.id);call(get("/api/v1/posts/"+id+"/likes"),viewer,404);
  privacy(owner,false);posts.audience(owner.id,id,"ONLY_ME");call(get("/api/v1/posts/"+id+"/likes"),viewer,404);
  assertEquals(1,feeds.likers(owner.id,id,20,null).items().size());posts.delete(owner.id,id);
  call(get("/api/v1/posts/"+id+"/likes"),owner,404);
 }
 @Test void globalEligibilityMatchesPrivacyFollowAndDeletion() throws Exception {
  var owner=user();var follower=user();var friend=user();var pending=user();var stranger=user();
  relationships.follow(follower.id,owner.id);relationships.follow(friend.id,owner.id);relationships.follow(owner.id,friend.id);
  long everyone=post(owner,"EVERYONE"),friends=post(owner,"FRIENDS"),only=post(owner,"ONLY_ME");
  assertTrue(ids(stranger).contains(everyone));assertFalse(ids(stranger).contains(friends));assertTrue(ids(owner).containsAll(Set.of(everyone,friends,only)));
  privacy(owner,true);relationships.follow(pending.id,owner.id);
  long privatePost=post(owner,"FOLLOWERS");
  for(var viewer:List.of(stranger,pending)) {
   assertFalse(ids(viewer).contains(everyone));assertFalse(ids(viewer).contains(privatePost));
   call(get("/api/v1/posts/"+everyone),viewer,404);
   call(put("/api/v1/posts/"+everyone+"/like"),viewer,404);
   call(put("/api/v1/posts/"+everyone+"/save"),viewer,404);
  }
  assertTrue(ids(follower).containsAll(Set.of(everyone,privatePost)));assertFalse(ids(follower).contains(friends));assertTrue(ids(friend).contains(friends));
  var request=relationships.requests(owner.id,0,50).items().stream().filter(r->r.requesterId().equals(pending.id)).findFirst().orElseThrow();
  relationships.respond(owner.id,request.id(),true);assertTrue(ids(pending).contains(privatePost));
  relationships.unfollow(follower.id,owner.id);assertFalse(ids(follower).contains(privatePost));
  for(int i=0;i<3;i++) {privacy(owner,false);assertTrue(ids(stranger).contains(privatePost));privacy(owner,true);assertFalse(ids(stranger).contains(privatePost));}
  posts.audience(owner.id,privatePost,"ONLY_ME");assertFalse(ids(friend).contains(privatePost));
  posts.delete(owner.id,everyone);assertFalse(ids(owner).contains(everyone));
  var media=db.one("SELECT id FROM post_media WHERE post_id=:id",args("id",everyone)).get("id");
  call(get("/api/v1/posts/"+everyone+"/media/"+media+"/thumbnail"),owner,404);
 }
 @Test void keysetTieOrderIgnoresPinsAndNewerInsertDoesNotDuplicatePages() throws Exception {
  var owner=user();var other=user();
  var time=OffsetDateTime.now(ZoneOffset.UTC).plusYears(100);
  var expected=new ArrayList<Long>();
  for(int i=0;i<5;i++) {long id=post(owner,"EVERYONE");expected.add(id);db.update("UPDATE posts SET created_at=:time WHERE id=:id",args("id",id,"time",time));}
  Collections.reverse(expected);posts.pin(owner.id,expected.get(4),true);
  var first=feeds.feed(other.id,2,null);assertEquals(expected.subList(0,2),first.items().stream().map(PostDtos.Detail::id).toList());
  long newer=post(owner,"EVERYONE");db.update("UPDATE posts SET created_at=:time WHERE id=:id",args("id",newer,"time",time.plusDays(1)));
  var second=feeds.feed(other.id,2,first.nextCursor());
  var third=feeds.feed(other.id,1,second.nextCursor());
  var actual=new ArrayList<Long>();for(var page:List.of(first,second,third)) page.items().forEach(p->actual.add(p.id()));
  assertEquals(expected,actual);assertEquals(newer,feeds.feed(other.id,1,null).items().get(0).id());
  call(get("/api/v1/feed?cursor="+first.nextCursor()),owner,400);
  call(get("/api/v1/feed?cursor=bad"),owner,400);call(get("/api/v1/feed?size=0"),owner,400);call(get("/api/v1/feed?size=51"),owner,400);
  mvc.perform(get("/api/v1/feed")).andExpect(status().isUnauthorized());
 }
 @Test void likeSaveAreIdempotentPersistentScopedAndOnlyLikeNotifiesOnce() throws Exception {
  var owner=user();var a=user();var b=user();long id=post(owner,"EVERYONE");String path="/api/v1/posts/"+id;
  long notifications=db.count("SELECT COUNT(*) FROM notifications",Map.of());
  for(int i=0;i<2;i++) {assertTrue(call(put(path+"/like"),a,200).get("likedByMe").asBoolean());call(put(path+"/save"),a,200);}
  var other=call(get(path),b,200);assertEquals(1,other.get("likeCount").asInt());assertFalse(other.get("savedByMe").asBoolean());assertFalse(other.get("likedByMe").asBoolean());
  var mine=call(get(path),a,200);assertTrue(mine.get("likedByMe").asBoolean());assertTrue(mine.get("savedByMe").asBoolean());
  privacy(owner,true);call(delete(path+"/like"),a,404);call(delete(path+"/save"),a,404);
  assertEquals(1,db.count("SELECT COUNT(*) FROM post_saves WHERE post_id=:id",args("id",id)));
  privacy(owner,false);assertTrue(call(get(path),a,200).get("savedByMe").asBoolean());
  for(int i=0;i<2;i++) {call(delete(path+"/like"),a,200);call(delete(path+"/save"),a,200);}
  assertEquals(0,call(get(path),a,200).get("likeCount").asInt());
  assertEquals(notifications+1,db.count("SELECT COUNT(*) FROM notifications",Map.of()));
  call(put("/api/v1/posts/9223372036854775807/like"),a,404);
  mvc.perform(put(path+"/like")).andExpect(status().isUnauthorized());
  assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->db.update("INSERT INTO post_likes(post_id,user_id) VALUES(-1,:user)",args("user",a.id)));
 }
 @Test void concurrentRetryDoesNotDuplicateOrInflateCount() throws Exception {
  var owner=user();var viewer=user();long id=post(owner,"EVERYONE");var executor=Executors.newFixedThreadPool(6);
  try {
   var work=new ArrayList<Callable<PostDtos.Engagement>>();for(int i=0;i<12;i++) work.add(()->feeds.set(viewer.id,id,true,true));
   for(var result:executor.invokeAll(work)) assertEquals(1,result.get(10,TimeUnit.SECONDS).likeCount());
   assertEquals(1,db.count("SELECT COUNT(*) FROM post_likes WHERE post_id=:id",args("id",id)));
   work.clear();for(int i=0;i<12;i++) work.add(()->feeds.set(viewer.id,id,false,true));
   for(var result:executor.invokeAll(work)) assertTrue(result.get(10,TimeUnit.SECONDS).savedByMe());
   assertEquals(1,db.count("SELECT COUNT(*) FROM post_saves WHERE post_id=:id",args("id",id)));
  } finally {executor.shutdownNow();}
 }
 @Test @org.springframework.transaction.annotation.Transactional
 void emptyStateAndFilteringBeforeLimitDoNotExposeHiddenCounts() throws Exception {
  db.update("UPDATE posts SET audience='ONLY_ME'",Map.of());
  var viewer=user();
  var empty=call(get("/api/v1/feed"),viewer,200);
  assertEquals(0,empty.get("items").size());assertTrue(empty.get("nextCursor").isNull());assertFalse(empty.has("total"));
  var owner=user();long hidden=post(owner,"ONLY_ME"),visible=post(owner,"EVERYONE");
  db.update("UPDATE posts SET created_at=:time WHERE id=:id",args("time",OffsetDateTime.now().plusYears(150),"id",hidden));
  var page=call(get("/api/v1/feed?size=1"),viewer,200);
  assertEquals(visible,page.get("items").get(0).get("id").asLong());assertTrue(page.get("nextCursor").isNull());
 }
 @Test void batchingHasFixedQueryCountAndRechecksRightsAfterDataReads() {
  var owner=user();var viewer=user();long id=post(owner,"EVERYONE");
  org.mockito.Mockito.clearInvocations(readRepo);
  var page=feeds.feed(viewer.id,20,null);
  org.mockito.Mockito.verify(readRepo,org.mockito.Mockito.times(1)).page(org.mockito.ArgumentMatchers.eq(viewer.id),org.mockito.ArgumentMatchers.eq(21),org.mockito.ArgumentMatchers.isNull());
  org.mockito.Mockito.verify(readRepo,org.mockito.Mockito.times(1)).media(org.mockito.ArgumentMatchers.anyList());
  org.mockito.Mockito.verify(readRepo,org.mockito.Mockito.times(1)).tags(org.mockito.ArgumentMatchers.anyList());
  org.mockito.Mockito.verify(readRepo,org.mockito.Mockito.times(1)).people(org.mockito.ArgumentMatchers.eq(viewer.id),org.mockito.ArgumentMatchers.anyList());
  org.mockito.Mockito.verify(readRepo,org.mockito.Mockito.times(1)).engagements(org.mockito.ArgumentMatchers.eq(viewer.id),org.mockito.ArgumentMatchers.anyList());
  org.mockito.Mockito.verify(readRepo,org.mockito.Mockito.times(1)).visible(org.mockito.ArgumentMatchers.eq(viewer.id),org.mockito.ArgumentMatchers.anyList());
  assertFalse(page.items().isEmpty());
  org.mockito.Mockito.doAnswer(invocation->{var result=invocation.callRealMethod();privacy(owner,true);return result;})
   .when(readRepo).media(org.mockito.ArgumentMatchers.anyList());
  assertFalse(feeds.feed(viewer.id,50,null).items().stream().anyMatch(p->p.id()==id));
 }
}
