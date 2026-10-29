package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.*;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.location.model.TripCurrentLocationDocument;
import vn.gomate.location.repository.TripLocationMongoRepository;
import vn.gomate.location.realtime.TripLocationStreamHub;
import vn.gomate.message.service.MessageMongoService;
import vn.gomate.notification.push.NotificationPushDelivery;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class TripLocationSharingTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @MockitoBean TripLocationMongoRepository mongo;
 @MockitoBean MessageMongoService messages;
 @MockitoBean NotificationPushDelivery pushes;
 @MockitoSpyBean TripLocationStreamHub streams;
 final Map<String,TripCurrentLocationDocument> snapshots=new ConcurrentHashMap<>();
 @BeforeEach void setup() {
  snapshots.clear();
  doAnswer(i -> { snapshots.remove(i.getArgument(0)+":"+i.getArgument(1)); return null; }).when(mongo).deleteByMember(any(),any());
  doAnswer(i -> { snapshots.values().removeIf(d -> d.getTripId().equals(i.getArgument(0))); return null; }).when(mongo).deleteByTrip(any());
  when(mongo.findByTrip(any())).thenAnswer(i -> snapshots.values().stream().filter(d -> d.getTripId().equals(i.getArgument(0))).toList());
  when(mongo.upsert(any(),any(),anyDouble(),anyDouble(),any(),any(),any())).thenAnswer(i -> snapshot(i.getArgument(0),i.getArgument(1),i.getArgument(2),i.getArgument(3),i.getArgument(4),i.getArgument(5),i.getArgument(6)));
 }
 @AfterEach void cleanup() {
  reset(streams);
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 @Test void ownPinIsTheOnlyPublishIntentAndNeverPinsAnotherUser() throws Exception {
  var a=user(); var b=user(); var stranger=user(); String id=group(a,b); String path="/api/v1/trips/"+id;
  assertTrue(call(get("/api/v1/trips/pinned"),b,null,200).path("trip").isNull());
  call(put(path+"/location"),b,coordinates(),403);
  call(post(path+"/pin"),a,null,200);
  call(put(path+"/location"),b,coordinates(),403);
  call(post(path+"/pin"),stranger,null,404);
  call(post(path+"/pin"),b,null,200);
  call(put(path+"/location"),b,coordinates(),200);
  call(delete(path+"/pin"),b,null,204);
  assertEquals(id,call(get("/api/v1/trips/pinned"),a,null,200).path("trip").path("id").asText());
  call(put(path+"/location"),b,coordinates(),403);
  assertEquals(1,snapshots.size());
  assertEquals(b.id.toString(),call(get(path+"/locations"),a,null,200).get(0).path("userId").asText());
 }

 @Test void unpinRetainsExactLastKnownSnapshotForBothMembersWithoutNewPublish() throws Exception {
  var a=user(); var b=user(); var stranger=user(); String id=group(a,b); String path="/api/v1/trips/"+id;
  activate(a,b,id); call(post(path+"/pin"),a,null,200);
  assertEquals(0,call(get(path+"/locations"),a,null,200).size());
  call(put(path+"/location"),b,Map.of("latitude",100,"longitude",108.4),400);
  call(put(path+"/location"),b,Map.of("latitude",11.9,"longitude",108.4,"accuracyM",-1),400);
  call(put(path+"/location"),b,Map.of("latitude",11.9,"longitude",108.4,"userId",a.id),400);
  var first=call(put(path+"/location"),b,Map.of("latitude",11.9,"longitude",108.4,"capturedAt","2020-01-01T00:00:00Z"),200);
  Thread.sleep(3);
  var next=call(put(path+"/location"),b,coordinates(),200);
  assertEquals(b.id.toString(),next.path("userId").asText());
  assertEquals(1,snapshots.size());
  assertTrue(Instant.parse(next.path("updatedAt").asText()).isAfter(Instant.parse(first.path("updatedAt").asText())));
  assertTrue(Instant.parse(first.path("updatedAt").asText()).isAfter(Instant.parse("2026-01-01T00:00:00Z")));
  call(put(path+"/location"),a,coordinates(),200);
  clearInvocations(mongo,streams);
  call(delete(path+"/pin"),b,null,204);
  call(delete(path+"/pin"),b,null,204);
  var rows=call(get(path+"/locations"),a,null,200);
  assertEquals(2,rows.size());
  var retained=java.util.stream.StreamSupport.stream(rows.spliterator(),false)
   .filter(row -> b.id.toString().equals(row.path("userId").asText())).findFirst().orElseThrow();
  assertEquals(next,retained);
  assertEquals("LAST_KNOWN",retained.path("locationState").asText());
  assertEquals(rows,call(get(path+"/locations"),b,null,200));
  call(put(path+"/location"),b,coordinates(),403);
  verify(mongo,never()).deleteByMember(any(),any());
  verify(mongo,never()).upsert(any(),any(),anyDouble(),anyDouble(),any(),any(),any());
  verify(streams,never()).removed(any(),any());
  call(get(path+"/locations"),stranger,null,404);
 }

 @Test void lastKnownRequiresCurrentMemberAndActiveAccountButNeverInventsMissingSnapshot() throws Exception {
  var a=user(); var b=user(); String id=group(a,b); String path="/api/v1/trips/"+id;
  call(post(path+"/pin"),a,null,200);
  assertEquals(0,call(get(path+"/locations"),a,null,200).size());
  call(post(path+"/pin"),b,null,200);
  call(put(path+"/location"),b,coordinates(),200);
  call(delete(path+"/pin"),b,null,204);
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",b.id));
  assertEquals(0,call(get(path+"/locations"),a,null,200).size());
  db.update("UPDATE users SET status='ACTIVE' WHERE id=:id",args("id",b.id));
  assertEquals(1,call(get(path+"/locations"),a,null,200).size());
 }

 @Test void mongoFailureHasNoRealtimeSuccess() throws Exception {
  var a=user(); var b=user(); String id=group(a,b); activate(a,b,id);
  doThrow(new ApiException(503,"LOCATION_STORE_UNAVAILABLE","fixture failure")).when(mongo).upsert(any(),any(),anyDouble(),anyDouble(),any(),any(),any());
  clearInvocations(streams);
  call(put("/api/v1/trips/"+id+"/location"),b,coordinates(),503);
  verify(streams,never()).updated(any(),any(),any()); assertTrue(snapshots.isEmpty());
 }

 @Test void sseFailureDoesNotUndoSnapshotAndNoInboxOrPushSignal() throws Exception {
  var a=user(); var b=user(); String id=group(a,b); activate(a,b,id);
  long count=db.count("SELECT COUNT(*) FROM notifications",Map.of());
  doThrow(new IllegalStateException("transport unavailable")).when(streams).updated(any(),any(),any());
  clearInvocations(pushes);
  call(put("/api/v1/trips/"+id+"/location"),b,coordinates(),200);
  assertEquals(1,snapshots.size()); assertEquals(count,db.count("SELECT COUNT(*) FROM notifications",Map.of()));
  verifyNoInteractions(pushes);
 }

 @ParameterizedTest @ValueSource(strings={"leave","remove","archive"})
 void membershipOrDeleteStopsPublishAndViewAuthority(String mode) throws Exception {
  var a=user(); var b=user(); String id=group(a,b); String path="/api/v1/trips/"+id; activate(a,b,id);
  call(put(path+"/location"),b,coordinates(),200);
  switch(mode) {
   case "leave" -> call(delete(path+"/members/me"),b,null,204);
   case "remove" -> call(delete(path+"/members/"+b.id),a,null,200);
   default -> call(delete(path),a,null,204);
  }
  call(put(path+"/location"),b,coordinates(),404);
  call(get(path+"/locations"),b,null,404);
  assertTrue(snapshots.isEmpty());
 }

 @ParameterizedTest @ValueSource(strings={"FOREGROUND","BACKGROUND"})
 void bothRuntimeModesRequireOwnPin(String mode) throws Exception {
  var a=user(); var b=user(); String id=group(a,b); String path="/api/v1/trips/"+id;
  var body=new HashMap<String,Object>(coordinates()); body.put("runtimeMode",mode);
  call(put(path+"/location"),b,body,403);
  call(post(path+"/pin"),b,null,200); call(put(path+"/location"),b,body,200);
  call(delete(path+"/pin"),b,null,204); call(put(path+"/location"),b,body,403);
 }

 @Test void membershipCleanupFailureStillHidesDepartedMemberLastKnownMarker() throws Exception {
  var a=user(); var b=user(); String id=group(a,b); String path="/api/v1/trips/"+id; activate(a,b,id);
  call(put(path+"/location"),b,coordinates(),200);
  doThrow(new IllegalStateException("offline")).when(mongo).deleteByMember(UUID.fromString(id),b.id);
  call(delete(path+"/members/me"),b,null,204);
  assertEquals(1,snapshots.size());
  assertEquals(0,call(get(path+"/locations"),a,null,200).size());
  assertTrue(call(get("/api/v1/trips/pinned"),b,null,200).path("trip").isNull());
  verify(streams).removed(UUID.fromString(id),b.id);
  call(get(path+"/locations"),b,null,404);
 }

 @Test void switchingPinRetainsPreviousLastKnownWithoutCopyingNewTripCoordinates() throws Exception {
  var a=user(); var b=user(); String first=group(a,b),second=group(a,b);
  activate(a,b,first);
  call(post("/api/v1/trips/"+first+"/pin"),a,null,200);
  call(put("/api/v1/trips/"+first+"/location"),a,coordinates(),200);
  var last=call(put("/api/v1/trips/"+first+"/location"),b,coordinates(),200);
  call(post("/api/v1/trips/"+second+"/pin"),b,null,200);
  assertEquals(2,snapshots.size());
  call(put("/api/v1/trips/"+first+"/location"),b,coordinates(),403);
  call(put("/api/v1/trips/"+second+"/location"),b,Map.of("latitude",12.5,"longitude",109.1),200);
  var previous=call(get("/api/v1/trips/"+first+"/locations"),a,null,200);
  assertEquals(2,previous.size());
  assertTrue(java.util.stream.StreamSupport.stream(previous.spliterator(),false).anyMatch(last::equals));
  assertEquals(3,snapshots.size());
  call(delete("/api/v1/trips/"+first+"/pin"),b,null,204);
  assertEquals(second,call(get("/api/v1/trips/pinned"),b,null,200).path("trip").path("id").asText());
  call(post("/api/v1/trips/"+first+"/pin"),b,null,200);
  call(put("/api/v1/trips/"+first+"/location"),b,coordinates(),200);
  assertEquals(3,snapshots.size());
 }

 @Test void sseAuthenticatedMinimalRemovalAndRevocation() throws Exception {
  var a=user(); var b=user(); var stranger=user(); String id=group(a,b); activate(a,b,id); String path="/api/v1/trips/"+id;
  mvc.perform(get(path+"/locations/stream")).andExpect(status().isUnauthorized());
  call(get(path+"/locations/stream"),stranger,null,404);
  call(get(path+"/locations/stream?userId="+b.id),a,null,400);
  var connected=mvc.perform(get(path+"/locations/stream").header("Authorization",a.token)).andExpect(request().asyncStarted()).andReturn();
  call(put(path+"/location"),b,coordinates(),200);
  waitFor(connected,"tripLocationUpdated");
  call(delete(path+"/pin"),b,null,204);
  verify(streams,never()).removed(UUID.fromString(id),b.id);
  call(delete(path+"/members/"+b.id),a,null,200);
  waitFor(connected,"tripLocationRemoved");
  String content=connected.getResponse().getContentAsString();
  assertFalse(content.contains("latitude")); assertFalse(content.contains("longitude")); assertFalse(content.contains("notificationId"));
  call(delete(path),a,null,204); waitFor(connected,"tripUnavailable");
 }

 @Test void unpinSerializesWithInflightPublish() throws Exception {
  var a=user(); var b=user(); String id=group(a,b); activate(a,b,id);
  var entered=new CountDownLatch(1); var release=new CountDownLatch(1);
  doAnswer(i -> { entered.countDown(); assertTrue(release.await(10,TimeUnit.SECONDS)); return snapshot(i.getArgument(0),i.getArgument(1),i.getArgument(2),i.getArgument(3),i.getArgument(4),i.getArgument(5),i.getArgument(6)); })
   .when(mongo).upsert(any(),any(),anyDouble(),anyDouble(),any(),any(),any());
  var pool=Executors.newFixedThreadPool(2);
  try {
   var publish=pool.submit(() -> call(put("/api/v1/trips/"+id+"/location"),b,coordinates(),200));
   assertTrue(entered.await(5,TimeUnit.SECONDS));
   var off=pool.submit(() -> call(delete("/api/v1/trips/"+id+"/pin"),b,null,204));
   release.countDown(); publish.get(15,TimeUnit.SECONDS); off.get(15,TimeUnit.SECONDS);
   call(put("/api/v1/trips/"+id+"/location"),b,coordinates(),403);
   assertEquals(1,snapshots.size());
   assertEquals(b.id.toString(),call(get("/api/v1/trips/"+id+"/locations"),a,null,200).get(0).path("userId").asText());
  } finally { release.countDown(); pool.shutdownNow(); }
 }

 @Test void globalBlockFiltersLastKnownPerViewerInvalidatesImmediatelyAndKeepsGroupData() throws Exception {
  var a=user();var b=user();var c=user();
  var trip=call(post("/api/v1/trips"),a,Map.of("title","Block location fixture","startDate","2026-12-01","endDate","2026-12-02","selectedMemberIds",List.of(b.id,c.id)),201);
  for(var invite:trip.path("pendingInvitations")) {
   var recipient=invite.toString().contains(b.id.toString())?b:c;
   call(post("/api/v1/trip-invitations/"+invite.path("invitationId").asText()+"/accept"),recipient,null,200);
  }
  String id=trip.path("id").asText(),path="/api/v1/trips/"+id;
  for(var u:List.of(a,b,c)) {call(post(path+"/pin"),u,null,200);call(put(path+"/location"),u,coordinates(),200);}
  call(delete(path+"/pin"),b,null,204);
  var prior=snapshots.get(id+":"+b.id).getUpdatedAt();
  var streamA=mvc.perform(get(path+"/locations/stream").header("Authorization",a.token)).andExpect(request().asyncStarted()).andReturn();
  var streamB=mvc.perform(get(path+"/locations/stream").header("Authorization",b.token)).andExpect(request().asyncStarted()).andReturn();
  var streamC=mvc.perform(get(path+"/locations/stream").header("Authorization",c.token)).andExpect(request().asyncStarted()).andReturn();
  UUID chat=(UUID)db.one("SELECT id FROM conversations WHERE linked_trip_id=:id AND status='ACCEPTED'",args("id",UUID.fromString(id))).get("id");
  long reminderCount=db.count("SELECT COUNT(*) FROM trip_reminders WHERE trip_id=:id",args("id",UUID.fromString(id)));
  clearInvocations(mongo);
  call(put("/api/v1/users/"+b.id+"/block"),a,null,200);
  waitFor(streamA,"tripLocationsInvalidated");waitFor(streamB,"tripLocationsInvalidated");
  assertFalse(streamC.getResponse().getContentAsString().contains("tripLocationsInvalidated"));
  assertEquals(2,call(get(path+"/locations"),a,null,200).size());
  assertEquals(2,call(get(path+"/locations"),b,null,200).size());
  assertEquals(3,call(get(path+"/locations"),c,null,200).size());
  assertEquals(prior,snapshots.get(id+":"+b.id).getUpdatedAt());assertEquals(3,snapshots.size());
  verify(mongo,never()).deleteByMember(any(),any());verify(mongo,never()).deleteByTrip(any());
  var warning=call(get("/api/v1/conversations/"+chat+"/blocked-members"),a,null,200);assertEquals(1,warning.size());assertEquals(b.id.toString(),warning.get(0).path("userId").asText());
  assertEquals(0,call(get("/api/v1/conversations/"+chat+"/blocked-members"),b,null,200).size());
  streams.updated(UUID.fromString(id),b.id,Instant.now());waitFor(streamC,"tripLocationUpdated");
  assertFalse(streamA.getResponse().getContentAsString().contains("tripLocationUpdated"));
  call(put(path+"/location"),a,coordinates(),200); // Pin publishing is not disabled by Block.
  assertEquals(3,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:id AND status='ACTIVE'",args("id",UUID.fromString(id))));
  assertEquals("ACCEPTED",db.one("SELECT status FROM conversations WHERE id=:id",args("id",chat)).get("status"));
  assertEquals(reminderCount,db.count("SELECT COUNT(*) FROM trip_reminders WHERE trip_id=:id",args("id",UUID.fromString(id))));
  call(delete("/api/v1/users/"+b.id+"/block"),a,null,200);
  assertEquals(3,call(get(path+"/locations"),a,null,200).size());assertEquals(prior,snapshots.get(id+":"+b.id).getUpdatedAt());
  for(var r:List.of(streamA,streamB,streamC)) r.getRequest().getAsyncContext().complete();
 }

 void waitFor(MvcResult response,String signal) throws Exception {
  for(int i=0;i<100 && !response.getResponse().getContentAsString().contains(signal);i++) Thread.sleep(10);
  assertTrue(response.getResponse().getContentAsString().contains(signal),signal);
 }

 TripCurrentLocationDocument snapshot(UUID trip,UUID user,double lat,double lng,Double accuracy,Instant captured,Instant updated) {
  return snapshots.compute(trip+":"+user,(key,old) -> {
   var doc=new TripCurrentLocationDocument(); doc.setId(old==null?UUID.randomUUID().toString():old.getId());
   doc.setTripId(trip); doc.setUserId(user); doc.setLatitude(lat); doc.setLongitude(lng); doc.setAccuracyM(accuracy); doc.setCapturedAt(captured); doc.setUpdatedAt(updated); return doc;
  });
 }
 Map<String,Object> coordinates() { return Map.of("latitude",11.94,"longitude",108.44,"accuracyM",12); }
 void activate(User a,User b,String id) throws Exception { call(post("/api/v1/trips/"+id+"/pin"),b,null,200); }
 String group(User a,User b) throws Exception {
  var trip=call(post("/api/v1/trips"),a,Map.of("title","Location sharing fixture","startDate","2026-12-01","endDate","2026-12-02","selectedMemberIds",List.of(b.id)),201);
  call(post("/api/v1/trip-invitations/"+trip.path("pendingInvitations").get(0).path("invitationId").asText()+"/accept"),b,null,200);
  return trip.path("id").asText();
 }
 User user() {
  String suffix=UUID.randomUUID().toString().replace("-","");
  var session=auth.register(new AuthDtos.Register(suffix+"@example.invalid","TestPass123!","loc_"+suffix.substring(0,12)));
  return new User((UUID)((Map<?,?>)session.get("user")).get("id"),"Bearer "+session.get("accessToken"));
 }
 JsonNode call(MockHttpServletRequestBuilder req,User user,Object body,int expected) throws Exception {
  req.header("Authorization",user.token); if(body!=null) req.contentType("application/json").content(json.writeValueAsBytes(body));
  var response=mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse();
  return response.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(response.getContentAsByteArray());
 }
 record User(UUID id,String token) {}
}
