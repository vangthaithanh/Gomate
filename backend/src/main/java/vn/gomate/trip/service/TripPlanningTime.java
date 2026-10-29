package vn.gomate.trip.service;

import java.time.*;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;

@Service
public class TripPlanningTime {
 private final Clock clock;
 public TripPlanningTime(Clock clock) { this.clock=clock; }
 public Instant now() { return clock.instant(); }
 public ZoneId zone(String value) {
  try { return ZoneId.of(value==null || value.isBlank()?"Asia/Ho_Chi_Minh":value); }
  catch(DateTimeException e) { throw ApiException.bad("Múi giờ không hợp lệ."); }
 }
 public Instant remindAt(LocalDate startDate,int daysBefore,String timezone) {
  if(daysBefore!=1 && daysBefore!=2) throw new IllegalArgumentException("D-2 or D-1 required");
  var local=startDate.minusDays(daysBefore).atTime(20,0);
  var zone=zone(timezone);
  var offsets=zone.getRules().getValidOffsets(local);
  return offsets.isEmpty()?null:local.toInstant(offsets.get(0));
 }
 public void validate(LocalDate start,LocalDate end,String timezone,boolean newStart,boolean newEnd) {
  if(start==null || end==null || end.isBefore(start)) throw ApiException.bad("Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.");
  LocalDate today=LocalDate.ofInstant(now(),zone(timezone));
  if((newStart && start.isBefore(today)) || (newEnd && end.isBefore(today))) throw ApiException.bad("Không thể chọn ngày trong quá khứ.");
 }
}
