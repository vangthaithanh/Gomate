package vn.gomate.auth;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.text.Normalizer;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.*;
import static vn.gomate.common.Db.args;
@Service
public class AuthService {
 private final AuthRepository repo;private final PasswordEncoder passwords;private final TokenService tokens;
 private final long refreshDays;private final String dummyHash;
 public AuthService(AuthRepository repo,PasswordEncoder passwords,TokenService tokens,@Value("${app.refresh-token-days}") long days) {
  this.repo=repo;this.passwords=passwords;this.tokens=tokens;this.refreshDays=days;dummyHash=passwords.encode(UUID.randomUUID().toString());
 }
 public static String email(String value) { return value.trim().toLowerCase(Locale.ROOT); }
 private void password(String value) {
  if(value.getBytes(StandardCharsets.UTF_8).length>72 || value.length()<8 || value.isBlank())
   throw ApiException.bad("Mật khẩu cần ít nhất 8 ký tự và tối đa 72 byte UTF-8.");
 }
 @Transactional
 public Map<String,Object> register(AuthDtos.Register req) {
  password(req.password());String nick=Normalizer.normalize(req.nickname().trim(),Normalizer.Form.NFC);
  if(nick.length()<3) throw ApiException.bad("Biệt danh cần ít nhất 3 ký tự.");
  UUID id=UUID.randomUUID();
  repo.db().update("INSERT INTO users(id,email,password_hash) VALUES(:id,:email,:hash)",args("id",id,"email",email(req.email()),"hash",passwords.encode(req.password())));
  repo.db().update("INSERT INTO user_profiles(user_id,nickname,nickname_key) VALUES(:id,:nick,:key)",args("id",id,"nick",nick,"key",nick.toLowerCase(Locale.ROOT)));
  repo.db().update("INSERT INTO user_settings(user_id) VALUES(:id)",args("id",id));
  return newSession(id);
 }
 @Transactional
 public Map<String,Object> login(AuthDtos.Login req) {
  var row=repo.byEmail(email(req.email())).orElse(null);
  boolean valid=req.password().getBytes(StandardCharsets.UTF_8).length<=72 && passwords.matches(req.password(),row==null || row.get("passwordHash")==null?dummyHash:(String)row.get("passwordHash"));
  if(!valid || row==null || row.get("passwordHash")==null) throw new ApiException(401,"INVALID_CREDENTIALS","Email hoặc mật khẩu không đúng.");
  UUID id=(UUID)row.get("id");
  // Khoá user trước session để đồng bộ login, refresh và đổi mật khẩu.
  var locked=repo.db().one("SELECT status,password_hash FROM users WHERE id=:id FOR UPDATE",args("id",id));
  if(!"ACTIVE".equals(locked.get("status"))) throw new ApiException(403,"ACCOUNT_LOCKED","Tài khoản đã bị khóa.");
  if(!row.get("passwordHash").equals(locked.get("passwordHash"))) throw ApiException.unauthorized();
  repo.db().update("UPDATE users SET last_login_at=CURRENT_TIMESTAMP WHERE id=:id",args("id",id));
  return newSession(id);
 }
 private Map<String,Object> newSession(UUID uid) {
  UUID sid=UUID.randomUUID();String refresh=tokens.refresh();
  repo.db().update("INSERT INTO refresh_sessions(id,user_id,refresh_hash,expires_at) VALUES(:id,:uid,:hash,:expiry)",
   args("id",sid,"uid",uid,"hash",TokenService.hash(refresh),"expiry",OffsetDateTime.now(ZoneOffset.UTC).plusDays(refreshDays)));
  return response(uid,sid,refresh);
 }
 private Map<String,Object> response(UUID uid,UUID sid,String refresh) {
  return Map.of("accessToken",tokens.access(uid,sid),"refreshToken",refresh,"tokenType","Bearer","expiresIn",tokens.accessSeconds,"user",repo.profile(uid));
 }
 @Transactional
 public Map<String,Object> refresh(String token) {
  String hash=TokenService.hash(token);
  var found=repo.db().list("SELECT user_id FROM refresh_sessions WHERE refresh_hash=:hash",args("hash",hash));
  if(found.isEmpty()) throw ApiException.unauthorized();UUID uid=(UUID)found.get(0).get("userId");
  repo.db().one("SELECT id FROM users WHERE id=:id FOR UPDATE",args("id",uid));
  var rows=repo.db().list("SELECT id FROM refresh_sessions WHERE refresh_hash=:hash FOR UPDATE",args("hash",hash));
  if(rows.isEmpty()) throw ApiException.unauthorized();UUID sid=(UUID)rows.get(0).get("id");
  if(!repo.activeSession(sid,uid)) throw ApiException.unauthorized();String next=tokens.refresh();
  repo.db().update("UPDATE refresh_sessions SET refresh_hash=:hash WHERE id=:id",args("id",sid,"hash",TokenService.hash(next)));
  return response(uid,sid,next);
 }
 @Transactional
 public void logout(UUID uid,UUID sid) {
  repo.db().update("UPDATE refresh_sessions SET revoked=TRUE WHERE id=:id AND user_id=:uid",args("id",sid,"uid",uid));
 }
 @Transactional
 public void changePassword(UUID uid,AuthDtos.ChangePassword req) {
  password(req.newPassword());var row=repo.db().one("SELECT password_hash FROM users WHERE id=:id FOR UPDATE",args("id",uid));
  if(req.currentPassword().getBytes(StandardCharsets.UTF_8).length>72 || !passwords.matches(req.currentPassword(),(String)row.get("passwordHash")))
   throw ApiException.bad("Mật khẩu hiện tại không đúng.");
  repo.db().update("UPDATE users SET password_hash=:hash WHERE id=:id",args("id",uid,"hash",passwords.encode(req.newPassword())));
  repo.db().update("UPDATE refresh_sessions SET revoked=TRUE WHERE user_id=:id",args("id",uid));
 }

 @Transactional
 public Map<String,Object> google(FirebaseGoogleVerifier.Identity identity) {
  var rows=repo.db().list("SELECT id FROM users WHERE google_subject=:sub FOR UPDATE",args("sub",identity.subject()));
  UUID uid;
  if(rows.isEmpty()) {
   if(repo.byEmail(identity.email()).isPresent())
    throw new ApiException(409,"GOOGLE_LINK_REQUIRED","Email đã có tài khoản. Đăng nhập bằng mật khẩu rồi liên kết Google trong trang cá nhân.");
   uid=UUID.randomUUID();
   repo.db().update("INSERT INTO users(id,email,google_subject) VALUES(:id,:email,:sub)",args("id",uid,"email",identity.email(),"sub",identity.subject()));
   String nickname="gomate_"+uid.toString().replace("-","").substring(0,20);
   repo.db().update("INSERT INTO user_profiles(user_id,nickname,nickname_key,full_name) VALUES(:id,:nick,:nick,:name)",args("id",uid,"nick",nickname,"name",identity.fullName()));
   repo.db().update("INSERT INTO user_settings(user_id) VALUES(:id)",args("id",uid));
  } else { uid=(UUID)rows.get(0).get("id"); }
  var user=repo.db().one("SELECT status FROM users WHERE id=:id FOR UPDATE",args("id",uid));
  if(!"ACTIVE".equals(user.get("status"))) throw new ApiException(403,"ACCOUNT_LOCKED","Tài khoản đã bị khóa.");
  repo.db().update("UPDATE users SET last_login_at=CURRENT_TIMESTAMP WHERE id=:id",args("id",uid));
  return newSession(uid);
 }
 @Transactional
 public Map<String,Object> linkGoogle(UUID uid,FirebaseGoogleVerifier.Identity identity) {
  var user=repo.db().one("SELECT email,google_subject,status FROM users WHERE id=:id FOR UPDATE",args("id",uid));
  if(!"ACTIVE".equals(user.get("status"))) throw ApiException.unauthorized();
  if(!identity.email().equals(user.get("email"))) throw ApiException.bad("Hãy chọn Google có cùng email với tài khoản GoMate.");
  if(user.get("googleSubject")!=null && !identity.subject().equals(user.get("googleSubject")))
   throw ApiException.bad("Tài khoản đã liên kết với một Google khác.");
  repo.db().update("UPDATE users SET google_subject=:sub WHERE id=:id",args("id",uid,"sub",identity.subject()));
  return repo.profile(uid);
 }
 @Transactional
 public Map<String,Object> onboarding(UUID uid,List<String> codes) {
  Set<String> allowed=Set.of("KET_BAN","NGHI_DUONG","CHECKIN_HOT","THIEN_NHIEN","VAN_HOA","AM_THUC","MUC_DICH_KHAC","BIEN_NUI","TRUNG_TAM","DIA_DANH_NOI_TIENG","LANG_NGHE_DI_TICH","NGOAI_O_DONG_QUE","LOAI_KHAC","GAN_TOI","LOCAL","DANG_HOT","DI_TRONG_NGAY","CO_REVIEW","UU_TIEN_KHAC");
  if(!allowed.containsAll(codes)) throw ApiException.bad("Lựa chọn khảo sát không hợp lệ.");
  String json="["+String.join(",",new LinkedHashSet<>(codes).stream().map(c->"\""+c+"\"").toList())+"]";
  repo.db().update("UPDATE user_settings SET onboarding_completed=TRUE,interest_codes=:codes WHERE user_id=:id",args("id",uid,"codes",json));
  return repo.profile(uid);
 }
}
