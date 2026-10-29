package vn.gomate.trip.service;

import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.*;

@Configuration @EnableScheduling
@ConditionalOnProperty(name="app.trip-reminders.enabled",havingValue="true",matchIfMissing=true)
public class TripReminderScheduler {
 private final TripStartReminderService service;
 public TripReminderScheduler(TripStartReminderService service) { this.service=service; }
 @Scheduled(fixedDelayString="${app.trip-reminders.poll-ms:15000}",initialDelayString="${app.trip-reminders.poll-ms:15000}")
 public void tick() {
  try {
   for(var candidate:service.due()) {
    try { service.fire((UUID)candidate.get("id"),(UUID)candidate.get("tripId")); }
    catch(RuntimeException e) { org.slf4j.LoggerFactory.getLogger(getClass()).warn("Trip reminder processing failed id={} errorType={}",candidate.get("id"),e.getClass().getSimpleName()); }
   }
  } catch(RuntimeException e) { org.slf4j.LoggerFactory.getLogger(getClass()).warn("Trip reminder queue unavailable errorType={}",e.getClass().getSimpleName()); }
 }
}
