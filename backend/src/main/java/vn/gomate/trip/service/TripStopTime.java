package vn.gomate.trip.service;

import java.time.*;
import java.util.Objects;
import vn.gomate.common.ApiException;

/** Stop occurrences only. No reminder scheduling or Trip date rebasing. */
public final class TripStopTime {
 private TripStopTime() {}
 public record Value(OffsetDateTime start,Integer duration) {}

 public static OffsetDateTime parse(String raw,ZoneId zone) {
  if(raw==null) return null;
  try {
   // Existing offset-bearing clients remain supported. New local wall input is
   // resolved by Spring against the authoritative Trip IANA zone.
   try { return OffsetDateTime.parse(raw).withOffsetSameInstant(ZoneOffset.UTC); }
   catch(DateTimeException ignored) {
    LocalDateTime wall=LocalDateTime.parse(raw);
    var offsets=zone.getRules().getValidOffsets(wall);
    if(offsets.isEmpty()) throw error("Giờ này không tồn tại trong múi giờ lịch trình.");
    // Deterministic first occurrence during a DST overlap (same as reminders).
    return wall.atOffset(offsets.get(0)).withOffsetSameInstant(ZoneOffset.UTC);
   }
  } catch(DateTimeException e) { throw error("Giờ địa điểm không hợp lệ."); }
 }

 public static Value normalize(String startRaw,String endRaw,Integer duration,ZoneId zone) {
  if(startRaw==null) return new Value(null,null); // end-only has no meaning
  OffsetDateTime start=parse(startRaw,zone);
  OffsetDateTime end=parse(endRaw,zone);
  if(end!=null) {
   Duration interval=Duration.between(start,end);
   if(interval.isNegative() || interval.isZero() || interval.getSeconds()%60!=0 || interval.getNano()!=0)
    throw error("Giờ kết thúc phải sau giờ bắt đầu, với khoảng giờ tính theo phút.");
   if(interval.toMinutes()>Integer.MAX_VALUE) throw error("Khoảng giờ không hợp lệ.");
   duration=(int)interval.toMinutes();
  }
  return new Value(start,duration);
 }

 public static boolean same(Value a,OffsetDateTime start,Integer duration) {
  return (a.start()==null?start==null:start!=null && a.start().isEqual(start))
   && Objects.equals(a.duration(),duration);
 }

 public static void validate(Value time,LocalDate tripStart,LocalDate tripEnd,int dayNo,ZoneId zone,Instant now) {
  if(time.start()==null) return; // explicit clear/optional times remain possible
  validateDay(tripStart,tripEnd,dayNo);
  LocalDate day=tripStart.plusDays(dayNo-1);
  var localStart=time.start().atZoneSameInstant(zone);
  if(!localStart.toLocalDate().equals(day)) throw error("Giờ bắt đầu không thuộc ngày địa điểm đã chọn.");
  if(day.isBefore(LocalDate.ofInstant(now,zone)))
   throw error("Ngày địa điểm đã qua. Hãy sửa ngày lịch trình trước khi đặt giờ mới.");
  if(!time.start().toInstant().isAfter(now)) throw error("Giờ bắt đầu phải ở tương lai tại thời điểm lưu.");
  if(time.duration()!=null) {
   if(time.duration()<=0) throw error("Giờ kết thúc phải sau giờ bắt đầu.");
   var end=localStart.plusMinutes(time.duration());
   if(!end.toLocalDate().equals(day) || !end.toLocalTime().isAfter(localStart.toLocalTime()))
    throw error("Giờ kết thúc phải sau giờ bắt đầu trong cùng ngày địa điểm.");
  }
 }

 public static void validateDay(LocalDate tripStart,LocalDate tripEnd,int dayNo) {
  if(tripStart==null || tripEnd==null || dayNo<1 || dayNo>java.time.temporal.ChronoUnit.DAYS.between(tripStart,tripEnd)+1)
   throw error("Ngày địa điểm phải nằm trong lịch trình.");
 }

 private static ApiException error(String message) {
  return new ApiException(400,"TRIP_STOP_TIME_INVALID",message);
 }
}
