package vn.gomate.trip.service;

import java.util.*;
import org.springframework.stereotype.Component;
import vn.gomate.common.ApiException;
import vn.gomate.trip.model.TripStopSequenceItem;

@Component
public class TripStopSequenceValidator {
 public void validateNoAdjacentDuplicate(Collection<? extends TripStopSequenceItem> stops) {
  Map<Integer,List<TripStopSequenceItem>> byDay=new TreeMap<>();
  for(TripStopSequenceItem stop:stops) {
   byDay.computeIfAbsent(stop.dayNo(),ignored -> new ArrayList<>()).add(stop);
  }
  for(var entry:byDay.entrySet()) {
   List<TripStopSequenceItem> dayStops=entry.getValue();
   dayStops.sort(Comparator.comparingInt(TripStopSequenceItem::orderNo).thenComparing(TripStopSequenceItem::id));
   for(int i=1;i<dayStops.size();i++) {
    if(dayStops.get(i-1).placeId()==dayStops.get(i).placeId()) {
     throw new ApiException(
      400,
      "TRIP_STOP_ADJACENT_DUPLICATE",
      "Không thể để hai địa điểm giống nhau đứng liền nhau trong cùng một ngày."
     );
    }
   }
  }
 }
}
