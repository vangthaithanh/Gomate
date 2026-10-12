package vn.gomate.location.service;

import java.time.Instant;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.location.model.TripCurrentLocationDocument;
import vn.gomate.location.repository.TripLocationMongoRepository;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.repository.TripRepository;

@Service
public class TripLocationService {
 private final TripRepository trips;
 private final TripLocationMongoRepository locations;

 public TripLocationService(TripRepository trips,TripLocationMongoRepository locations) {
  this.trips=trips;
  this.locations=locations;
 }

 @Transactional
 public TripDtos.TripLocationItem publish(UUID actorId,UUID tripId,TripDtos.PublishLocationRequest req) {
  requireActiveMember(tripId,actorId);
  validateCoordinate(req.latitude(),req.longitude());
  if(req.accuracyM()!=null && req.accuracyM()<0) throw ApiException.bad("Độ chính xác vị trí không hợp lệ.");
  trips.updateLocationSharing(tripId,actorId,true);
  Instant now=Instant.now();
  Instant capturedAt=req.capturedAt()==null?now:req.capturedAt().toInstant();
  var doc=locations.upsert(tripId,actorId,req.latitude(),req.longitude(),req.accuracyM(),capturedAt,now);
  var profiles=profilesByUserId(tripId);
  return item(doc,profiles.get(actorId));
 }

 public List<TripDtos.TripLocationItem> list(UUID actorId,UUID tripId) {
  requireActiveMember(tripId,actorId);
  Map<UUID,Map<String,Object>> profiles=profilesByUserId(tripId);
  Set<UUID> shareEnabled=trips.locationSharingEnabledUserIds(tripId);
  return locations.findByTrip(tripId).stream()
   .filter(doc -> profiles.containsKey(doc.getUserId()))
   .filter(doc -> shareEnabled.contains(doc.getUserId()))
   .filter(doc -> validCoordinate(doc.getLatitude(),doc.getLongitude()))
   .map(doc -> item(doc,profiles.get(doc.getUserId())))
   .sorted(Comparator.comparing(TripDtos.TripLocationItem::updatedAt,Comparator.nullsLast(Comparator.naturalOrder())).reversed())
   .toList();
 }

 private void requireActiveMember(UUID tripId,UUID userId) {
  if(!trips.isActiveMember(tripId,userId)) throw ApiException.notFound();
 }

 private Map<UUID,Map<String,Object>> profilesByUserId(UUID tripId) {
  return trips.activeMemberProfiles(tripId).stream()
   .collect(Collectors.toMap(row -> (UUID)row.get("userId"),Function.identity(),(a,b) -> a,LinkedHashMap::new));
 }

 private TripDtos.TripLocationItem item(TripCurrentLocationDocument doc,Map<String,Object> profile) {
  String displayName=profile==null?"Thành viên":(String)profile.get("displayName");
  String avatarUrl=profile==null?null:(String)profile.get("avatarUrl");
  return new TripDtos.TripLocationItem(
   doc.getUserId(),
   displayName,
   avatarUrl,
   doc.getLatitude(),
   doc.getLongitude(),
   doc.getAccuracyM(),
   doc.getCapturedAt(),
   doc.getUpdatedAt(),
   "LAST_KNOWN"
  );
 }

 private void validateCoordinate(double latitude,double longitude) {
  if(!validCoordinate(latitude,longitude)) throw ApiException.bad("Tọa độ vị trí không hợp lệ.");
 }

 private boolean validCoordinate(double latitude,double longitude) {
  return Double.isFinite(latitude) && Double.isFinite(longitude)
   && latitude>=-90 && latitude<=90
   && longitude>=-180 && longitude<=180;
 }
}
