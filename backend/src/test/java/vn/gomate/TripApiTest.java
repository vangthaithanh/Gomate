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
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import static org.junit.jupiter.api.Assertions.*;
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

 private long lakeId;
 private long templeId;

 @BeforeEach
 void setup() {
  clearTripsAndPlaces();
  db.update("INSERT INTO place_categories(code,name,active) VALUES('lake','Ho va canh quan',TRUE)",Map.of());
  db.update("INSERT INTO place_categories(code,name,active) VALUES('temple','Tam linh',TRUE)",Map.of());
  long lakeCategory=categoryId("lake");
  long templeCategory=categoryId("temple");
  lakeId=insertPlace(lakeCategory,"Ho Xuan Huong",11.9419,108.4483);
  templeId=insertPlace(templeCategory,"Thien Vien Truc Lam",11.9037,108.4369);
  db.update("""
   INSERT INTO place_media(place_id,media_type,url,public_id,caption,sort_order)
   VALUES(:placeId,'IMAGE','https://res.cloudinary.com/demo/image/upload/sample.jpg','test/place-cover','cover',0)
   """,args("placeId",lakeId));
 }

 @AfterEach
 void cleanup() {
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
  assertEquals("DRAFT",created.get("status").asText());
  assertEquals("LEADER",created.get("members").get(0).get("role").asText());

  mvc.perform(get("/api/v1/trips").header("Authorization",token))
   .andExpect(status().isOk())
   .andExpect(jsonPath("$.length()").value(1))
   .andExpect(jsonPath("$[0].stopCount").value(0));

  JsonNode updated=performJson(patch("/api/v1/trips/"+tripId),token,Map.of(
   "title","Da Lat plan",
   "status","PLANNED"
  ),200);
  assertEquals("Da Lat plan",updated.get("title").asText());
  assertEquals("PLANNED",updated.get("status").asText());

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

  mvc.perform(delete("/api/v1/trips/"+tripId).header("Authorization",token))
   .andExpect(status().isNoContent());
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

 private JsonNode performJson(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,String token,Object body,int expectedStatus) throws Exception {
  var result=mvc.perform(request.header("Authorization",token).contentType("application/json").content(json.writeValueAsBytes(body)))
   .andExpect(status().is(expectedStatus))
   .andReturn();
  return json.readTree(result.getResponse().getContentAsByteArray());
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
  db.update("DELETE FROM trip_members",Map.of());
  db.update("DELETE FROM trips",Map.of());
  db.update("DELETE FROM place_media",Map.of());
  db.update("DELETE FROM places",Map.of());
  db.update("DELETE FROM place_categories",Map.of());
 }
}
