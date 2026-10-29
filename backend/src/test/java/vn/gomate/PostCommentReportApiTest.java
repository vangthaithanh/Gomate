package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.util.*;
import java.util.concurrent.*;
import java.nio.file.Path;
import org.junit.jupiter.api.*;
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
import vn.gomate.social.comment.*;
import vn.gomate.social.report.*;
import vn.gomate.media.service.MediaService;
import vn.gomate.media.provider.ProtectedMediaOrigin;
import vn.gomate.media.dto.MediaUploadResult;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PostCommentReportApiTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired AuthService auth;@Autowired Db db;
 @Autowired PostService posts;@Autowired CommentService comments;@Autowired CommentMediaService media;
 @Autowired vn.gomate.relationship.service.SocialRelationshipService relationships;
 @Autowired vn.gomate.user.service.UserService users;
 @MockitoBean MediaService provider;@MockitoBean PostFileInspector inspector;@MockitoBean ProtectedMediaOrigin origin;
 record User(UUID id,String token) {}
 User user() {String key="c"+UUID.randomUUID().toString().replace("-","").substring(0,18);var s=auth.register(new AuthDtos.Register(key+"@example.com","TestPass123!",key));return new User((UUID)((Map<?,?>)s.get("user")).get("id"),"Bearer "+s.get("accessToken"));}
 JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,User u,int status) throws Exception {var res=mvc.perform(req.header("Authorization",u.token)).andExpect(status().is(status)).andReturn().getResponse();return res.getContentAsByteArray().length==0 || !res.getContentType().contains("json")?json.createObjectNode():json.readTree(res.getContentAsByteArray());}
 org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder body(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder b,Object value) throws Exception {return b.contentType("application/json").content(json.writeValueAsBytes(value));}
 long publish(User u) {var id=UUID.randomUUID();db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,'hash','IMAGE','READY',:pid,:thumb,'png','image/png',4,2,2)",args("id",id,"owner",u.id,"pid",id.toString(),"thumb",id+"_cover"));return posts.publish(u.id,new PostDtos.Publish(UUID.randomUUID(),"P3","EVERYONE",new ArrayList<>(List.of(id)),List.of(),new ArrayList<>(),null)).id();}
 Map<String,Object> request(String text,Long parent,List<UUID> media) {return args("clientRequestId",UUID.randomUUID(),"body",text,"parentId",parent,"mediaIds",media);}
 JsonNode comment(User u,long p,String text,Long parent) throws Exception {return call(body(post("/api/v1/posts/"+p+"/comments"),request(text,parent,List.of())),u,201);}
 long id(JsonNode c) {return c.get("commentId").asLong();}
 UUID ready(User u,long p) {var id=UUID.randomUUID();db.update("INSERT INTO comment_media(id,owner_id,post_id,content_hash,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,:post,'hash','READY',:pid,:thumb,'png','image/png',4,2,2)",args("id",id,"owner",u.id,"post",p,"pid","test-comment-"+id,"thumb",id+"_cover"));return id;}
 void privacy(User u,boolean value) {users.updateProfile(u.id,new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,null,null,null,null,value));}
 @Test void oneLevelThreadCountsDeletionAndOwnerPermissions() throws Exception {
  var author=user();var a=user();var b=user();long p=publish(author);
  long root=id(comment(a,p,"root",null));long reply=id(comment(b,p,"reply",root));var nested=comment(a,p,"reply to reply",reply);
  assertEquals(root,nested.get("parentCommentId").asLong());assertEquals(b.id.toString(),nested.get("replyToUserId").asText());
  var list=call(get("/api/v1/posts/"+p+"/comments"),b,200);assertEquals(1,list.get("items").size());assertEquals(2,list.get("items").get(0).get("replyCount").asInt());
  assertEquals(3,call(get("/api/v1/posts/"+p),b,200).get("commentCount").asInt());
  call(delete("/api/v1/comments/"+root),author,404);
  call(delete("/api/v1/comments/"+reply),b,204);assertEquals(2,posts.detail(b.id,p).commentCount());
  call(delete("/api/v1/comments/"+root),a,204);call(delete("/api/v1/comments/"+root),a,204);
  assertEquals(0,posts.detail(b.id,p).commentCount());call(get("/api/v1/comments/"+root+"/replies"),b,404);call(put("/api/v1/comments/"+id(nested)+"/like"),b,404);
  call(body(post("/api/v1/posts/"+p+"/comments"),request("deleted parent",root,List.of())),b,404);
 }
 @Test void validationImageOnlySixImagesCrossPostAndOwnerAssociation() throws Exception {
  var a=user();var b=user();long p=publish(a),other=publish(a);
  call(body(post("/api/v1/posts/"+p+"/comments"),request(" ",null,List.of())),a,400);
  call(body(post("/api/v1/posts/"+p+"/comments"),request("a".repeat(2001),null,List.of())),a,400);
  long foreign=id(comment(a,other,"other",null));call(body(post("/api/v1/posts/"+p+"/comments"),request("cross",foreign,List.of())),a,400);
  var six=new ArrayList<UUID>();for(int i=0;i<6;i++) six.add(ready(a,p));
  var imageOnly=call(body(post("/api/v1/posts/"+p+"/comments"),request("",null,six)),a,201);assertEquals(6,imageOnly.get("media").size());
  var seven=new ArrayList<>(six);seven.add(ready(a,p));call(body(post("/api/v1/posts/"+p+"/comments"),request("seven",null,seven)),a,400);
  call(body(post("/api/v1/posts/"+p+"/comments"),request("take",null,List.of(ready(b,p)))),a,404);
  call(body(post("/api/v1/posts/"+other+"/comments"),request("cross media",null,List.of(ready(a,p)))),a,404);
  call(body(post("/api/v1/posts/"+p+"/comments"),request("used",null,six)),a,409);
  call(body(post("/api/v1/posts/"+p+"/comments"),request("combo",null,List.of(ready(a,p)))),a,201);
 }
 @Test void retryConcurrentCreateNotifiesOnceAndCommentLikesDoNotNotify() throws Exception {
  var a=user();var b=user();long p=publish(a);long count=db.count("SELECT COUNT(*) FROM notifications",Map.of());
  var req=new CommentDtos.Create(UUID.randomUUID(),"stable",null,new ArrayList<>());var executor=Executors.newFixedThreadPool(5);
  try {
   var work=new ArrayList<Callable<Map<String,Object>>>();for(int i=0;i<10;i++) work.add(()->comments.create(b.id,p,req));
   var ids=new HashSet<Long>();for(var f:executor.invokeAll(work)) ids.add(((Number)f.get(15,TimeUnit.SECONDS).get("commentId")).longValue());assertEquals(1,ids.size());long c=ids.iterator().next();
   work.clear();for(int i=0;i<10;i++) work.add(()->comments.like(a.id,c,true));for(var f:executor.invokeAll(work)) assertEquals(1,((Number)f.get(15,TimeUnit.SECONDS).get("likeCount")).intValue());
   comments.like(a.id,c,false);comments.like(a.id,c,false);assertEquals(0,db.count("SELECT COUNT(*) FROM comment_likes WHERE comment_id=:id",args("id",c)));
   assertThrows(ApiException.class,()->comments.create(b.id,p,new CommentDtos.Create(req.clientRequestId(),"changed",null,List.of())));
  }finally {executor.shutdownNow();}
  assertEquals(count+1,db.count("SELECT COUNT(*) FROM notifications",Map.of()));
 }
 @Test void paginationBoundToViewerPostAndThread() throws Exception {
  var a=user();var b=user();long p=publish(a);for(int i=0;i<5;i++) comment(a,p,"r"+i,null);
  String path="/api/v1/posts/"+p+"/comments?size=2";var first=call(get(path),b,200);var token=first.get("nextCursor").asText();var second=call(get(path+"&cursor="+token),b,200);
  assertTrue(first.get("items").get(1).get("id").asLong()>second.get("items").get(0).get("id").asLong());call(get(path+"&cursor="+token),a,400);
  long root=id(comment(a,p,"thread",null));for(int i=0;i<3;i++) comment(b,p,"reply",root);
  var replies=call(get("/api/v1/comments/"+root+"/replies?size=2"),a,200);assertEquals(2,replies.get("items").size());assertFalse(replies.get("nextCursor").isNull());
  call(get(path+"&cursor=bad"),a,400);mvc.perform(get(path)).andExpect(status().isUnauthorized());
 }
 @Test void privacyPendingAcceptedMutualAudienceAndDeletedPost() throws Exception {
  var a=user();var b=user();long p=publish(a);long root=id(comment(b,p,"old",null));privacy(a,true);relationships.follow(b.id,a.id);
  call(get("/api/v1/posts/"+p+"/comments"),b,404);call(put("/api/v1/comments/"+root+"/like"),b,404);call(body(post("/api/v1/posts/"+p+"/comments"),request("no",null,List.of())),b,404);
  var r=relationships.requests(a.id,0,50).items().stream().filter(i->i.requesterId().equals(b.id)).findFirst().orElseThrow();relationships.respond(a.id,r.id(),true);
  call(get("/api/v1/posts/"+p+"/comments"),b,200);posts.audience(a.id,p,"FRIENDS");call(get("/api/v1/posts/"+p+"/comments"),b,404);relationships.follow(a.id,b.id);call(get("/api/v1/posts/"+p+"/comments"),b,200);
  relationships.unfollow(b.id,a.id);call(get("/api/v1/posts/"+p+"/comments"),b,404);privacy(a,false);posts.audience(a.id,p,"EVERYONE");call(get("/api/v1/posts/"+p+"/comments"),b,200);
  posts.audience(a.id,p,"ONLY_ME");call(get("/api/v1/posts/"+p+"/comments"),b,404);posts.delete(a.id,p);call(get("/api/v1/posts/"+p+"/comments"),a,404);
 }
 @Test void protectedImagesRecheckPermissionEvenWhenBufferWarm() throws Exception {
  var a=user();var b=user();long p=publish(a);var m=ready(b,p);long root=id(comment(a,p,"root",null));var c=call(body(post("/api/v1/posts/"+p+"/comments"),request("picture",root,List.of(m))),b,201);long id=id(c);
  when(provider.protectedDownload(anyString(),anyString(),any())).thenReturn("https://api.cloudinary.com/test");
  when(origin.open(anyString(),isNull())).thenAnswer(i->new ProtectedMediaOrigin.Body(new java.io.ByteArrayInputStream(new byte[]{1,2,3,4}),4,0,()->{}));
  String path="/api/v1/comments/"+id+"/media/"+m;
  call(get(path),a,200);call(get(path),a,200);verify(origin,times(1)).open(anyString(),isNull());
  privacy(a,true);call(get(path),b,404);privacy(a,false);call(get(path+"/thumbnail"),a,200);
  call(delete("/api/v1/comments/"+root),a,204);call(get(path),a,404);call(get(path+"/thumbnail"),a,404);
 }
 @Test void reportsSixReasonsRetryHistoryPrivacyAndNoModeration() throws Exception {
  var a=user();var b=user();var other=user();long p=publish(a);long notifications=db.count("SELECT COUNT(*) FROM notifications",Map.of());
  String path="/api/v1/posts/"+p+"/reports";var key=UUID.randomUUID();Map<String,Object> req=args("clientRequestId",key,"reasonCode","SCAM_OR_SPAM","description","details");
  var first=call(body(post(path),req),b,201);var second=call(body(post(path),req),b,201);assertEquals(first.get("id"),second.get("id"));assertEquals("PENDING",first.get("status").asText());
  call(body(post(path),args("clientRequestId",key,"reasonCode","FALSE_INFORMATION")),b,409);
  for(var reason:PostReportService.REASONS) call(body(post(path),args("clientRequestId",UUID.randomUUID(),"reasonCode",reason)),b,201);
  assertEquals(7,call(get("/api/v1/me/reports"),b,200).get("items").size());assertEquals(0,call(get("/api/v1/me/reports"),other,200).get("items").size());call(get("/api/v1/me/reports/"+first.get("id").asText()),other,404);
  call(body(post(path),args("clientRequestId",UUID.randomUUID(),"reasonCode","SCAM_OR_SPAM")),a,403);
  call(body(post(path),args("clientRequestId",UUID.randomUUID(),"reasonCode","OTHER")),b,400);call(body(post(path),args("clientRequestId",UUID.randomUUID(),"reasonCode","SCAM_OR_SPAM","description","a".repeat(1001))),b,400);
  privacy(a,true);call(body(post(path),args("clientRequestId",UUID.randomUUID(),"reasonCode","SCAM_OR_SPAM")),b,404);
  assertEquals(7,call(get("/api/v1/me/reports"),b,200).get("items").size());assertNotNull(posts.detail(a.id,p));assertEquals(notifications,db.count("SELECT COUNT(*) FROM notifications",Map.of()));
 }
 @Test void uploadRetryInvalidVideoCleanupFailureAndReconciliation() throws Exception {
  var a=user();long p=publish(a);var upload=UUID.randomUUID();
  var image=new MockMultipartFile("file","photo.jpg","image/jpeg",new byte[]{1,2,3,4});
  when(inspector.inspect(any(Path.class),eq("IMAGE"),eq("image/jpeg"))).thenReturn(new PostFileInspector.Metadata("image/jpeg","jpg",2,2,null,4));
  when(provider.uploadProtected(any(),anyString(),any())).thenReturn(new MediaUploadResult(null,null,vn.gomate.media.model.MediaResourceType.IMAGE,"jpg",2,2,4L,null));
  assertEquals(upload,media.upload(a.id,p,upload,image).get("mediaId"));media.upload(a.id,p,upload,image);
  verify(provider,times(2)).uploadProtected(any(),anyString(),any());
  var m=ready(a,p);var c=comments.create(a.id,p,new CommentDtos.Create(UUID.randomUUID(),"picture",null,new ArrayList<>(List.of(m))));
  comments.delete(a.id,((Number)c.get("id")).longValue());media.cleanup(m);
  assertNotNull(db.one("SELECT cleaned_at FROM comment_media WHERE id=:id",args("id",m)).get("cleanedAt"));
  var failed=UUID.randomUUID();when(provider.uploadProtected(any(),anyString(),any())).thenThrow(new ApiException(503,"TEST","failed"));
  doThrow(new ApiException(503,"TEST","cleanup failed")).when(provider).deleteProtected(anyString(),any());
  assertThrows(ApiException.class,()->media.upload(a.id,p,failed,image));
  assertEquals("CLEANUP",db.one("SELECT state FROM comment_media WHERE id=:id",args("id",failed)).get("state"));
  doNothing().when(provider).deleteProtected(anyString(),any());media.reconcile();
  assertEquals(0,db.count("SELECT COUNT(*) FROM comment_media WHERE id=:id",args("id",failed)));
  when(inspector.inspect(any(Path.class),eq("IMAGE"),eq("video/mp4"))).thenThrow(new ApiException(415,"INVALID_POST_MEDIA","not image"));
  assertThrows(ApiException.class,()->media.upload(a.id,p,UUID.randomUUID(),new MockMultipartFile("file","v.mp4","video/mp4",new byte[]{1,2,3,4})));
 }

}
