package vn.gomate.auth;
import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.*;
import static vn.gomate.common.Db.args;
@Repository
public class AuthRepository {
 private final Db db;
 public Db db() { return db; }
 public AuthRepository(Db db) { this.db=db; }
 public Map<String,Object> profile(UUID id) {
  return db.one("""
   SELECT u.id,u.email,u.role,u.status,u.created_at,u.last_login_at,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,s.onboarding_completed,s.interest_codes,
   CASE WHEN u.google_subject IS NULL THEN FALSE ELSE TRUE END AS google_linked
   FROM users u JOIN user_profiles p ON p.user_id=u.id JOIN user_settings s ON s.user_id=u.id WHERE u.id=:id
   """,args("id",id));
 }
 public Optional<Map<String,Object>> byEmail(String email) {
  return db.list("SELECT * FROM users WHERE email=:email",args("email",email)).stream().findFirst();
 }
 public boolean activeSession(UUID sid,UUID uid) {
  return db.count("""
   SELECT COUNT(*) FROM refresh_sessions s JOIN users u ON u.id=s.user_id
   WHERE s.id=:sid AND s.user_id=:uid AND s.revoked=FALSE AND s.expires_at>CURRENT_TIMESTAMP AND u.status='ACTIVE'
   """,args("sid",sid,"uid",uid))==1;
 }
}
