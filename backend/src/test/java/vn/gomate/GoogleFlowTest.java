package vn.gomate;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import static org.junit.jupiter.api.Assertions.*;
import static vn.gomate.common.Db.args;
@SpringBootTest @ActiveProfiles("test")
class GoogleFlowTest {
 @Autowired AuthService auth; @Autowired Db db;
 GoogleVerifier.Identity identity() {String id=UUID.randomUUID().toString();return new GoogleVerifier.Identity(id,id+"@example.com","Google Test");}
 @SuppressWarnings("unchecked") UUID uid(Map<String,Object> session) {return (UUID)((Map<String,Object>)session.get("user")).get("id");}
 @Test void exactlyFourTables() {
  var tables=db.list("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'",Map.of());
  assertEquals(Set.of("users","user_profiles","user_settings","refresh_sessions"),new HashSet<>(tables.stream().map(t->(String)t.get("tableName")).toList()));
 }
 @Test void googleCreatesAndReusesAccount() {
  var identity=identity();var first=auth.google(identity);UUID id=uid(first);
  assertEquals(id,uid(auth.google(identity)));
  assertEquals(1,db.count("SELECT COUNT(*) FROM user_profiles WHERE user_id=:id",args("id",id)));
  assertEquals(1,db.count("SELECT COUNT(*) FROM user_settings WHERE user_id=:id",args("id",id)));
  assertEquals(2,db.count("SELECT COUNT(*) FROM refresh_sessions WHERE user_id=:id",args("id",id)));
  assertThrows(ApiException.class,()->auth.login(new AuthDtos.Login(identity.email(),"GuessPass123")));
 }
 @Test void existingEmailAutoLinksVerifiedGoogle() {
  var identity=identity();UUID id=uid(auth.register(new AuthDtos.Register(identity.email(),"TestPass123!","n"+UUID.randomUUID())));
  assertEquals(id,uid(auth.google(identity)));
  assertTrue((Boolean)db.one("SELECT CASE WHEN google_subject IS NULL THEN FALSE ELSE TRUE END AS linked FROM users WHERE id=:id",args("id",id)).get("linked"));
  assertEquals(id,uid(auth.google(identity)));
 }
 @Test void googleRejectsEmailAlreadyLinkedToDifferentSubject() {
  var identity=identity();UUID id=uid(auth.google(identity));
  var otherSubjectSameEmail=new GoogleVerifier.Identity(UUID.randomUUID().toString(),identity.email(),"Other Google");
  var error=assertThrows(ApiException.class,()->auth.google(otherSubjectSameEmail));
  assertEquals(409,error.status);
  assertEquals(id,uid(auth.google(identity)));
 }
 @Test void googleLockedAccountRejected() {
  var identity=identity();UUID id=uid(auth.google(identity));
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",id));
  assertThrows(ApiException.class,()->auth.google(identity));
 }
 @Test void surveyUsesSettingsOnly() {
  UUID id=uid(auth.google(identity()));
  var profile=auth.onboarding(id,List.of("KET_BAN","GAN_TOI"));
  assertTrue((Boolean)profile.get("onboardingCompleted"));
  assertEquals("[\"KET_BAN\",\"GAN_TOI\"]",profile.get("interestCodes"));
  assertThrows(ApiException.class,()->auth.onboarding(id,List.of("FAKE_CODE")));
 }
}
