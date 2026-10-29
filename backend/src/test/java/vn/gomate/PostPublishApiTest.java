package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.util.*;
import java.io.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.mock.web.MockMultipartFile;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.social.post.*;
import vn.gomate.media.provider.ProtectedMediaOrigin;
import vn.gomate.media.service.MediaService;
import vn.gomate.media.dto.MediaUploadResult;
import vn.gomate.media.model.MediaResourceType;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PostPublishApiTest {
 @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired AuthService auth; @Autowired Db db;
 @Autowired vn.gomate.relationship.service.SocialRelationshipService relationships;
 @Autowired vn.gomate.user.service.UserService users;
 @Autowired PostService posts;
 @Autowired PostMediaService postMedia;
 @org.springframework.test.context.bean.override.mockito.MockitoSpyBean PostRepository postRepository;
 @MockitoBean ProtectedMediaOrigin origin;
 @MockitoBean MediaService media;
 @MockitoBean PostFileInspector inspector;
 record User(UUID id,String token) {}
 User user() {String key="post"+UUID.randomUUID().toString().replace("-","").substring(0,15);var s=auth.register(new AuthDtos.Register(key+"@example.com","TestPass123!",key));return new User((UUID)((Map<?,?>)s.get("user")).get("id"),"Bearer "+s.get("accessToken"));}
 UUID asset(User u,String kind) {
  UUID id=UUID.randomUUID();db.update("""
   INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,duration_ms,width,height)
   VALUES(:id,:owner,'hash',:kind,'READY',:pid,:thumb,'png',:mime,4,:duration,2,2)
   """,args("id",id,"owner",u.id,"kind",kind,"pid",id.toString(),"thumb",id+"_cover","mime",kind.equals("VIDEO")?"video/mp4":"image/png","duration",kind.equals("VIDEO")?30000:null));return id;
 }
 Map<String,Object> body(User u,String audience,int count) {
  var m=new LinkedHashMap<String,Object>();m.put("clientRequestId",UUID.randomUUID());m.put("caption","Đà Lạt 🌸\nDòng hai");m.put("audience",audience);m.put("mediaIds",java.util.stream.IntStream.range(0,count).mapToObj(i->asset(u,i%2==0?"IMAGE":"VIDEO")).toList());m.put("hashtags",List.of("#ĐàLạt","đàlạt"));m.put("taggedUserIds",List.of());return m;
 }
 JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,User u,Object body,int expected) throws Exception {
  req.header("Authorization",u.token);if(body!=null)req.contentType("application/json").content(json.writeValueAsBytes(body));
  var response=mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse();return response.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(response.getContentAsByteArray());
 }
 void privacy(User u,boolean value) {users.updateProfile(u.id,new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,null,null,null,null,value));}
 void binary(User u,JsonNode post,boolean allowed) throws Exception {
  String path="/api/v1"+post.get("media").get(0).get("url").asText();
  when(media.protectedDownload(anyString(),anyString(),any())).thenReturn("https://api.cloudinary.com/test");
  when(origin.open(anyString(),nullable(String.class))).thenAnswer(i->new ProtectedMediaOrigin.Body(new ByteArrayInputStream(new byte[]{1,2,3,4}),4,0,()->{}));
  mvc.perform(get(path).header("Authorization",u.token)).andExpect(status().is(allowed?200:404));
  mvc.perform(get(path+"/thumbnail").header("Authorization",u.token)).andExpect(status().is(allowed?200:404));
  if(allowed) mvc.perform(get(path).header("Authorization",u.token).header("Range","bytes=9-12"))
   .andExpect(status().isRequestedRangeNotSatisfiable()).andExpect(header().string("Content-Range","bytes */4"));
 }
 @Test void mediaCountOrderUnicodeTagsAndIdempotentCommit() throws Exception {
  var owner=user();var b=body(owner,"EVERYONE",12);
  var p=call(post("/api/v1/posts"),owner,b,201);
  assertEquals(b.get("caption"),p.get("caption").asText());assertEquals(12,p.get("media").size());assertEquals(1,p.get("hashtags").size());
  for(int i=0;i<12;i++){assertEquals(((List<?>)b.get("mediaIds")).get(i).toString(),p.get("media").get(i).get("id").asText());assertEquals(i,p.get("media").get(i).get("sortOrder").asInt());}
  assertEquals(p.get("id"),call(post("/api/v1/posts"),owner,b,201).get("id"));
  b.put("caption","Changed");call(post("/api/v1/posts"),owner,b,409);
  call(post("/api/v1/posts"),owner,body(owner,"EVERYONE",0),400);
  call(post("/api/v1/posts"),owner,body(owner,"EVERYONE",13),400);
 }
 @Test void audienceMatrixUsesAcceptedEdgesAndProtectsOriginalAndThumbnail() throws Exception {
  var owner=user();var follower=user();var friend=user();var pending=user();var stranger=user();
  relationships.follow(follower.id,owner.id);relationships.follow(friend.id,owner.id);relationships.follow(owner.id,friend.id);
  var account=call(post("/api/v1/posts"),owner,body(owner,"EVERYONE",1),201);
  var friends=call(post("/api/v1/posts"),owner,body(owner,"FRIENDS",1),201);
  var only=call(post("/api/v1/posts"),owner,body(owner,"ONLY_ME",1),201);
  privacy(owner,true);relationships.follow(pending.id,owner.id);
  call(post("/api/v1/posts"),owner,body(owner,"EVERYONE",1),422);
  var privatePost=call(post("/api/v1/posts"),owner,body(owner,"FOLLOWERS",1),201);
  for(var viewer:List.of(owner,follower,friend,pending,stranger)) {
   boolean accepted=viewer==owner || viewer==follower || viewer==friend;
   for(var p:List.of(account,privatePost)) {
    call(get("/api/v1/posts/"+p.get("id").asText()),viewer,null,accepted?200:404);binary(viewer,p,accepted);
   }
   boolean mutual=viewer==owner || viewer==friend;
   call(get("/api/v1/posts/"+friends.get("id").asText()),viewer,null,mutual?200:404);binary(viewer,friends,mutual);
   call(get("/api/v1/posts/"+only.get("id").asText()),viewer,null,viewer==owner?200:404);binary(viewer,only,viewer==owner);
  }
  privacy(owner,false);
  assertEquals("EVERYONE",call(get("/api/v1/posts/"+privatePost.get("id").asText()),stranger,null,200).get("audience").asText());binary(stranger,privatePost,true);
  assertFalse(relationships.isFollowing(pending.id,owner.id));
  privacy(owner,true);binary(stranger,privatePost,false);
 }
 @Test void spoofOwnershipInvalidForeignKeysAndSixTagsAreControlled() throws Exception {
  var owner=user();var other=user();var b=body(owner,"EVERYONE",1);
  b.put("authorId",other.id);call(post("/api/v1/posts"),owner,b,400);b.remove("authorId");
  b.put("mediaIds",List.of(asset(other,"IMAGE")));call(post("/api/v1/posts"),owner,b,404);
  b=body(owner,"EVERYONE",1);b.put("taggedUserIds",List.of(UUID.randomUUID()));call(post("/api/v1/posts"),owner,b,422);
  b=body(owner,"EVERYONE",1);b.put("placeId",Long.MAX_VALUE);call(post("/api/v1/posts"),owner,b,422);
  b=body(owner,"EVERYONE",1);b.put("hashtags",List.of("a","b","c","d","e","f"));call(post("/api/v1/posts"),owner,b,400);
  b=body(owner,"FOLLOWERS",1);call(post("/api/v1/posts"),owner,b,422);
  mvc.perform(post("/api/v1/posts").contentType("application/json").content(json.writeValueAsBytes(b))).andExpect(status().isUnauthorized());
 }
 @Test void missingTaggedUserReturnsDomainErrorWithoutConsumingDraftOrRequestKey() throws Exception {
  var owner=user();var tagged=user();var b=body(owner,"EVERYONE",1);
  UUID mediaId=(UUID)((List<?>)b.get("mediaIds")).get(0);
  b.put("taggedUserIds",List.of(UUID.randomUUID()));
  long before=db.count("SELECT COUNT(*) FROM posts",Map.of());
  var error=call(post("/api/v1/posts"),owner,b,422);
  assertEquals("INVALID_TAGGED_USER",error.path("code").asText());
  assertEquals(before,db.count("SELECT COUNT(*) FROM posts",Map.of()));
  var draft=db.one("SELECT state,post_id FROM post_media WHERE id=:id",args("id",mediaId));
  assertEquals("READY",draft.get("state"));assertNull(draft.get("postId"));
  var missingOwner=assertThrows(ApiException.class,()->posts.publish(UUID.randomUUID(),json.convertValue(b,PostDtos.Publish.class)));
  assertEquals(404,missingOwner.status);
  b.put("taggedUserIds",List.of(tagged.id));
  var published=call(post("/api/v1/posts"),owner,b,201);
  assertEquals(published.get("id"),call(post("/api/v1/posts"),owner,b,201).get("id"));
  assertEquals(1,db.count("SELECT COUNT(*) FROM posts WHERE author_id=:owner",args("owner",owner.id)));
 }
 @Test void inactiveTagRemains422ButBlockedTagRemainsHiddenInBothDirections() throws Exception {
  var owner=user();var inactive=user();var blocked=user();var reverse=user();
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",inactive.id));
  var b=body(owner,"EVERYONE",1);b.put("taggedUserIds",List.of(inactive.id));
  assertEquals("INVALID_TAGGED_USER",call(post("/api/v1/posts"),owner,b,422).path("code").asText());
  call(put("/api/v1/users/"+blocked.id+"/block"),owner,null,200);
  call(put("/api/v1/users/"+owner.id+"/block"),reverse,null,200);
  for(var target:List.of(blocked,reverse)) {
   b=body(owner,"EVERYONE",1);b.put("taggedUserIds",List.of(target.id));
   assertEquals("NOT_FOUND",call(post("/api/v1/posts"),owner,b,404).path("code").asText());
  }
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",blocked.id));
  b=body(owner,"EVERYONE",1);b.put("taggedUserIds",List.of(blocked.id));
  call(post("/api/v1/posts"),owner,b,404);
  assertEquals(0,db.count("SELECT COUNT(*) FROM posts WHERE author_id=:owner",args("owner",owner.id)));
 }
 @Test void publishedRetryStillSucceedsAfterTaggedUserBecomesInactive() throws Exception {
  var owner=user();var tagged=user();var b=body(owner,"EVERYONE",1);b.put("taggedUserIds",List.of(tagged.id));
  var published=call(post("/api/v1/posts"),owner,b,201);
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",tagged.id));
  assertEquals(published.get("id"),call(post("/api/v1/posts"),owner,b,201).get("id"));
  b.put("caption","Different payload with the published key");call(post("/api/v1/posts"),owner,b,409);
  b.put("clientRequestId",UUID.randomUUID());call(post("/api/v1/posts"),owner,b,422);
  assertEquals(1,db.count("SELECT COUNT(*) FROM posts WHERE author_id=:owner",args("owner",owner.id)));
 }
 @Test void tagDoesNotGrantAudienceAndRangeRemainsAuthenticated() throws Exception {
  var owner=user();var tagged=user();var b=body(owner,"ONLY_ME",1);b.put("taggedUserIds",List.of(tagged.id));
  var p=call(post("/api/v1/posts"),owner,b,201);binary(tagged,p,false);assertFalse(relationships.isFollowing(tagged.id,owner.id));
  binary(owner,p,true);String url="/api/v1"+p.get("media").get(0).get("url").asText();
  mvc.perform(get(url).header("Authorization",owner.token).header("Range","bytes=1-2")).andExpect(status().isPartialContent()).andExpect(header().string("Content-Range","bytes 1-2/4")).andExpect(header().string("Cache-Control","private, no-store, max-age=0")).andExpect(content().bytes(new byte[]{2,3}));
  mvc.perform(get(url).header("Range","bytes=1-2")).andExpect(status().isUnauthorized());
 }
 @Test void warmImagesStillCheckCurrentPermissionsAndDeletionBeforeBufferAccess() throws Exception {
  var owner=user();var viewer=user();
  var p=call(post("/api/v1/posts"),owner,body(owner,"EVERYONE",1),201);
  String path="/api/v1"+p.get("media").get(0).get("url").asText();
  when(media.protectedDownload(anyString(),anyString(),any())).thenReturn("https://api.cloudinary.com/test");
  when(origin.open(anyString(),nullable(String.class))).thenAnswer(i->new ProtectedMediaOrigin.Body(new ByteArrayInputStream(new byte[]{1,2,3,4}),4,0,()->{}));
  clearInvocations(origin);
  for(var suffix:List.of("","/thumbnail")) {
   for(int i=0;i<2;i++) mvc.perform(get(path+suffix).header("Authorization",viewer.token))
    .andExpect(status().isOk()).andExpect(content().bytes(new byte[]{1,2,3,4}))
    .andExpect(header().string("Cache-Control","private, no-store, max-age=0"));
  }
  verify(origin,times(2)).open(anyString(),nullable(String.class));
  privacy(owner,true);
  for(var suffix:List.of("","/thumbnail")) mvc.perform(get(path+suffix).header("Authorization",viewer.token)).andExpect(status().isNotFound());
  relationships.follow(viewer.id,owner.id);
  mvc.perform(get(path).header("Authorization",viewer.token)).andExpect(status().isNotFound());
  privacy(owner,false);
  mvc.perform(get(path).header("Authorization",viewer.token)).andExpect(status().isOk());
  call(patch("/api/v1/posts/"+p.get("id").asText()+"/audience"),owner,Map.of("audience","ONLY_ME"),200);
  mvc.perform(get(path).header("Authorization",viewer.token)).andExpect(status().isNotFound());
  mvc.perform(get(path).header("Authorization",owner.token)).andExpect(status().isOk());
  call(delete("/api/v1/posts/"+p.get("id").asText()),owner,null,204);
  for(var suffix:List.of("","/thumbnail")) mvc.perform(get(path+suffix).header("Authorization",owner.token)).andExpect(status().isNotFound());
  mvc.perform(get(path)).andExpect(status().isUnauthorized());
  verify(origin,times(2)).open(anyString(),nullable(String.class));
 }
 @Test void databaseRollbackKeepsReadyAssetsAndRetryCommitsOnce() throws Exception {
  var owner=user();var b=body(owner,"EVERYONE",1);UUID mediaId=(UUID)((List<?>)b.get("mediaIds")).get(0);
  long before=db.count("SELECT COUNT(*) FROM posts",Map.of());
  doThrow(new IllegalStateException("Injected DB write failure")).doCallRealMethod().when(postRepository).attach(eq(mediaId),anyLong(),eq(0));
  call(post("/api/v1/posts"),owner,b,500);
  assertEquals(before,db.count("SELECT COUNT(*) FROM posts",Map.of()));
  assertEquals("READY",db.one("SELECT state FROM post_media WHERE id=:id",args("id",mediaId)).get("state"));
  var p=call(post("/api/v1/posts"),owner,b,201);
  assertEquals(p.get("id"),call(post("/api/v1/posts"),owner,b,201).get("id"));
 }

 @Test void concurrentPublishAndCaptionGraphemeLimit() throws Exception {
  var owner=user();var b=body(owner,"EVERYONE",1);
  var req=json.convertValue(b,PostDtos.Publish.class);
  var pool=java.util.concurrent.Executors.newFixedThreadPool(3);
  try {
   var tasks=java.util.stream.IntStream.range(0,3).mapToObj(i -> (java.util.concurrent.Callable<Long>)() -> posts.publish(owner.id,req).id()).toList();
   var results=pool.invokeAll(tasks);
   long id=results.get(0).get();
   for(var result:results) assertEquals(id,result.get());
   assertEquals(1,db.count("SELECT COUNT(*) FROM posts WHERE author_id=:id",args("id",owner.id)));
  } finally {pool.shutdownNow();}
  b=body(owner,"EVERYONE",1);b.put("caption","🌸".repeat(2200));call(post("/api/v1/posts"),owner,b,201);
  b=body(owner,"EVERYONE",1);b.put("caption","🌸".repeat(2201));call(post("/api/v1/posts"),owner,b,400);
 }

 @Test void uploadRetryAndProviderFailureCleanupNeverCreateFakePost() throws Exception {
  var owner=user();var id=UUID.randomUUID();
  when(inspector.inspect(any(),eq("IMAGE"),eq("image/png"))).thenReturn(new PostFileInspector.Metadata("image/png","png",2,2,null,4));
  when(media.uploadProtected(any(),anyString(),any())).thenReturn(new MediaUploadResult(null,"test",MediaResourceType.IMAGE,"png",2,2,4L,null));
  var file=new MockMultipartFile("file","image.png","image/png",new byte[]{1,2,3,4});
  for(int i=0;i<2;i++) mvc.perform(multipart("/api/v1/posts/media").file(file).param("uploadId",id.toString()).param("kind","IMAGE").header("Authorization",owner.token)).andExpect(status().isOk()).andExpect(jsonPath("$.mediaId").value(id.toString()));
  verify(media,times(2)).uploadProtected(any(),anyString(),any());
  UUID failed=UUID.randomUUID();when(media.uploadProtected(any(),contains(failed.toString()),any())).thenThrow(new ApiException(503,"UPLOAD_FAILED","Failed"));
  mvc.perform(multipart("/api/v1/posts/media").file(file).param("uploadId",failed.toString()).param("kind","IMAGE").header("Authorization",owner.token)).andExpect(status().isServiceUnavailable());
  assertEquals(0,db.count("SELECT COUNT(*) FROM post_media WHERE id=:id",args("id",failed)));
  verify(media,times(2)).deleteProtected(contains(failed.toString()),eq(MediaResourceType.IMAGE));
 }
 @Test void profilePagesFilterBeforePaginationWithoutHiddenCounts() throws Exception {
  var owner=user();var follower=user();var friend=user();var pending=user();var stranger=user();
  relationships.follow(follower.id,owner.id);relationships.follow(friend.id,owner.id);relationships.follow(owner.id,friend.id);
  var account=posts.publish(owner.id,json.convertValue(body(owner,"EVERYONE",1),PostDtos.Publish.class));
  var mutual=posts.publish(owner.id,json.convertValue(body(owner,"FRIENDS",1),PostDtos.Publish.class));
  var secret=posts.publish(owner.id,json.convertValue(body(owner,"ONLY_ME",1),PostDtos.Publish.class));
  posts.pin(owner.id,secret.id(),true);
  assertEquals(secret.id(),posts.list(owner.id,owner.id,1,null).items().get(0).id());
  var first=posts.list(owner.id,owner.id,1,null);var next=posts.list(owner.id,owner.id,1,first.nextCursor());
  assertNotEquals(first.items().get(0).id(),next.items().get(0).id());
  assertEquals(List.of(account.id()),posts.list(stranger.id,owner.id,1,null).items().stream().map(PostDtos.Detail::id).toList());
  assertNull(posts.list(stranger.id,owner.id,1,null).nextCursor());
  privacy(owner,true);relationships.follow(pending.id,owner.id);
  assertTrue(posts.list(pending.id,owner.id,20,null).items().isEmpty());
  assertTrue(posts.list(stranger.id,owner.id,20,null).items().isEmpty());
  assertEquals(1,posts.list(follower.id,owner.id,20,null).items().size());
  assertEquals(2,posts.list(friend.id,owner.id,20,null).items().size());
  call(get("/api/v1/users/"+owner.id+"/posts").param("cursor",first.nextCursor()),stranger,null,400);
  var response=call(get("/api/v1/users/"+owner.id+"/posts"),pending,null,200);
  assertFalse(response.has("total"));assertEquals(0,response.get("items").size());
 }
 @Test void threePinLimitIsAtomicAndDeletionReleasesSlot() throws Exception {
  var owner=user();var other=user();var ids=new ArrayList<Long>();
  for(int i=0;i<5;i++) ids.add(posts.publish(owner.id,json.convertValue(body(owner,"ONLY_ME",1),PostDtos.Publish.class)).id());
  posts.pin(owner.id,ids.get(0),true);posts.pin(owner.id,ids.get(1),true);
  var pool=java.util.concurrent.Executors.newFixedThreadPool(2);
  try {
   var results=pool.invokeAll(List.of((java.util.concurrent.Callable<Boolean>)()->{try{posts.pin(owner.id,ids.get(2),true);return true;}catch(ApiException e){assertEquals(422,e.status);return false;}},
    ()->{try{posts.pin(owner.id,ids.get(3),true);return true;}catch(ApiException e){assertEquals(422,e.status);return false;}}));
   assertNotEquals(results.get(0).get(),results.get(1).get());
  } finally {pool.shutdownNow();}
  call(put("/api/v1/posts/"+ids.get(4)+"/pin"),owner,null,422);
  call(put("/api/v1/posts/"+ids.get(0)+"/pin"),other,null,404);
  posts.pin(owner.id,ids.get(0),false);posts.pin(owner.id,ids.get(4),true);
  posts.delete(owner.id,ids.get(4));posts.pin(owner.id,ids.get(0),true);
  assertEquals(3,posts.list(owner.id,owner.id,20,null).items().stream().filter(PostDtos.Detail::pinned).count());
 }
 @Test void audienceEditsAndDeleteGateAllMediaAndCleanupIsScoped() throws Exception {
  var owner=user();var other=user();relationships.follow(other.id,owner.id);
  var p=posts.publish(owner.id,json.convertValue(body(owner,"EVERYONE",1),PostDtos.Publish.class));
  var kept=posts.publish(owner.id,json.convertValue(body(owner,"EVERYONE",1),PostDtos.Publish.class));
  call(patch("/api/v1/posts/"+p.id()+"/audience"),other,Map.of("audience","ONLY_ME"),404);
  posts.audience(owner.id,p.id(),"FRIENDS");call(get("/api/v1/posts/"+p.id()),other,null,404);
  relationships.follow(owner.id,other.id);call(get("/api/v1/posts/"+p.id()),other,null,200);
  posts.audience(owner.id,p.id(),"ONLY_ME");call(get("/api/v1/posts/"+p.id()),other,null,404);
  privacy(owner,true);call(patch("/api/v1/posts/"+p.id()+"/audience"),owner,Map.of("audience","EVERYONE"),422);
  posts.audience(owner.id,p.id(),"FOLLOWERS");privacy(owner,false);
  assertEquals("EVERYONE",posts.detail(other.id,p.id()).audience());
  call(delete("/api/v1/posts/"+p.id()),other,null,404);
  call(delete("/api/v1/posts/"+p.id()),owner,null,204);call(delete("/api/v1/posts/"+p.id()),owner,null,204);
  call(get("/api/v1/posts/"+p.id()),owner,null,404);
  for(String path:List.of(p.media().get(0).url(),p.media().get(0).thumbnailUrl())) mvc.perform(get("/api/v1"+path).header("Authorization",owner.token).header("Range","bytes=0-1")).andExpect(status().isNotFound());
  assertEquals(1,posts.list(owner.id,owner.id,20,null).items().size());
  postMedia.cleanup(p.media().get(0).id());
  verify(media,times(2)).deleteProtected(anyString(),eq(MediaResourceType.IMAGE));
  assertNotNull(db.one("SELECT cleaned_at FROM post_media WHERE id=:id",args("id",p.media().get(0).id())).get("cleanedAt"));
  assertEquals(kept.id(),posts.detail(owner.id,kept.id()).id());
 }
 @Test void oldLongVideoRemainsReadableButCannotBeNewlyAttached() throws Exception {
  var owner=user();UUID video=asset(owner,"VIDEO");
  db.update("UPDATE post_media SET duration_ms=60000 WHERE id=:id",args("id",video));
  var b=body(owner,"EVERYONE",1);b.put("mediaIds",List.of(video));call(post("/api/v1/posts"),owner,b,422);
  db.update("INSERT INTO posts(author_id,client_request_id,request_hash,content,audience) VALUES(:owner,:request,'legacy','Old V19 video','ACCOUNT')",args("owner",owner.id,"request",UUID.randomUUID()));
  long id=((Number)db.one("SELECT id FROM posts WHERE author_id=:id",args("id",owner.id)).get("id")).longValue();
  db.update("UPDATE post_media SET state='ATTACHED',post_id=:post,sort_order=0 WHERE id=:id",args("post",id,"id",video));
  var legacy=call(get("/api/v1/posts/"+id),owner,null,200);assertEquals(60000,legacy.get("media").get(0).get("durationMs").asLong());binary(owner,legacy,true);
  String url="/api/v1"+legacy.get("media").get(0).get("url").asText();
  mvc.perform(get(url).header("Authorization",owner.token).header("Range","bytes=1-2")).andExpect(status().isPartialContent());
  assertEquals(1,posts.list(owner.id,owner.id,20,null).items().size());
 }
}
