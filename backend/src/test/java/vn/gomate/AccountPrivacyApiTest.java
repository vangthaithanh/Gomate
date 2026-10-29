package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.AuthDtos;
import vn.gomate.auth.AuthService;
import vn.gomate.common.Db;
import vn.gomate.relationship.service.SocialRelationshipService;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AccountPrivacyApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @Autowired SocialRelationshipService relationships;

 @Test void publicFollowAndPrivatePendingUseServerPrivacy() throws Exception {
  var a=user(); var b=user();
  assertFalse(call(get("/api/v1/users/me/profile"),b,null,200).get("isPrivate").asBoolean());
  assertTrue(call(put("/api/v1/users/"+b.id+"/follow"),a,Map.of("isPrivate",true),200).get("followingByMe").asBoolean());
  call(delete("/api/v1/users/"+b.id+"/follow"),a,null,200);
  privacy(b,true);
  var pending=call(put("/api/v1/users/"+b.id+"/follow"),a,Map.of("isPrivate",false),200);
  assertTrue(pending.get("followRequestPending").asBoolean());
  assertFalse(pending.get("followingByMe").asBoolean());
  call(put("/api/v1/users/"+b.id+"/follow"),a,null,200);
  assertEquals(1,requests(a,b,"PENDING"));
  assertFalse(relationships.isFollowing(a.id,b.id));
  var profile=call(get("/api/v1/users/"+b.id),a,null,200);
  assertTrue(profile.get("isPrivate").asBoolean());
  assertTrue(profile.get("followRequestPending").asBoolean());
  var search=call(get("/api/v1/users/search?q="+b.nickname),a,null,200).get("items").get(0);
  assertTrue(search.get("isPrivate").asBoolean());
  assertTrue(search.get("followRequestPending").asBoolean());
  call(get("/api/v1/users/"+b.id+"/followers"),a,null,403);
  call(get("/api/v1/users/"+b.id+"/mutual-friends"),a,null,403);
  var login=auth.login(new AuthDtos.Login(b.email,"TestPass123!"));
  assertTrue(Boolean.TRUE.equals(((Map<?,?>)login.get("user")).get("isPrivate")));
 }

 @Test void onlyOwnerAcceptsAndCreatesExactlyOneRealEdge() throws Exception {
  var a=user(); var b=user(); var c=user();
  privacy(b,true);
  call(put("/api/v1/users/"+a.id+"/follow"),b,null,200);
  call(put("/api/v1/users/"+b.id+"/follow"),a,null,200);
  assertFalse(relationships.isMutualFriend(a.id,b.id));
  String id=requestId(b);
  call(post("/api/v1/users/me/follow-requests/"+id+"/accept"),a,null,404);
  call(post("/api/v1/users/me/follow-requests/"+id+"/reject"),c,null,404);
  assertEquals(0,call(get("/api/v1/users/me/follow-requests"),c,null,200).get("total").asInt());
  var accepted=call(post("/api/v1/users/me/follow-requests/"+id+"/accept"),b,null,200);
  assertTrue(accepted.get("mutualFriend").asBoolean());
  call(post("/api/v1/users/me/follow-requests/"+id+"/accept"),b,null,200);
  assertTrue(relationships.isMutualFriend(a.id,b.id));
  assertEquals(1,requests(a,b,"ACCEPTED"));
  assertEquals(1,db.count("SELECT COUNT(*) FROM user_follows WHERE follower_user_id=:a AND followed_user_id=:b",args("a",a.id,"b",b.id)));
  call(get("/api/v1/users/"+b.id+"/followers"),a,null,200);
 }

 @Test void rejectCancelAndResendPreserveHistoryAndDoNotFollow() throws Exception {
  var a=user(); var b=user(); privacy(b,true);
  call(put("/api/v1/users/"+b.id+"/follow"),a,null,200);
  String first=requestId(b);
  call(post("/api/v1/users/me/follow-requests/"+first+"/reject"),b,null,200);
  call(post("/api/v1/users/me/follow-requests/"+first+"/reject"),b,null,200);
  assertFalse(relationships.isFollowing(a.id,b.id));
  call(put("/api/v1/users/"+b.id+"/follow"),a,null,200);
  String second=requestId(b);
  assertNotEquals(first,second);
  call(delete("/api/v1/users/"+b.id+"/follow"),a,null,200);
  call(post("/api/v1/users/me/follow-requests/"+second+"/accept"),b,null,409);
  assertEquals(1,requests(a,b,"REJECTED"));
  assertEquals(1,requests(a,b,"CANCELLED"));
  assertFalse(relationships.isFollowing(a.id,b.id));
 }

 @Test void togglingVisibilityPreservesFollowersAndNeverAutoAcceptsPending() throws Exception {
  var a=user(); var b=user(); var c=user();
  call(put("/api/v1/users/"+b.id+"/follow"),a,null,200);
  privacy(b,true);
  call(put("/api/v1/users/"+b.id+"/follow"),c,null,200);
  privacy(b,false);
  assertTrue(relationships.isFollowing(a.id,b.id));
  assertFalse(relationships.isFollowing(c.id,b.id));
  assertEquals(1,requests(c,b,"PENDING"));
  privacy(b,true);
  assertTrue(relationships.isFollowing(a.id,b.id));
  assertEquals(1,requests(c,b,"PENDING"));
  assertTrue(call(get("/api/v1/users/"+b.id),c,null,200).get("isPrivate").asBoolean());
  // After a later PUBLIC toggle, only an explicit follow action can supersede it.
  privacy(b,false);
  call(put("/api/v1/users/"+b.id+"/follow"),c,null,200);
  assertTrue(relationships.isFollowing(c.id,b.id));
  assertEquals(1,requests(c,b,"CANCELLED"));
 }

 @Test void concurrentDuplicateFollowAndAcceptAreSerialized() throws Exception {
  var a=user(); var b=user(); privacy(b,true);
  var pool=Executors.newFixedThreadPool(4);
  try {
   var tasks=java.util.stream.IntStream.range(0,8).mapToObj(i -> (java.util.concurrent.Callable<Void>)() -> {
    relationships.follow(a.id,b.id); return null;
   }).toList();
   for(var task:pool.invokeAll(tasks)) task.get();
   assertEquals(1,requests(a,b,"PENDING"));
   UUID id=UUID.fromString(requestId(b));
   var accepts=java.util.stream.IntStream.range(0,4).mapToObj(i -> (java.util.concurrent.Callable<Void>)() -> {
    relationships.respond(b.id,id,true); return null;
   }).toList();
   for(var task:pool.invokeAll(accepts)) task.get();
   assertEquals(1,requests(a,b,"ACCEPTED"));
   assertTrue(relationships.isFollowing(a.id,b.id));
  } finally { pool.shutdownNow(); }
 }

 private void privacy(User u,boolean value) throws Exception {
  assertEquals(value,call(patch("/api/v1/users/me/profile"),u,Map.of("isPrivate",value),200).get("isPrivate").asBoolean());
 }
 private long requests(User a,User b,String state) {
  return db.count("SELECT COUNT(*) FROM follow_requests WHERE requester_id=:a AND target_id=:b AND status=:state",args("a",a.id,"b",b.id,"state",state));
 }
 private String requestId(User owner) throws Exception {
  return call(get("/api/v1/users/me/follow-requests"),owner,null,200).get("items").get(0).get("id").asText();
 }
 private JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,User actor,Object body,int status) throws Exception {
  req.header("Authorization",actor.token);
  if(body!=null) req.contentType("application/json").content(json.writeValueAsBytes(body));
  return json.readTree(mvc.perform(req).andExpect(status().is(status)).andReturn().getResponse().getContentAsByteArray());
 }
 private User user() {
  String name="privacy"+UUID.randomUUID().toString().replace("-","").substring(0,12);
  var session=auth.register(new AuthDtos.Register(name+"@example.com","TestPass123!",name));
  return new User((UUID)((Map<?,?>)session.get("user")).get("id"),"Bearer "+session.get("accessToken"),name+"@example.com",name);
 }
 private record User(UUID id,String token,String email,String nickname) {}
}
