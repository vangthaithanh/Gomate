package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import vn.gomate.location.model.TripCurrentLocationDocument;
import vn.gomate.location.repository.TripLocationMongoRepository;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TripApiTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired Db db;
 @Autowired TripTestClockConfiguration.PlanningClock planningClock;
 @MockitoBean TripLocationMongoRepository locationMongo;

 private long lakeId;
 private long templeId;
 private long gardenId;

 @BeforeEach
 void setup() {
  planningClock.reset();
  clearTripsAndPlaces();
  db.update("INSERT INTO place_categories(code,name,active) VALUES('lake','Ho va canh quan',TRUE)",Map.of());
  db.update("INSERT INTO place_categories(code,name,active) VALUES('temple','Tam linh',TRUE)",Map.of());
  long lakeCategory=categoryId("lake");
  long templeCategory=categoryId("temple");
  lakeId=insertPlace(lakeCategory,"Ho Xuan Huong",11.9419,108.4483);
  templeId=insertPlace(templeCategory,"Thien Vien Truc Lam",11.9037,108.4369);
  gardenId=insertPlace(lakeCategory,"Vuon Hoa Thanh Pho",11.9470,108.4450);
  db.update("""
   INSERT INTO place_media(place_id,media_type,url,public_id,caption,sort_order)
   VALUES(:placeId,'IMAGE','https://res.cloudinary.com/demo/image/upload/sample.jpg','test/place-cover','cover',0)
   """,args("placeId",lakeId));
 }

 @Test
 void pinAndMemberLocationSnapshotArePersistedAndProtected() throws Exception {
  var leaderSession=registerSession("trip-phase3-leader");
  var memberSession=registerSession("trip-phase3-member");
  var outsiderSession=registerSession("trip-phase3-outsider");
  String leaderToken="Bearer "+leaderSession.get("accessToken");
  String memberToken="Bearer "+memberSession.get("accessToken");
  String outsiderToken="Bearer "+outsiderSession.get("accessToken");
  @SuppressWarnings("unchecked")
  UUID leaderId=(UUID)((Map<String,Object>)leaderSession.get("user")).get("id");
  @SuppressWarnings("unchecked")
  UUID memberId=(UUID)((Map<String,Object>)memberSession.get("user")).get("id");

  String tripId=performJson(post("/api/v1/trips"),leaderToken,Map.of(
   "title","Phase 3 pinned group",
   "selectedMemberIds",List.of(memberId.toString()),
   "startDate","2026-10-01",
   "endDate","2026-10-02"
  ),201).get("id").asText();
  UUID tripUuid=UUID.fromString(tripId);

  JsonNode incoming=performJson(get("/api/v1/trip-invitations/incoming"),memberToken,null,200);
  performJson(post("/api/v1/trip-invitations/"+incoming.get(0).get("invitationId").asText()+"/accept"),memberToken,null,200);

  JsonNode pinned=performJson(post("/api/v1/trips/"+tripId+"/pin"),leaderToken,null,200);
  assertEquals(tripId,pinned.get("id").asText());
  assertTrue(pinned.get("pinned").asBoolean());
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_pins WHERE user_id=:userId AND trip_id=:tripId",args("userId",leaderId,"tripId",tripUuid)));
  assertTrue(performJson(get("/api/v1/trips/pinned"),leaderToken,null,200).get("trip").get("pinned").asBoolean());

  var doc=new TripCurrentLocationDocument();
  doc.setTripId(tripUuid);
  doc.setUserId(memberId);
  doc.setLatitude(11.9419);
  doc.setLongitude(108.4483);
  doc.setAccuracyM(12.0);
  doc.setCapturedAt(java.time.Instant.parse("2026-10-10T01:00:00Z"));
  doc.setUpdatedAt(java.time.Instant.parse("2026-10-10T01:00:05Z"));
  when(locationMongo.upsert(eq(tripUuid),eq(memberId),eq(11.9419),eq(108.4483),eq(12.0),any(),any())).thenReturn(doc);
  when(locationMongo.findByTrip(tripUuid)).thenReturn(List.of(doc));

  performJson(post("/api/v1/trips/"+tripId+"/pin"),memberToken,null,200);
  JsonNode published=performJson(put("/api/v1/trips/"+tripId+"/location"),memberToken,Map.of(
   "latitude",11.9419,
   "longitude",108.4483,
   "accuracyM",12.0
  ),200);
  assertEquals(memberId.toString(),published.get("userId").asText());
  assertEquals("LAST_KNOWN",published.get("locationState").asText());
  assertEquals(1,db.count("""
   SELECT COUNT(*) FROM trip_pins
   WHERE trip_id=:tripId AND user_id=:userId
   """,args("tripId",tripUuid,"userId",memberId)));

  JsonNode locations=performJson(get("/api/v1/trips/"+tripId+"/locations"),leaderToken,null,200);
  assertEquals(1,locations.size());
  assertEquals(memberId.toString(),locations.get(0).get("userId").asText());
  assertEquals("LAST_KNOWN",locations.get(0).get("locationState").asText());

  mvc.perform(get("/api/v1/trips/"+tripId+"/locations").header("Authorization",outsiderToken))
   .andExpect(status().isNotFound());

  mvc.perform(put("/api/v1/trips/"+tripId+"/location")
    .header("Authorization",memberToken)
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("latitude",100,"longitude",108.4483))))
   .andExpect(status().isBadRequest());

  mvc.perform(delete("/api/v1/trips/"+tripId+"/pin").header("Authorization",leaderToken))
   .andExpect(status().isNoContent());
  assertEquals(0,db.count("SELECT COUNT(*) FROM trip_pins WHERE user_id=:userId",args("userId",leaderId)));
 }

 @Test
 void tripStopOccurrenceTimeReorderAndOptimizeRules() throws Exception {
  String token=registerToken("trip-phase2");
  String tripId=performJson(post("/api/v1/trips"),token,Map.of(
   "title","Phase 2 stop rules",
   "startDate","2026-10-01",
   "endDate","2026-10-03"
  ),201).get("id").asText();

  JsonNode a1=performJson(post("/api/v1/trips/"+tripId+"/stops"),token,Map.of(
   "placeId",lakeId,
   "dayNo",1,
   "plannedStartAt","2026-10-01T08:00:00+07:00",
   "plannedEndAt","2026-10-01T09:00:00+07:00"
  ),201);
  String a1Id=a1.get("stops").get(0).get("id").asText();
  assertTrue(a1.get("stops").get(0).get("hasCompleteInterval").asBoolean());
  assertFalse(a1.get("stops").get(0).get("plannedEndAt").isNull());
  assertEquals(60,a1.get("stops").get(0).get("plannedDurationMin").asInt());

  JsonNode b=performJson(post("/api/v1/trips/"+tripId+"/stops"),token,Map.of(
   "placeId",templeId,
   "dayNo",1
  ),201);
  String bId=b.get("stops").get(1).get("id").asText();

  JsonNode aba=performJson(post("/api/v1/trips/"+tripId+"/stops"),token,Map.of(
   "placeId",lakeId,
   "dayNo",1,
   "plannedStartAt","2026-10-01T18:00:00+07:00"
  ),201);
  assertEquals(3,aba.get("stops").size());
  String a2Id=aba.get("stops").get(2).get("id").asText();
  assertNotEquals(a1Id,a2Id);
  assertEquals(lakeId,aba.get("stops").get(0).get("placeId").asLong());
  assertEquals(lakeId,aba.get("stops").get(2).get("placeId").asLong());
  assertFalse(aba.get("stops").get(2).get("hasCompleteInterval").asBoolean());
  assertTrue(aba.get("stops").get(2).get("plannedEndAt").isNull());

  mvc.perform(post("/api/v1/trips/"+tripId+"/stops")
    .header("Authorization",token)
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("placeId",lakeId,"dayNo",1))))
   .andExpect(status().isBadRequest())
   .andExpect(jsonPath("$.code").value("TRIP_STOP_ADJACENT_DUPLICATE"));

  mvc.perform(patch("/api/v1/trips/"+tripId+"/stops/"+bId)
    .header("Authorization",token)
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("placeId",lakeId))))
   .andExpect(status().isBadRequest())
   .andExpect(jsonPath("$.code").value("TRIP_STOP_ADJACENT_DUPLICATE"));

  mvc.perform(delete("/api/v1/trips/"+tripId+"/stops/"+bId).header("Authorization",token))
   .andExpect(status().isBadRequest())
   .andExpect(jsonPath("$.code").value("TRIP_STOP_ADJACENT_DUPLICATE"));
  assertEquals(3,performJson(get("/api/v1/trips/"+tripId),token,null,200).get("stops").size());

  JsonNode timedA2=performJson(patch("/api/v1/trips/"+tripId+"/stops/"+a2Id),token,Map.of(
   "plannedStartAt","2026-10-01T18:00:00+07:00",
   "plannedEndAt","2026-10-01T19:00:00+07:00"
  ),200);
  JsonNode a2AfterTime=stopById(timedA2,a2Id);
  assertTrue(a2AfterTime.get("hasCompleteInterval").asBoolean());
  assertFalse(a2AfterTime.get("plannedEndAt").isNull());
  assertEquals(60,a2AfterTime.get("plannedDurationMin").asInt());
  assertEquals(60,stopById(timedA2,a1Id).get("plannedDurationMin").asInt());

  JsonNode clearedA1=performJson(patch("/api/v1/trips/"+tripId+"/stops/"+a1Id),token,Map.of(
   "clearTime",true
  ),200);
  JsonNode a1AfterClear=stopById(clearedA1,a1Id);
  assertTrue(a1AfterClear.get("plannedStartAt").isNull());
  assertTrue(a1AfterClear.get("plannedEndAt").isNull());
  assertFalse(a1AfterClear.get("hasCompleteInterval").asBoolean());

  mvc.perform(patch("/api/v1/trips/"+tripId+"/stops/reorder")
    .header("Authorization",token)
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of(
     "stops",List.of(
      Map.of("stopId",bId,"dayNo",1,"orderNo",1),
      Map.of("stopId",a1Id,"dayNo",1,"orderNo",2),
      Map.of("stopId",a2Id,"dayNo",1,"orderNo",3)
     )
    ))))
   .andExpect(status().isBadRequest())
   .andExpect(jsonPath("$.code").value("TRIP_STOP_ADJACENT_DUPLICATE"));
  JsonNode afterInvalidReorder=performJson(get("/api/v1/trips/"+tripId),token,null,200);
  assertEquals(a1Id,afterInvalidReorder.get("stops").get(0).get("id").asText());
  assertEquals(bId,afterInvalidReorder.get("stops").get(1).get("id").asText());
  assertEquals(a2Id,afterInvalidReorder.get("stops").get(2).get("id").asText());

  JsonNode validReorder=performJson(patch("/api/v1/trips/"+tripId+"/stops/reorder"),token,Map.of(
   "stops",List.of(
    Map.of("stopId",a2Id,"dayNo",1,"orderNo",1),
    Map.of("stopId",bId,"dayNo",1,"orderNo",2),
    Map.of("stopId",a1Id,"dayNo",1,"orderNo",3)
   )
  ),200);
  assertEquals(a2Id,validReorder.get("stops").get(0).get("id").asText());
  assertEquals(bId,validReorder.get("stops").get(1).get("id").asText());
  assertEquals(a1Id,validReorder.get("stops").get(2).get("id").asText());
  assertFalse(stopById(validReorder,a2Id).get("plannedStartAt").isNull());
  assertEquals(60,stopById(validReorder,a2Id).get("plannedDurationMin").asInt());
  assertTrue(stopById(validReorder,a1Id).get("plannedStartAt").isNull());

  JsonNode withUnscheduled=performJson(post("/api/v1/trips/"+tripId+"/stops"),token,Map.of(
   "placeId",gardenId,
   "dayNo",1
  ),201);
  String gardenStopId=withUnscheduled.get("stops").get(3).get("id").asText();

  JsonNode optimized=performJson(post("/api/v1/trips/"+tripId+"/stops/optimize"),token,Map.of("dayNo",1),200);
  Set<String> optimizedIds=new HashSet<>();
  for(JsonNode stop:optimized.get("stops")) optimizedIds.add(stop.get("id").asText());
  assertEquals(Set.of(a1Id,bId,a2Id,gardenStopId),optimizedIds);
  assertFalse(stopById(optimized,a2Id).get("plannedStartAt").isNull());
  assertEquals(60,stopById(optimized,a2Id).get("plannedDurationMin").asInt());
  assertNoAdjacentDuplicatePlaces(optimized);
 }

 @AfterEach
 void cleanup() {
  planningClock.reset();
  clearTripsAndPlaces();
 }

 @Test
 void personalTripRunsEndToEndWithStopsAndReorder() throws Exception {
  String token=registerToken("trip-owner");

  JsonNode created=performJson(post("/api/v1/trips"),token,Map.of(
   "title","Da Lat weekend",
   "description","Personal planning",
   "startDate","2026-10-01",
   "endDate","2026-10-03"
  ),201);
  String tripId=created.get("id").asText();
  assertEquals("PERSONAL",created.get("tripType").asText());
  assertFalse(created.has("status"));
  assertEquals("LEADER",created.get("members").get(0).get("role").asText());

  mvc.perform(get("/api/v1/trips").header("Authorization",token))
   .andExpect(status().isOk())
   .andExpect(jsonPath("$.length()").value(1))
   .andExpect(jsonPath("$[0].stopCount").value(0));

  JsonNode updated=performJson(patch("/api/v1/trips/"+tripId),token,Map.of(
   "title","Da Lat plan"
  ),200);
  assertEquals("Da Lat plan",updated.get("title").asText());
  assertFalse(updated.has("status"));

  JsonNode oneStop=performJson(post("/api/v1/trips/"+tripId+"/stops"),token,Map.of(
   "placeId",lakeId,
   "dayNo",1,
   "orderNo",1,
   "note","Walk around the lake"
  ),201);
  assertEquals(1,oneStop.get("stops").size());
  assertEquals(lakeId,oneStop.get("stops").get(0).get("placeId").asLong());
  assertEquals("Ho Xuan Huong",oneStop.get("stops").get(0).get("name").asText());
  assertEquals("lake",oneStop.get("stops").get(0).get("category").asText());
  assertEquals(11.9419,oneStop.get("stops").get(0).get("latitude").asDouble(),0.00001);
  assertTrue(oneStop.get("stops").get(0).get("thumbnailUrl").asText().contains("cloudinary.com"));

  JsonNode twoStops=performJson(post("/api/v1/trips/"+tripId+"/stops"),token,Map.of(
   "placeId",templeId,
   "dayNo",1
  ),201);
  String firstStopId=twoStops.get("stops").get(0).get("id").asText();
  String secondStopId=twoStops.get("stops").get(1).get("id").asText();

  JsonNode reordered=performJson(patch("/api/v1/trips/"+tripId+"/stops/reorder"),token,Map.of(
   "stops",List.of(
    Map.of("stopId",secondStopId,"dayNo",1,"orderNo",1),
    Map.of("stopId",firstStopId,"dayNo",1,"orderNo",2)
   )
  ),200);
  assertEquals(templeId,reordered.get("stops").get(0).get("placeId").asLong());
  assertEquals(lakeId,reordered.get("stops").get(1).get("placeId").asLong());

  mvc.perform(delete("/api/v1/trips/"+tripId+"/stops/"+firstStopId).header("Authorization",token))
   .andExpect(status().isNoContent());
  mvc.perform(get("/api/v1/trips/"+tripId).header("Authorization",token))
   .andExpect(status().isOk())
   .andExpect(jsonPath("$.stops.length()").value(1))
   .andExpect(jsonPath("$.stops[0].placeId").value(templeId));

  db.update("INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,remind_at) SELECT :rid,id,owner_id,'TRIP_START',CURRENT_TIMESTAMP FROM trips WHERE id=:id",
   args("rid",UUID.randomUUID(),"id",UUID.fromString(tripId)));
  long reminderRowsBeforeArchive=db.count("SELECT COUNT(*) FROM trip_reminders WHERE trip_id=:id",args("id",UUID.fromString(tripId)));
  mvc.perform(delete("/api/v1/trips/"+tripId).header("Authorization",token))
   .andExpect(status().isNoContent());
  assertEquals(1,db.count("SELECT COUNT(*) FROM trips WHERE id=:id AND archived_at IS NOT NULL",args("id",UUID.fromString(tripId))));
  assertEquals(1,db.count("SELECT COUNT(*) FROM trip_stops WHERE trip_id=:id",args("id",UUID.fromString(tripId))));
  assertEquals(reminderRowsBeforeArchive,db.count("SELECT COUNT(*) FROM trip_reminders WHERE trip_id=:id",args("id",UUID.fromString(tripId))));
  mvc.perform(get("/api/v1/trips/"+tripId).header("Authorization",token))
   .andExpect(status().isNotFound());
 }

 @Test
 void invalidPlaceAndOtherUserAccessAreControlled() throws Exception {
  String ownerToken=registerToken("trip-owner");
  String otherToken=registerToken("trip-other");
  String tripId=performJson(post("/api/v1/trips"),ownerToken,Map.of(
   "title","Private trip",
   "startDate","2026-11-01",
   "endDate","2026-11-02"
  ),201).get("id").asText();

  mvc.perform(get("/api/v1/trips/"+tripId).header("Authorization",otherToken))
   .andExpect(status().isNotFound());

  mvc.perform(patch("/api/v1/trips/"+tripId)
    .header("Authorization",otherToken)
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("title","Nope"))))
   .andExpect(status().isNotFound());

  mvc.perform(delete("/api/v1/trips/"+tripId).header("Authorization",otherToken))
   .andExpect(status().isNotFound());

  mvc.perform(post("/api/v1/trips/"+tripId+"/stops")
    .header("Authorization",ownerToken)
    .contentType("application/json")
    .content(json.writeValueAsBytes(Map.of("placeId",999999))))
   .andExpect(status().isNotFound())
   .andExpect(jsonPath("$.code").value("PLACE_NOT_FOUND"));
 }

 @Test
 void tripStopPlaceForeignKeyIsEnforced() {
  var session=registerSession("trip-fk");
  @SuppressWarnings("unchecked")
  UUID userId=(UUID)((Map<String,Object>)session.get("user")).get("id");
  UUID tripId=UUID.randomUUID();
  db.update("""
   INSERT INTO trips(id,owner_id,title,start_date,end_date)
   VALUES(:tripId,:userId,'FK test',DATE '2026-12-01',DATE '2026-12-02')
   """,args("tripId",tripId,"userId",userId));
  assertThrows(DataIntegrityViolationException.class,() -> db.update("""
   INSERT INTO trip_stops(id,trip_id,place_id,day_no,order_no)
   VALUES(:id,:tripId,999999,1,1)
   """,args("id",UUID.randomUUID(),"tripId",tripId)));
 }

 @Test
 void stopTimeRoundTripPreservesOccurrenceAndUnchangedHistoricalMetadata() throws Exception {
  String token=registerToken("stop-time");
  String trip=performJson(post("/api/v1/trips"),token,Map.of("title","Stop time proof","startDate","2026-10-28","endDate","2026-10-30","timezone","Asia/Ho_Chi_Minh"),201).get("id").asText();
  String path="/api/v1/trips/"+trip+"/stops";
  var first=performJson(post(path),token,Map.of("placeId",lakeId,"dayNo",2,"plannedStartAt","2026-10-29T10:00:00","plannedEndAt","2026-10-29T10:01:00"),201).get("stops").get(0);
  String id=first.get("id").asText();
  assertEquals("2026-10-29T03:00:00Z",first.get("plannedStartAt").asText());
  assertEquals("2026-10-29T10:00:00",first.get("plannedLocalStartAt").asText());
  assertEquals("2026-10-29T10:01:00",first.get("plannedLocalEndAt").asText());
  assertEquals(1,db.one("SELECT planned_duration_min AS duration FROM trip_stops WHERE id=:id",args("id",UUID.fromString(id))).get("duration"));
  performJson(post(path),token,Map.of("placeId",templeId,"dayNo",2),201);
  var aba=performJson(post(path),token,Map.of("placeId",lakeId,"dayNo",2,"plannedStartAt","2026-10-29T11:00:00+07:00"),201);
  String second=aba.get("stops").get(2).get("id").asText();
  var edited=performJson(patch(path+"/"+second),token,Map.of("plannedStartAt","2026-10-29T12:00:00","plannedEndAt","2026-10-29T13:00:00"),200);
  assertEquals(first,stopById(edited,id));
  assertEquals(60,stopById(edited,second).get("plannedDurationMin").asInt());
  assertEquals(3,edited.get("stops").size());
  // Trip dates change without rebasing existing occurrence instants.
  performJson(patch("/api/v1/trips/"+trip),token,Map.of("startDate","2026-11-01","endDate","2026-11-03"),200);
  assertEquals(first,stopById(performJson(get("/api/v1/trips/"+trip),token,null,200),id));
  planningClock.at("2026-12-01T00:00:00Z");
  var metadata=performJson(patch(path+"/"+id),token,Map.of("note","Historical note"),200);
  assertEquals(first.get("plannedStartAt"),stopById(metadata,id).get("plannedStartAt"));
  assertEquals(1,stopById(metadata,id).get("plannedDurationMin").asInt());
  assertEquals(400,performJson(patch(path+"/"+id),token,Map.of("plannedStartAt","2026-11-02T12:00:00"),400).get("status").asInt());
  var clear=performJson(patch(path+"/"+id),token,Map.of("clearTime",true),200);
  assertTrue(stopById(clear,id).get("plannedStartAt").isNull());
  assertTrue(stopById(clear,id).get("plannedEndAt").isNull());
  assertTrue(stopById(clear,id).get("plannedDurationMin").isNull());
 }

 @Test
 void addAndEditUseServerClockAndRejectWithoutChangingStoredTime() throws Exception {
  String token=registerToken("stop-clock");
  String trip=performJson(post("/api/v1/trips"),token,Map.of("title","Time validation","startDate","2026-10-27","endDate","2026-10-29"),201).get("id").asText();
  String path="/api/v1/trips/"+trip+"/stops";
  var empty=performJson(post(path),token,Map.of("placeId",lakeId),201).get("stops").get(0);
  String id=empty.get("id").asText();
  planningClock.at("2026-10-28T03:00:00Z");
  for(var value:List.of("2026-10-27T12:00:00","2026-10-28T09:59:00","2026-10-28T10:00:00")) {
   int day=value.contains("27T")?1:2;
   for(var request:List.of(post(path),patch(path+"/"+id))) {
    var error=performJson(request,token,Map.of("placeId",templeId,"dayNo",day,"plannedStartAt",value),400);
    assertEquals("TRIP_STOP_TIME_INVALID",error.get("code").asText());
   }
   assertEquals(empty,stopById(performJson(get("/api/v1/trips/"+trip),token,null,200),id));
  }
  for(String end:List.of("2026-10-29T09:59:00","2026-10-29T10:00:00","2026-10-30T00:01:00")) {
   for(var request:List.of(post(path),patch(path+"/"+id)))
    performJson(request,token,Map.of("placeId",templeId,"dayNo",3,"plannedStartAt","2026-10-29T10:00:00","plannedEndAt",end),400);
  }
  var valid=performJson(patch(path+"/"+id),token,Map.of("dayNo",2,"plannedStartAt","2026-10-28T10:01:00"),200);
  assertFalse(stopById(valid,id).get("hasCompleteInterval").asBoolean());
  assertTrue(stopById(valid,id).get("plannedEndAt").isNull());
  var other=registerSession("stop-member");
  UUID member=(UUID)((Map<?,?>)other.get("user")).get("id");
  db.update("INSERT INTO trip_members(trip_id,user_id,role,status) VALUES(:trip,:user,'MEMBER','ACTIVE')",args("trip",UUID.fromString(trip),"user",member));
  String memberToken="Bearer "+other.get("accessToken");
  performJson(get("/api/v1/trips/"+trip),memberToken,null,200);
  performJson(patch(path+"/"+id),memberToken,Map.of("clearTime",true),403);
  performJson(post(path),memberToken,Map.of("placeId",templeId),403);
 }

 private JsonNode performJson(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,String token,Object body,int expectedStatus) throws Exception {
  var builder=request.header("Authorization",token).contentType("application/json");
  if(body!=null) builder.content(json.writeValueAsBytes(body));
  var result=mvc.perform(builder)
   .andExpect(status().is(expectedStatus))
   .andReturn();
  return json.readTree(result.getResponse().getContentAsByteArray());
 }

 private JsonNode stopById(JsonNode detail,String stopId) {
  for(JsonNode stop:detail.get("stops")) {
   if(stopId.equals(stop.get("id").asText())) return stop;
  }
  fail("Missing stop "+stopId);
  return detail;
 }

 private void assertNoAdjacentDuplicatePlaces(JsonNode detail) {
  JsonNode stops=detail.get("stops");
  for(int i=1;i<stops.size();i++) {
   assertNotEquals(stops.get(i-1).get("placeId").asLong(),stops.get(i).get("placeId").asLong());
  }
 }

 private String registerToken(String prefix) {
  Map<String,Object> session=registerSession(prefix);
  return "Bearer "+session.get("accessToken");
 }

 private Map<String,Object> registerSession(String prefix) {
  String suffix=UUID.randomUUID().toString().replace("-","");
  String email=prefix+"_"+suffix+"@example.com";
  return auth.register(new AuthDtos.Register(email,"TestPass123!",prefix+"_"+suffix.substring(0,8)));
 }

 private long categoryId(String code) {
  return ((Number)db.one("SELECT id FROM place_categories WHERE code=:code",args("code",code)).get("id")).longValue();
 }

 private long insertPlace(long categoryId,String name,double latitude,double longitude) {
  db.update("""
   INSERT INTO places(category_id,name,description,province,district,address,latitude,longitude,source_type,status)
   VALUES(:categoryId,:name,:name,'Lam Dong','Da Lat',:name,:latitude,:longitude,'ADMIN','ACTIVE')
   """,args("categoryId",categoryId,"name",name,"latitude",latitude,"longitude",longitude));
  return ((Number)db.one("SELECT id FROM places WHERE name=:name",args("name",name)).get("id")).longValue();
 }

 private void clearTripsAndPlaces() {
  db.update("DELETE FROM trip_reminders",Map.of());
  db.update("DELETE FROM trip_stops",Map.of());
 db.update("DELETE FROM trip_invitations",Map.of());
  db.update("DELETE FROM trip_members",Map.of());
  db.update("DELETE FROM trips",Map.of());
  db.update("DELETE FROM place_media",Map.of());
  db.update("DELETE FROM places",Map.of());
  db.update("DELETE FROM place_categories",Map.of());
 }
}
