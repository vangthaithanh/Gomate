package vn.gomate.trip.model;

import java.util.UUID;

public interface TripStopSequenceItem {
 UUID id();
 long placeId();
 int dayNo();
 int orderNo();
}
