package vn.gomate.notification.push;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.*;
import java.time.Duration;
import java.util.UUID;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class FirebaseFcmGateway implements FcmGateway {
 private final ObjectProvider<FirebaseApp> firebase;
 private final boolean enabled;
 public FirebaseFcmGateway(ObjectProvider<FirebaseApp> firebase,@Value("${app.notification.push-enabled:false}") boolean enabled) {
  this.firebase=firebase; this.enabled=enabled;
 }
 @Override public Result send(String token,UUID recipientId,UUID notificationId,String title) {
  return send(token,recipientId,notificationId,title,"gomate_invitations_v1");
 }
 @Override public Result send(String token,UUID recipientId,UUID notificationId,String title,String channel) {
  FirebaseApp app=firebase.getIfAvailable();
  if(!enabled || app==null) return Result.DISABLED;
  Message message=Message.builder().setToken(token)
   .setNotification(Notification.builder().setTitle("GoMate").setBody(title).build())
   .putData("notificationId",notificationId.toString()).putData("recipientUserId",recipientId.toString()).putData("eventKind","CREATED")
   .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH).setTtl(Duration.ofHours(24).toMillis())
    .setNotification(AndroidNotification.builder().setChannelId(channel).setIcon("ic_stat_gomate")
     .setTag(notificationId.toString()).build()).build())
   .build();
  try {
   FirebaseMessaging.getInstance(app).send(message);
   return Result.SENT;
  } catch(FirebaseMessagingException failure) {
   // INVALID_ARGUMENT can mean an invalid payload, not an invalid token: do not purge it.
   return failure.getMessagingErrorCode()==MessagingErrorCode.UNREGISTERED?Result.UNREGISTERED:Result.UNAVAILABLE;
  }
 }
}
