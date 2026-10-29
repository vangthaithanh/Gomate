package vn.gomate.location.realtime;

import jakarta.annotation.PreDestroy;
import java.io.IOException;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.*;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.gomate.common.ApiException;
import vn.gomate.trip.repository.TripRepository;

/** Trip-scoped invalidation only. Never enters notification inbox/push delivery. */
@Component
public class TripLocationStreamHub {
 private final TripRepository trips;
 private final JwtDecoder decoder;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;
 private final ConcurrentMap<UUID,Connection> connections=new ConcurrentHashMap<>();
 private final ThreadPoolExecutor delivery=new ThreadPoolExecutor(1,2,30,TimeUnit.SECONDS,
  new ArrayBlockingQueue<>(128),r -> daemon(r,"trip-location-sse"),new ThreadPoolExecutor.AbortPolicy());
 private final ScheduledExecutorService heartbeat=Executors.newSingleThreadScheduledExecutor(r -> daemon(r,"trip-location-heartbeat"));
 private record Connection(UUID id,UUID tripId,UUID userId,Jwt jwt,SseEmitter emitter) {}
 public record Signal(String eventKind,UUID tripId,UUID userId,Instant updatedAt) {}

 public TripLocationStreamHub(TripRepository trips,JwtDecoder decoder,vn.gomate.relationship.block.GlobalBlockPolicy blocks) {
  this.trips=trips; this.decoder=decoder;
  this.blocks=blocks;
  heartbeat.scheduleWithFixedDelay(this::heartbeat,15,15,TimeUnit.SECONDS);
 }

 public synchronized SseEmitter connect(UUID tripId,Jwt jwt) {
  UUID userId=UUID.fromString(jwt.getSubject());
  if(!trips.permitsLocation(tripId,userId)) throw ApiException.notFound();
  if(connections.size()>=512 || connections.values().stream().filter(c -> c.userId().equals(userId)).count()>=4) {
   throw new ApiException(429,"LOCATION_STREAM_LIMIT","Quá nhiều kết nối vị trí. Vui lòng thử lại sau.");
  }
  var emitter=new SseEmitter(120000L);
  var connection=new Connection(UUID.randomUUID(),tripId,userId,jwt,emitter);
  emitter.onCompletion(() -> remove(connection));
  emitter.onTimeout(() -> close(connection));
  emitter.onError(ignored -> remove(connection));
  connections.put(connection.id(),connection);
  try { emitter.send(SseEmitter.event().name("ready").data("{}",MediaType.APPLICATION_JSON)); }
  catch(IOException e) { remove(connection); }
  return emitter;
 }

 public void updated(UUID tripId,UUID userId,Instant updatedAt) {
  var signal=new Signal("tripLocationUpdated",tripId,userId,updatedAt);
  for(var connection:connections.values()) if(connection.tripId().equals(tripId)) submit(connection,signal);
 }

 public void removed(UUID tripId,UUID userId) {
  var signal=new Signal("tripLocationRemoved",tripId,userId,Instant.now());
  for(var connection:connections.values()) if(connection.tripId().equals(tripId)) submit(connection,signal);
 }

 public void invalidate(UUID tripId) {
  for(var connection:connections.values()) if(connection.tripId().equals(tripId)) submit(connection,null);
 }

 public void accessChanged(UUID a,UUID b) {
  // No peer identity or GPS data is exposed in this generic invalidation.
  for(var connection:connections.values()) if(connection.userId().equals(a) || connection.userId().equals(b))
   submit(connection,new Signal("tripLocationsInvalidated",connection.tripId(),null,Instant.now()));
 }

 private void heartbeat() { for(var connection:connections.values()) submit(connection,null); }
 private void submit(Connection connection,Signal signal) {
  try { delivery.execute(() -> send(connection,signal)); }
  catch(RejectedExecutionException e) { close(connection); }
 }
 private void send(Connection connection,Signal signal) {
  synchronized(connection) {
   if(!connections.containsKey(connection.id())) return;
   try {
    decoder.decode(connection.jwt().getTokenValue());
    if(!trips.permitsLocation(connection.tripId(),connection.userId())) {
     connection.emitter().send(SseEmitter.event().name("tripUnavailable").data(
      new Signal("tripUnavailable",connection.tripId(),null,Instant.now()),MediaType.APPLICATION_JSON));
     close(connection);
     return;
    }
    if(signal!=null && signal.userId()!=null && blocks.either(connection.userId(),signal.userId())) return;
    if(signal==null) connection.emitter().send(SseEmitter.event().comment("keepalive"));
    else connection.emitter().send(SseEmitter.event().name(signal.eventKind()).data(signal,MediaType.APPLICATION_JSON));
   } catch(IOException e) { remove(connection); }
   catch(RuntimeException e) { close(connection); }
  }
 }
 private void remove(Connection c) { connections.remove(c.id()); }
 private void close(Connection c) { remove(c); c.emitter().complete(); }
 @PreDestroy public void shutdown() {
  heartbeat.shutdownNow(); connections.values().forEach(this::close); delivery.shutdownNow();
 }
 private static Thread daemon(Runnable action,String name) {
  Thread thread=new Thread(action,name); thread.setDaemon(true); return thread;
 }
}
