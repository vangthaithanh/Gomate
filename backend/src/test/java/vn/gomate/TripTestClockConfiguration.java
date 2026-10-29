package vn.gomate;

import java.time.*;
import org.springframework.context.annotation.*;

/** Test-only planning clock; JWT/session clocks remain real and unchanged. */
@Configuration @Profile("test")
public class TripTestClockConfiguration {
 @Bean @Primary public PlanningClock tripTestClock() { return new PlanningClock(); }
 public static class PlanningClock extends Clock {
  private volatile Instant now=Instant.parse("2026-01-01T00:00:00Z");
  public void at(String value) { now=Instant.parse(value); }
  public void reset() { at("2026-01-01T00:00:00Z"); }
  @Override public Instant instant() { return now; }
  @Override public ZoneId getZone() { return ZoneOffset.UTC; }
  @Override public Clock withZone(ZoneId zone) { return Clock.fixed(now,zone); }
 }
}
