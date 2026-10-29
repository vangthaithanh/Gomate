package vn.gomate.trip.service;

import java.time.Clock;
import org.springframework.context.annotation.*;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;

@Configuration
public class TripReminderConfiguration {
 @Bean @ConditionalOnMissingBean(Clock.class)
 public Clock tripPlanningClock() { return Clock.systemUTC(); }
}
