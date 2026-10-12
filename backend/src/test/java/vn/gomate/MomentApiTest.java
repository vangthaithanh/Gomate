package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
import vn.gomate.common.Db;
import vn.gomate.moment.model.MomentDocument;
import vn.gomate.moment.repository.MomentMongoRepository;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MomentApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @MockitoBean MomentMongoRepository moments;

 @AfterEach
 void cleanup() {
  reset(moments);
  db.update("DELETE FROM user_follows",Map.of());
 }

 @Test
 void mutualFriendMomentAppearsOnHomeForOtherUser() throws Exception {
  var userA=register("moment-owner");
  var userB=register("moment-viewer");
  makeMutual(userA.id(),userB.id());

  var moment=momentOf(userA.id());
  when(moments.mutedOwnerIds(userB.id())).thenReturn(Set.of());
  when(moments.viewedMomentIds(eq(userB.id()),ArgumentMatchers.<Collection<String>>any())).thenReturn(Set.of());
  when(moments.activeOwn(eq(userB.id()),any(Instant.class))).thenReturn(List.of());
  when(moments.ownerHistory(userB.id(),200)).thenReturn(List.of());
  when(moments.reactions("moment-owner-1")).thenReturn(List.of());
  when(moments.activeByOwners(ArgumentMatchers.<Collection<UUID>>any(),any(Instant.class),eq(500)))
   .thenAnswer(invocation -> {
    Collection<UUID> ownerIds=invocation.getArgument(0);
    return ownerIds.contains(userA.id())?List.of(moment):List.of();
   });

  JsonNode home=performJson(get("/api/v1/moments/home"),userB.token(),200);

  assertEquals(2,home.get("stripItems").size());
  assertEquals(userA.id().toString(),home.get("stripItems").get(1).get("userId").asText());
  assertEquals(true,home.get("stripItems").get(1).get("hasAvailableMoment").asBoolean());
  assertEquals(1,home.get("availableFriendMoments").size());
  assertEquals("moment-owner-1",home.get("availableFriendMoments").get(0).get("momentId").asText());
  assertEquals(userA.id().toString(),home.get("availableFriendMoments").get(0).get("ownerId").asText());
 }

 private MomentDocument momentOf(UUID ownerId) {
  var now=Instant.now();
  var doc=new MomentDocument();
  doc.setMomentId("moment-owner-1");
  doc.setOwnerUserId(ownerId);
  doc.setMediaUrl("https://res.cloudinary.com/demo/image/upload/sample.jpg");
  doc.setMediaPublicId("gomate/test/moment-owner-1");
  doc.setMediaType("IMAGE");
  doc.setVisibility("MUTUAL_FRIENDS");
  doc.setCreatedAt(now);
  doc.setExpiresAt(now.plusSeconds(3600));
  return doc;
 }

 private void makeMutual(UUID userA,UUID userB) {
  db.update("INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(:a,:b)",args("a",userA,"b",userB));
  db.update("INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(:b,:a)",args("a",userA,"b",userB));
 }

 private JsonNode performJson(
  org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,
  String token,
  int expectedStatus
 ) throws Exception {
  var result=mvc.perform(request.header("Authorization",token))
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
