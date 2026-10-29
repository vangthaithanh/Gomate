package vn.gomate;
import java.util.*;
import java.util.concurrent.*;
import com.fasterxml.jackson.databind.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import vn.gomate.common.Db;
import vn.gomate.auth.AuthService;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class ApiIntegrationTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired Db db;@Autowired AuthService auth;
 private JsonNode user,other;private String token,otherToken;private String place,category;
 private final String password="TestPass123!";
 JsonNode call(String method,String path,String bearer,Object body,int status) throws Exception {
  var req=MockMvcRequestBuilders.request(org.springframework.http.HttpMethod.valueOf(method),"/api/v1"+path);
  if(bearer!=null) req.header("Authorization","Bearer "+bearer);
  if(body!=null) req.contentType("application/json").content(json.writeValueAsBytes(body));
  var result=mvc.perform(req).andExpect(status().is(status)).andReturn();
  String content=result.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
  return content.isBlank()?json.nullNode():json.readTree(content);
 }
 JsonNode register(String email,String nick) throws Exception {
  return call("POST","/auth/register",null,Map.of("email",email,"password",password,"nickname",nick),201);
 }
 @BeforeEach void setup() throws Exception {
  String suffix=UUID.randomUUID().toString().substring(0,8);
  user=register(suffix+"@example.com","owner_"+suffix);token=user.get("accessToken").asText();
  other=register("b"+suffix+"@example.com","other_"+suffix);otherToken=other.get("accessToken").asText();
 }
 @Test void registerAtomicAndNoPasswordLeak() throws Exception {
  JsonNode profile=call("GET","/users/me",token,null,200);
  assertFalse(profile.has("passwordHash"));assertFalse(user.toString().contains("passwordHash"));
  String nick=user.at("/user/nickname").asText().toUpperCase(Locale.ROOT),mail=UUID.randomUUID()+"@example.com";
  call("POST","/auth/register",null,Map.of("email",mail,"password",password,"nickname",nick),409);
  assertEquals(0,db.count("SELECT COUNT(*) FROM users WHERE email=:email",args("email",mail)));
  call("POST","/auth/register",null,Map.of("email",profile.get("email").asText().toUpperCase(Locale.ROOT),"password",password,"nickname","anotherNick"),409);
 }
 @Test void rejectsWeakPasswordUnknownRoleAndInvalidEmail() throws Exception {
  call("POST","/auth/register",null,Map.of("email","not-an-email","password","abc","nickname","ab"),400);
  call("POST","/auth/register",null,Map.of("email","new@example.com","password",password,"nickname","newbie","role","ADMIN"),400);
  call("POST","/auth/register",null,Map.of("email","new@example.com","password","ệ".repeat(30),"nickname","newbie"),400);
 }
 @Test void loginRefreshRotationAndLogout() throws Exception {
  String email=user.at("/user/email").asText();
  call("POST","/auth/login",null,Map.of("email",email,"password","wrongpass"),401);
  JsonNode login=call("POST","/auth/login",null,Map.of("email",email,"password",password),200);
  String refresh=login.get("refreshToken").asText();
  JsonNode rotated=call("POST","/auth/refresh",null,Map.of("refreshToken",refresh),200);
  assertNotEquals(refresh,rotated.get("refreshToken").asText());
  call("POST","/auth/refresh",null,Map.of("refreshToken",refresh),401);
  String access=rotated.get("accessToken").asText();
  call("POST","/auth/logout",access,null,204);
  call("GET","/users/me",access,null,401);
  call("POST","/auth/refresh",null,Map.of("refreshToken",rotated.get("refreshToken").asText()),401);
 }
 @Test void refreshConcurrentOnlyOneSucceeds() throws Exception {
  String refresh=user.get("refreshToken").asText();
  ExecutorService pool=Executors.newFixedThreadPool(2);
  try {
   Callable<Boolean> work=()->{try { auth.refresh(refresh);return true; } catch(vn.gomate.common.ApiException e) {assertEquals(401,e.status);return false;} };
   var results=pool.invokeAll(List.of(work,work));
   assertEquals(1,(results.get(0).get()?1:0)+(results.get(1).get()?1:0));
  } finally {pool.shutdownNow();}
 }
 @Test void changePasswordRevokesAllSessions() throws Exception {
  call("POST","/auth/change-password",token,Map.of("currentPassword",password,"newPassword","NewPassword123!"),204);
  call("GET","/users/me",token,null,401);
  call("POST","/auth/refresh",null,Map.of("refreshToken",user.get("refreshToken").asText()),401);
  call("POST","/auth/login",null,Map.of("email",user.at("/user/email").asText(),"password",password),401);
  call("POST","/auth/login",null,Map.of("email",user.at("/user/email").asText(),"password","NewPassword123!"),200);
 }
 @Test void lockedUserAndTamperedTokensDenied() throws Exception {
  call("GET","/users/me",token+"tampered",null,401);
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",UUID.fromString(user.at("/user/id").asText())));
  call("GET","/users/me",token,null,401);
  call("POST","/auth/login",null,Map.of("email",user.at("/user/email").asText(),"password",password),403);
 }
 @Test void openApiGenerated() throws Exception {
  mvc.perform(MockMvcRequestBuilders.get("/v3/api-docs")).andExpect(status().isOk()).andExpect(jsonPath("$.paths['/api/v1/auth/register']").exists());
 }
 @Test void googleRequiresConfigurationAndLinkRequiresSession() throws Exception {
  assertEquals("FIREBASE_NOT_CONFIGURED",call("POST","/auth/google",null,Map.of("idToken","fake"),503).get("code").asText());
  call("POST","/auth/google/link",null,Map.of("idToken","fake"),401);
  call("POST","/auth/google",null,Map.of("idToken",""),400);
 }
 @Test void healthIsPublicAtBothPaths() throws Exception {
  mvc.perform(MockMvcRequestBuilders.get("/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
  mvc.perform(MockMvcRequestBuilders.get("/api/v1/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
 }
}
