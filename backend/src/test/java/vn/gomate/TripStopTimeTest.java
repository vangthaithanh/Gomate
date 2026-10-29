package vn.gomate;

import java.time.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import vn.gomate.common.ApiException;
import vn.gomate.trip.service.TripStopTime;
import static org.junit.jupiter.api.Assertions.*;

class TripStopTimeTest {
 private final ZoneId zone=ZoneId.of("Asia/Ho_Chi_Minh");
 private final LocalDate date=LocalDate.parse("2026-10-28");
 private final Instant now=Instant.parse("2026-10-28T03:00:00Z"); // 10:00
 private void validate(String start,String end,int day) {
  TripStopTime.validate(TripStopTime.normalize(start,end,null,zone),date.minusDays(1),date.plusDays(1),day,zone,now);
 }
 @ParameterizedTest @ValueSource(strings={"2026-10-27T20:00:00","2026-10-28T09:59:00","2026-10-28T10:00:00"})
 void rejectsPastDayPastTimeAndEqualNow(String start) {
  var error=assertThrows(ApiException.class,() -> validate(start,null,start.contains("27T")?1:2));
  assertEquals("TRIP_STOP_TIME_INVALID",error.code);
 }
 @Test void acceptsTodayFutureAndTomorrowMidnight() {
  validate("2026-10-28T10:01:00",null,2);
  validate("2026-10-29T00:00:00",null,3);
 }
 @ParameterizedTest @ValueSource(strings={"2026-10-29T09:59:00","2026-10-29T10:00:00","2026-10-30T00:01:00"})
 void rejectsInvalidIntervals(String end) {
  assertThrows(ApiException.class,() -> validate("2026-10-29T10:00:00",end,3));
 }
 @Test void oneMinuteAndOptionalSemantics() {
  validate("2026-10-29T10:00:00","2026-10-29T10:01:00",3);
  assertEquals(1,TripStopTime.normalize("2026-10-29T10:00:00","2026-10-29T10:01:00",null,zone).duration());
  assertNull(TripStopTime.normalize("2026-10-29T10:00:00",null,null,zone).duration());
  validate(null,null,1);
  validate(null,"2026-10-27T20:00:00",1);
 }
 @Test void rejectsDateMismatchAndDurationCrossingMidnight() {
  assertThrows(ApiException.class,() -> validate("2026-10-29T10:00:00",null,2));
  var value=TripStopTime.normalize("2026-10-29T23:50:00",null,20,zone);
  assertThrows(ApiException.class,() -> TripStopTime.validate(value,date,date.plusDays(1),2,zone,now));
 }
 @Test void ianaDstAndOffsetCompatibility() {
  var ny=ZoneId.of("America/New_York");
  assertEquals(Instant.parse("2027-07-01T14:00:00Z"),TripStopTime.parse("2027-07-01T10:00:00",ny).toInstant());
  assertEquals(Instant.parse("2027-01-01T15:00:00Z"),TripStopTime.parse("2027-01-01T10:00:00",ny).toInstant());
  assertEquals(Instant.parse("2027-01-01T03:00:00Z"),TripStopTime.parse("2027-01-01T10:00:00+07:00",ny).toInstant());
  assertThrows(ApiException.class,() -> TripStopTime.parse("2027-03-14T02:30:00",ny));
  assertEquals(Instant.parse("2027-11-07T05:30:00Z"),TripStopTime.parse("2027-11-07T01:30:00",ny).toInstant());
  assertThrows(ApiException.class,() -> TripStopTime.parse("invalid",ny));
 }
}
