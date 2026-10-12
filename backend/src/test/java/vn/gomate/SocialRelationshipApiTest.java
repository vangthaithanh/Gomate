package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.AuthDtos;
import vn.gomate.auth.AuthService;
import vn.gomate.common.Db;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SocialRelationshipApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;

 @AfterEach
 void cleanup() {
  db.update("DELETE FROM user_follows",Map.of());
 }

 @Test
 void followAndUnfollowAreIdempotent() throws Exception {
  var userA=register("rel-a");
  var userB=register("rel-b");

  JsonNode first=performJson(put("/api/v1/users/"+userB.id()+"/follow"),userA.token(),null,200);
  JsonNode duplicate=performJson(put("/api/v1/users/"+userB.id()+"/follow"),userA.token(),null,200);

  assertTrue(first.get("followingByMe").asBoolean());
  assertTrue(duplicate.get("followingByMe").asBoolean());
  assertEquals(1,followCount(userA.id(),userB.id()));

  JsonNode removed=performJson(delete("/api/v1/users/"+userB.id()+"/follow"),userA.token(),null,200);
  JsonNode duplicateRemove=performJson(delete("/api/v1/users/"+userB.id()+"/follow"),userA.token(),null,200);

  assertFalse(removed.get("followingByMe").asBoolean());
  assertFalse(duplicateRemove.get("followingByMe").asBoolean());
  assertEquals(0,followCount(userA.id(),userB.id()));
 }

 @Test
 void rejectsSelfFollowMissingTargetAndUnauthenticatedRequest() throws Exception {
  var userA=register("rel-auth-a");

  mvc.perform(put("/api/v1/users/"+userA.id()+"/follow"))
   .andExpect(status().isUnauthorized());

  mvc.perform(put("/api/v1/users/"+userA.id()+"/follow").header("Authorization",userA.token()))
   .andExpect(status().isBadRequest())
   .andExpect(jsonPath("$.code").value("SELF_FOLLOW_NOT_ALLOWED"));

  mvc.perform(put("/api/v1/users/"+UUID.randomUUID()+"/follow").header("Authorization",userA.token()))
   .andExpect(status().isNotFound())
   .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
 }

 @Test
 void mutualFriendIsDerivedFromTwoDirectedEdges() throws Exception {
  var userA=register("rel-mutual-a");
  var userB=register("rel-mutual-b");

  JsonNode aToB=performJson(put("/api/v1/users/"+userB.id()+"/follow"),userA.token(),null,200);
  assertTrue(aToB.get("followingByMe").asBoolean());
  assertFalse(aToB.get("followsMe").asBoolean());
  assertFalse(aToB.get("mutualFriend").asBoolean());

  JsonNode bToA=performJson(put("/api/v1/users/"+userA.id()+"/follow"),userB.token(),null,200);
  assertTrue(bToA.get("mutualFriend").asBoolean());

  JsonNode afterMutual=performJson(get("/api/v1/users/"+userB.id()+"/relationship"),userA.token(),null,200);
  assertTrue(afterMutual.get("followingByMe").asBoolean());
  assertTrue(afterMutual.get("followsMe").asBoolean());
  assertTrue(afterMutual.get("mutualFriend").asBoolean());

  JsonNode afterUnfollow=performJson(delete("/api/v1/users/"+userB.id()+"/follow"),userA.token(),null,200);
  assertFalse(afterUnfollow.get("followingByMe").asBoolean());
  assertTrue(afterUnfollow.get("followsMe").asBoolean());
  assertFalse(afterUnfollow.get("mutualFriend").asBoolean());
 }

 @Test
 void listsFollowingFollowersAndMutualFriendsWithPagination() throws Exception {
  var userA=register("rel-list-a");
  var userB=register("rel-list-b");
  var userC=register("rel-list-c");
  var userD=register("rel-list-d");

  performJson(put("/api/v1/users/"+userB.id()+"/follow"),userA.token(),null,200);
  performJson(put("/api/v1/users/"+userC.id()+"/follow"),userA.token(),null,200);
  performJson(put("/api/v1/users/"+userA.id()+"/follow"),userB.token(),null,200);
  performJson(put("/api/v1/users/"+userA.id()+"/follow"),userD.token(),null,200);

  JsonNode followingPage0=performJson(get("/api/v1/users/me/following?page=0&size=1"),userA.token(),null,200);
  JsonNode followingPage1=performJson(get("/api/v1/users/me/following?page=1&size=1"),userA.token(),null,200);
  assertEquals(2,followingPage0.get("total").asLong());
  assertEquals(1,followingPage0.get("items").size());
  assertEquals(1,followingPage1.get("items").size());

  JsonNode followers=performJson(get("/api/v1/users/me/followers"),userA.token(),null,200);
  assertEquals(2,followers.get("total").asLong());

  JsonNode mutual=performJson(get("/api/v1/users/me/mutual-friends"),userA.token(),null,200);
  assertEquals(1,mutual.get("total").asLong());
  assertEquals(userB.id().toString(),mutual.get("items").get(0).get("userId").asText());
  assertTrue(mutual.get("items").get(0).get("mutualFriend").asBoolean());
 }

 @Test
 void bodyCannotFakeActor() throws Exception {
  var userA=register("rel-actor-a");
  var userB=register("rel-actor-b");
  var userC=register("rel-actor-c");

  performJson(put("/api/v1/users/"+userC.id()+"/follow"),userB.token(),Map.of("followerUserId",userA.id().toString()),200);

  assertEquals(0,followCount(userA.id(),userC.id()));
  assertEquals(1,followCount(userB.id(),userC.id()));
 }

 @Test
 void databaseConstraintsRejectSelfFollowAndDuplicateEdges() {
  var userA=register("rel-fk-a");
  var userB=register("rel-fk-b");

  db.update(
   "INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(:a,:b)",
   args("a",userA.id(),"b",userB.id())
  );

  assertThrows(DataIntegrityViolationException.class,() -> db.update(
   "INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(:a,:a)",
   args("a",userA.id())
  ));
  assertThrows(DataIntegrityViolationException.class,() -> db.update(
   "INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(:a,:b)",
   args("a",userA.id(),"b",userB.id())
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

 private long followCount(UUID followerUserId,UUID followedUserId) {
  return db.count("""
   SELECT COUNT(*) FROM user_follows
   WHERE follower_user_id=:followerUserId AND followed_user_id=:followedUserId
   """,args("followerUserId",followerUserId,"followedUserId",followedUserId));
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
