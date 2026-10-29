package vn.gomate.notification.realtime;

import jakarta.annotation.PreDestroy;
import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.gomate.common.ApiException;

@Component
public class NotificationStreamHub {
 private static final Logger log=LoggerFactory.getLogger(NotificationStreamHub.class);
 private final JwtDecoder decoder;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;
 private final vn.gomate.notification.repository.NotificationRepository inbox;
 private final ConcurrentMap<UUID,Connection> connections=new ConcurrentHashMap<>();
 private final ThreadPoolExecutor delivery=new ThreadPoolExecutor(2,4,30,TimeUnit.SECONDS,
  new ArrayBlockingQueue<>(128),r -> daemon(r,"notification-sse-delivery"),new ThreadPoolExecutor.AbortPolicy());
 private final ScheduledExecutorService heartbeat=Executors.newSingleThreadScheduledExecutor(r -> daemon(r,"notification-sse-heartbeat"));

 private record Connection(UUID id,UUID userId,Jwt jwt,SseEmitter emitter) {}

 public NotificationStreamHub(JwtDecoder decoder,vn.gomate.relationship.block.GlobalBlockPolicy blocks,vn.gomate.notification.repository.NotificationRepository inbox) {
  this.decoder=decoder;
  this.blocks=blocks;this.inbox=inbox;
  heartbeat.scheduleWithFixedDelay(this::heartbeat,15,15,TimeUnit.SECONDS);
 }

 public synchronized SseEmitter connect(Jwt jwt) {
  UUID userId=UUID.fromString(jwt.getSubject());
  if(connections.size()>=1024 || connections.values().stream().filter(c -> c.userId().equals(userId)).count()>=8) {
   throw new ApiException(429,"REALTIME_CONNECTION_LIMIT","Too many notification connections; polling remains available.");
  }
  SseEmitter emitter=new SseEmitter(120000L);
  Connection connection=new Connection(UUID.randomUUID(),userId,jwt,emitter);
  emitter.onCompletion(() -> remove(connection));
  emitter.onTimeout(() -> close(connection));
  emitter.onError(ignored -> remove(connection));
  connections.put(connection.id(),connection);
  try {
   emitter.send(SseEmitter.event().name("ready").data("{}",MediaType.APPLICATION_JSON));
   log.debug("Notification stream connect connectionId={}",connection.id());
  } catch(IOException failure) { remove(connection); }
  return emitter;
 }

 public void publish(UUID recipientId,NotificationSignal signal) {
  for(Connection connection:connections.values()) {
   if(connection.userId().equals(recipientId)) submit(connection,signal);
  }
 }

 private void heartbeat() {
  for(Connection connection:connections.values()) submit(connection,null);
 }

 private void submit(Connection connection,NotificationSignal signal) {
  try {
   delivery.execute(() -> send(connection,signal));
  } catch(RejectedExecutionException busy) {
   // Bounded best-effort delivery must not delay committed business requests.
   close(connection);
  }
 }

 private void send(Connection connection,NotificationSignal signal) {
  synchronized(connection) {
   if(!connections.containsKey(connection.id())) return;
   try {
    // Reuse the exact JWT/session validator; revoked or expired sessions stop receiving.
    decoder.decode(connection.jwt().getTokenValue());
    if(signal!=null && "CREATED".equals(signal.eventKind()) && signal.notificationId()!=null) {
     var row=inbox.byId(connection.userId(),signal.notificationId()).orElse(null);
     if(row==null) return;
     if(((String)row.get("type")).startsWith("POST_") && blocks.either(connection.userId(),(UUID)row.get("actorId"))) return;
    }
    if(signal==null) connection.emitter().send(SseEmitter.event().comment("keepalive"));
    else connection.emitter().send(SseEmitter.event().id(signal.eventId().toString())
     .name("notification").data(signal,MediaType.APPLICATION_JSON));
   } catch(IOException disconnected) {
    remove(connection);
   } catch(RuntimeException unavailable) {
    close(connection);
   }
  }
 }

 private void remove(Connection connection) {
  if(connections.remove(connection.id())!=null) log.debug("Notification stream disconnect connectionId={}",connection.id());
 }

 private void close(Connection connection) {
  remove(connection);
  connection.emitter().complete();
 }

 @PreDestroy public void shutdown() {
  heartbeat.shutdownNow();
  connections.values().forEach(this::close);
  delivery.shutdownNow();
 }

 private static Thread daemon(Runnable action,String name) {
  Thread thread=new Thread(action,name);
  thread.setDaemon(true);
  return thread;
 }
}
