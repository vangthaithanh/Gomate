package vn.gomate.location.service;

import java.time.Instant;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import vn.gomate.location.realtime.TripLocationStreamHub;
import vn.gomate.common.ApiException;
import vn.gomate.location.model.TripCurrentLocationDocument;
import vn.gomate.location.repository.TripLocationMongoRepository;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.repository.TripRepository;

@Service
public class TripLocationService {
 private final TripRepository trips;
 private final TripLocationMongoRepository locations;
 private final TripLocationStreamHub streams;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;

 public TripLocationService(TripRepository trips,TripLocationMongoRepository locations,TripLocationStreamHub streams,vn.gomate.relationship.block.GlobalBlockPolicy blocks) {
  this.trips=trips;
  this.locations=locations;
  this.streams=streams;
  this.blocks=blocks;
 }

 @Transactional
 public TripDtos.TripLocationItem publish(UUID actorId,UUID tripId,TripDtos.PublishLocationRequest req) {
  trips.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  trips.lockLocationActor(actorId);
  requireViewer(tripId,actorId);
  if(!trips.isPinned(tripId,actorId)) {
   throw new ApiException(403,"LOCATION_REQUIRES_PIN","Hãy ghim lịch trình trước khi gửi vị trí.");
  }
  validateCoordinate(req.latitude(),req.longitude());
  if(req.accuracyM()!=null && req.accuracyM()<0) throw ApiException.bad("Độ chính xác vị trí không hợp lệ.");
  Instant now=Instant.now();
  Instant capturedAt=req.capturedAt()==null?now:req.capturedAt().toInstant();
  var doc=locations.upsert(tripId,actorId,req.latitude(),req.longitude(),req.accuracyM(),capturedAt,now);
  afterCommit(() -> streams.updated(tripId,actorId,doc.getUpdatedAt()));
  var profiles=profilesByUserId(tripId);
  return item(doc,profiles.get(actorId));
 }

 @Transactional
 public List<TripDtos.TripLocationItem> list(UUID actorId,UUID tripId) {
  trips.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  requireViewer(tripId,actorId);
  Map<UUID,Map<String,Object>> profiles=profilesByUserId(tripId);
  var hidden=blocks.hidden(actorId,profiles.keySet());
  return locations.findByTrip(tripId).stream()
   .filter(doc -> profiles.containsKey(doc.getUserId()))
   .filter(doc -> !hidden.contains(doc.getUserId()))
   .filter(doc -> validCoordinate(doc.getLatitude(),doc.getLongitude()))
   .map(doc -> item(doc,profiles.get(doc.getUserId())))
   .sorted(Comparator.comparing(TripDtos.TripLocationItem::updatedAt,Comparator.nullsLast(Comparator.naturalOrder())).reversed())
   .toList();
 }

 private void requireViewer(UUID tripId,UUID userId) {
  if(!trips.permitsLocation(tripId,userId)) throw ApiException.notFound();
 }

 // Unpin/switch retains the last-known position; departure still revokes it.
 @Transactional(propagation=Propagation.REQUIRES_NEW)
 public void removeDepartedMemberSnapshot(UUID tripId,UUID userId) {
  trips.lockLocationActor(userId);
  if(trips.permitsLocation(tripId,userId)) return;
  try { locations.deleteByMember(tripId,userId); }
  catch(RuntimeException e) {
   org.slf4j.LoggerFactory.getLogger(TripLocationService.class).warn(
    "Member departure committed; snapshot cleanup failed: tripId={} userId={} errorType={}",
    tripId,userId,e.getClass().getSimpleName());
  }
  // REST also filters by active membership, even when Mongo cleanup failed.
  afterCommit(() -> streams.removed(tripId,userId));
 }

 private void afterCommit(Runnable action) {
  TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
   @Override public void afterCommit() {
    try { action.run(); }
    catch(RuntimeException e) { org.slf4j.LoggerFactory.getLogger(TripLocationService.class).warn("Location SSE unavailable; snapshot retained, REST can reconcile"); }
   }
  });
 }

 private Map<UUID,Map<String,Object>> profilesByUserId(UUID tripId) {
  return trips.locationMemberProfiles(tripId).stream()
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
