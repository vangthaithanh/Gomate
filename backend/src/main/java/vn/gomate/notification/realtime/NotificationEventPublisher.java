package vn.gomate.notification.realtime;

import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import vn.gomate.notification.push.NotificationPushDelivery;

@Component
public class NotificationEventPublisher {
 private static final Logger log=LoggerFactory.getLogger(NotificationEventPublisher.class);
 private final ApplicationEventPublisher events;
 private final NotificationStreamHub streams;
 private final NotificationPushDelivery push;
 public NotificationEventPublisher(ApplicationEventPublisher events,NotificationStreamHub streams,NotificationPushDelivery push) {
  this.events=events;
  this.streams=streams;
  this.push=push;
 }

 public record Change(UUID recipientId,NotificationSignal signal) {}

 public void changed(UUID recipientId,UUID notificationId,String kind) {
  events.publishEvent(new Change(recipientId,new NotificationSignal(UUID.randomUUID(),kind,notificationId,Instant.now())));
 }

 // No fallback execution: rollback or a missing transaction must never emit.
 @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT)
 public void afterCommit(Change change) {
  try {
   streams.publish(change.recipientId(),change.signal());
   log.debug("Notification event emitted eventId={} kind={} notificationId={}",
    change.signal().eventId(),change.signal().eventKind(),change.signal().notificationId());
  } catch(RuntimeException failure) {
   log.warn("Notification delivery unavailable eventId={} kind={}; REST/polling will reconcile",
    change.signal().eventId(),change.signal().eventKind());
  }
  try { push.enqueue(change.recipientId(),change.signal()); }
  catch(RuntimeException failure) { log.warn("FCM unavailable eventId={}; durable inbox retained",change.signal().eventId()); }
 }
}
