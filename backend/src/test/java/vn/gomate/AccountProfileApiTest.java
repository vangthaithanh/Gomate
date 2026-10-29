package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
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
class AccountProfileApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;

 @Test
 void currentProfileUsesRealUserDataAndPatchPreservesOmittedFields() throws Exception {
  var user=register("profile-owner");

  JsonNode me=performJson(get("/api/v1/users/me"),user.token(),null,200);
  assertEquals(user.id().toString(),me.get("id").asText());
  assertEquals(user.id().toString(),me.get("userId").asText());
  assertEquals(user.nickname(),me.get("nickname").asText());
  assertEquals(user.nickname(),me.get("displayName").asText());
  assertTrue(me.has("relationshipStats"));

  JsonNode updated=performJson(patch("/api/v1/users/me/profile"),user.token(),Map.of("city","Da Lat"),200);
  assertEquals("Da Lat",updated.get("city").asText());
  assertEquals(user.nickname(),updated.get("nickname").asText());
  assertEquals(user.nickname(),db.one("SELECT nickname FROM user_profiles WHERE user_id=:id",args("id",user.id())).get("nickname"));
 }

 @Test
 void publicProfileHidesPrivateFieldsAndSearchReturnsRelationshipContext() throws Exception {
  var viewer=register("profile-viewer");
  var target=register("profile-target");
  db.update("""
   UPDATE user_profiles SET full_name='Target Person',city='Da Nang',bio='Public bio'
   WHERE user_id=:id
   """,args("id",target.id()));
  db.update("""
   INSERT INTO user_follows(follower_user_id,followed_user_id)
   VALUES(:viewer,:target)
   """,args("viewer",viewer.id(),"target",target.id()));

  JsonNode profile=performJson(get("/api/v1/users/"+target.id()),viewer.token(),null,200);
  assertEquals("Target Person",profile.get("displayName").asText());
  assertTrue(profile.get("followingByMe").asBoolean());
  assertFalse(profile.hasNonNull("email"));

  JsonNode search=performJson(get("/api/v1/users/search?q=target&page=0&size=10"),viewer.token(),null,200);
  assertTrue(search.get("total").asLong() >= 1);
  assertEquals(target.id().toString(),search.get("items").get(0).get("userId").asText());
  assertTrue(search.get("items").get(0).get("followingByMe").asBoolean());
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
  String nickname=prefix+"_"+suffix.substring(0,8);
  String email=prefix+"_"+suffix+"@example.com";
  Map<String,Object> session=auth.register(new AuthDtos.Register(email,"TestPass123!",nickname));
  @SuppressWarnings("unchecked")
  UUID userId=(UUID)((Map<String,Object>)session.get("user")).get("id");
  return new TestUser(userId,"Bearer "+session.get("accessToken"),nickname);
 }

 private record TestUser(UUID id,String token,String nickname) {}
}
