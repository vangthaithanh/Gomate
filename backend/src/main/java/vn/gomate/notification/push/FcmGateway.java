package vn.gomate.notification.push;

import java.util.UUID;

public interface FcmGateway {
 enum Result { SENT, UNREGISTERED, UNAVAILABLE, DISABLED }
 Result send(String token,UUID recipientId,UUID notificationId,String title);
 default Result send(String token,UUID recipientId,UUID notificationId,String title,String channel) {
  return send(token,recipientId,notificationId,title);
 }
}
