package vn.gomate.notification.repository;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class NotificationDeviceRepository {
 private final Db db;
 public NotificationDeviceRepository(Db db) { this.db=db; }

 public void register(UUID userId,UUID sessionId,UUID installationId,String token,String platform) {
  var rows=db.list("SELECT id,installation_id FROM device_tokens WHERE installation_id=:installation OR token=:token FOR UPDATE",
   args("installation",installationId,"token",token));
  // Possession of this opaque installation ID/token rebinds this install, not other devices.
  db.update("DELETE FROM device_tokens WHERE token=:token AND installation_id<>:installation",args("token",token,"installation",installationId));
  var existing=rows.stream().filter(r -> installationId.equals(r.get("installationId"))).findFirst();
  var params=args("id",existing.map(r -> (UUID)r.get("id")).orElseGet(UUID::randomUUID),"user",userId,
   "session",sessionId,"installation",installationId,"token",token,"platform",platform);
  if(existing.isPresent()) {
   db.update("""
    UPDATE device_tokens SET user_id=:user,session_id=:session,token=:token,platform=:platform,enabled=TRUE,
     updated_at=CURRENT_TIMESTAMP,last_seen_at=CURRENT_TIMESTAMP WHERE id=:id
    """,params);
  } else {
   db.update("""
    INSERT INTO device_tokens(id,user_id,session_id,installation_id,token,platform)
    VALUES(:id,:user,:session,:installation,:token,:platform)
    """,params);
  }
 }

 public void unregister(UUID userId,UUID sessionId,UUID installationId) {
  db.update("""
   UPDATE device_tokens SET enabled=FALSE,updated_at=CURRENT_TIMESTAMP
   WHERE user_id=:user AND session_id=:session AND installation_id=:installation
   """,args("user",userId,"session",sessionId,"installation",installationId));
 }

 public List<Map<String,Object>> activeAndroid(UUID userId) {
  return db.list("""
   SELECT d.id,d.user_id,d.session_id,d.token FROM device_tokens d
   JOIN refresh_sessions s ON s.id=d.session_id AND s.user_id=d.user_id
   JOIN users u ON u.id=d.user_id
   JOIN user_settings settings ON settings.user_id=d.user_id
   WHERE d.user_id=:user AND d.enabled=TRUE AND d.platform='ANDROID'
    AND s.revoked=FALSE AND s.expires_at>CURRENT_TIMESTAMP AND u.status='ACTIVE'
    AND settings.notifications_enabled=TRUE
   """,args("user",userId));
 }

 public void invalidToken(UUID id,UUID userId,UUID sessionId,String token) {
  db.update("""
   UPDATE device_tokens SET enabled=FALSE,updated_at=CURRENT_TIMESTAMP
   WHERE id=:id AND user_id=:user AND session_id=:session AND token=:token
   """,args("id",id,"user",userId,"session",sessionId,"token",token));
 }
}
