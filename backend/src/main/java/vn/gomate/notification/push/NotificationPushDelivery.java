package vn.gomate.notification.push;

import jakarta.annotation.PreDestroy;
import java.util.*;
import java.util.concurrent.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import vn.gomate.notification.realtime.NotificationSignal;
import vn.gomate.notification.repository.NotificationDeviceRepository;
import vn.gomate.notification.repository.NotificationRepository;

@Component
public class NotificationPushDelivery {
 private static final Logger log=LoggerFactory.getLogger(NotificationPushDelivery.class);
 private final NotificationRepository inbox;
 private final NotificationDeviceRepository devices;
 private final FcmGateway fcm;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;
 private final ThreadPoolExecutor delivery=new ThreadPoolExecutor(1,2,30,TimeUnit.SECONDS,new ArrayBlockingQueue<>(64),r -> {
  Thread thread=new Thread(r,"notification-fcm-delivery"); thread.setDaemon(true); return thread;
 },new ThreadPoolExecutor.AbortPolicy());

 public NotificationPushDelivery(NotificationRepository inbox,NotificationDeviceRepository devices,FcmGateway fcm,vn.gomate.relationship.block.GlobalBlockPolicy blocks) {
  this.inbox=inbox; this.devices=devices; this.fcm=fcm;
  this.blocks=blocks;
 }

 public void enqueue(UUID userId,NotificationSignal signal) {
  if(!"CREATED".equals(signal.eventKind()) || signal.notificationId()==null) return;
  try { delivery.execute(() -> deliver(userId,signal)); }
  catch(RejectedExecutionException busy) { log.warn("FCM queue unavailable eventId={}; durable inbox retained",signal.eventId()); }
 }

 private void deliver(UUID userId,NotificationSignal signal) {
  try {
   var row=inbox.byId(userId,signal.notificationId()).orElse(null);
   if(row==null || Boolean.TRUE.equals(row.get("isRead"))) return;
   String type=(String)row.get("type");
   String status=(String)row.get("invitationStatus");
   boolean social="POST_COMMENT".equals(type) || "POST_REPLY".equals(type);
   if(!("TRIP_INVITATION".equals(type) && "PENDING".equals(status)) &&
      !("TRIP_INVITATION_ACCEPTED".equals(type) && "ACCEPTED".equals(status)) &&
      !("TRIP_START_REMINDER".equals(type) && row.get("tripId")!=null) && !social) return;
   String title=social?("POST_REPLY".equals(type)?"Bạn có phản hồi bình luận mới":"Bạn có bình luận mới"):
    "TRIP_START_REMINDER".equals(type)?(String)row.get("message"):"TRIP_INVITATION".equals(type)?"Lời mời lịch trình":"Lời mời đã được chấp nhận";
   for(var device:devices.activeAndroid(userId)) {
    try {
     if(social && blocks.either(userId,(UUID)row.get("actorId"))) return;
     var result=social?fcm.send((String)device.get("token"),userId,signal.notificationId(),title,"gomate_social_v1"):
      fcm.send((String)device.get("token"),userId,signal.notificationId(),title);
     if(result==FcmGateway.Result.UNREGISTERED) devices.invalidToken((UUID)device.get("id"),userId,
      (UUID)device.get("sessionId"),(String)device.get("token"));
     log.info("FCM delivery notificationId={} deviceId={} result={}",signal.notificationId(),device.get("id"),result);
    } catch(RuntimeException failure) {
     log.warn("FCM delivery failed notificationId={} deviceId={}; durable inbox retained",signal.notificationId(),device.get("id"));
    }
   }
  } catch(RuntimeException failure) {
   log.warn("FCM reconciliation failed eventId={}; durable inbox retained",signal.eventId());
  }
 }
 @PreDestroy public void shutdown() { delivery.shutdownNow(); }
}
