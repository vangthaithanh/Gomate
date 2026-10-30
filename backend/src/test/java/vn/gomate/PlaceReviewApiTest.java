package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.math.BigDecimal;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.place.review.*;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties="spring.datasource.url=jdbc:h2:mem:reviews;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1")
@AutoConfigureMockMvc @ActiveProfiles("test")
class PlaceReviewApiTest {
 @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired AuthService auth; @Autowired Db db;
 @Autowired PlaceReviewService service;
 @org.springframework.test.context.bean.override.mockito.MockitoSpyBean PlaceReviewRepository repo;
 record User(UUID id,String token) {}
 User user() {String k="review"+UUID.randomUUID().toString().replace("-","").substring(0,12);var s=auth.register(new AuthDtos.Register(k+"@example.com","TestPass123!",k));return new User((UUID)((Map<?,?>)s.get("user")).get("id"),"Bearer "+s.get("accessToken"));}
 long place() {
  String code="c"+UUID.randomUUID().toString().substring(0,10);
  db.update("INSERT INTO place_categories(code,name) VALUES(:c,:c)",args("c",code));
  long cat=((Number)db.one("SELECT id FROM place_categories WHERE code=:c",args("c",code)).get("id")).longValue();
  db.update("INSERT INTO places(category_id,name,province,latitude,longitude) VALUES(:c,:name,'Đà Lạt',11.94,108.44)",args("c",cat,"name",code));
  return ((Number)db.one("SELECT id FROM places WHERE name=:name",args("name",code)).get("id")).longValue();
 }
 JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,User u,int statusCode)throws Exception {
  return json.readTree(mvc.perform(req.header("Authorization",u.token)).andExpect(status().is(statusCode)).andReturn().getResponse().getContentAsByteArray());
 }
 JsonNode submit(User u,long p,String value)throws Exception {return call(post("/api/v1/places/"+p+"/reviews").contentType("application/json").content(value),u,200);}
 PlaceReviewService.Write write(int n) {return new PlaceReviewService.Write(BigDecimal.valueOf(n),"Review thật");}
 @Test void lifecycleRealAggregatesRetryAndReadContracts()throws Exception {
  var a=user();var b=user();long p=place();
  call(post("/api/v1/places/"+p+"/reviews").contentType("application/json").content("{\"rating\":5,\"userId\":\""+b.id+"\"}"),a,400);
  var first=submit(a,p,"{\"rating\":5,\"content\":\"Đẹp\"}");long id=first.path("myReview").path("id").asLong();
  assertEquals(1,first.path("reviewCount").asInt());assertEquals(5,first.path("avgRating").asDouble());
  assertEquals(id,submit(a,p,"{\"rating\":5}").path("myReview").path("id").asLong());
  var r=submit(b,p,"{\"rating\":3}");long bid=r.path("myReview").path("id").asLong();assertEquals(4,r.path("avgRating").asDouble());assertEquals(2,r.path("reviewCount").asInt());
  var edit=call(patch("/api/v1/reviews/"+id).contentType("application/json").content("{\"rating\":4}"),a,200);assertEquals(3.5,edit.path("avgRating").asDouble());
  assertEquals(4,call(get("/api/v1/places/"+p+"/reviews/me"),a,200).path("myReview").path("rating").asInt());
  for(String route:List.of("/api/v1/places/"+p,"/api/v1/places","/api/v1/places/search?q=","/api/v1/search/places?q=")) {
   if(route.contains("/search/places")) continue;
   var value=call(get(route),a,200);if(value.isArray()) {for(var item:value) if(item.path("placeId").asLong()==p) assertEquals(3.5,item.path("avgRating").asDouble());} else assertEquals(3.5,value.path("avgRating").asDouble());
  }
  var deleted=call(delete("/api/v1/reviews/"+id),a,200);assertEquals(3,deleted.path("avgRating").asDouble());assertEquals(1,deleted.path("reviewCount").asInt());
  call(delete("/api/v1/reviews/"+id),a,200);
  var empty=call(delete("/api/v1/reviews/"+bid),b,200);assertEquals(0,empty.path("reviewCount").asInt());assertEquals(0,empty.path("avgRating").asDouble());assertTrue(empty.path("myReview").isNull());
  assertEquals(2,db.count("SELECT COUNT(*) FROM reviews WHERE place_id=:p AND publication_status='DELETED'",args("p",p)));
 }
 @Test void validatesStarsContentAuthAndOwnership()throws Exception {
  var a=user();var b=user();long p=place();
  for(String value:List.of("0","6","-1","1.5","null","\"invalid\"")) call(post("/api/v1/places/"+p+"/reviews").contentType("application/json").content("{\"rating\":"+value+"}"),a,400);
  call(post("/api/v1/places/"+p+"/reviews").contentType("application/json").content("{}"),a,400);
  call(post("/api/v1/places/"+p+"/reviews").contentType("application/json").content(json.writeValueAsString(Map.of("rating",1,"content","x".repeat(1001)))),a,400);
  for(int stars:List.of(1,3,5)) submit(a,p,"{\"rating\":"+stars+"}");
  long id=((Number)((Map<?,?>)service.mine(a.id,p).get("myReview")).get("id")).longValue();
  call(patch("/api/v1/reviews/"+id).contentType("application/json").content("{\"rating\":2}"),b,403);call(delete("/api/v1/reviews/"+id),b,403);
  mvc.perform(post("/api/v1/places/"+p+"/reviews").contentType("application/json").content("{\"rating\":5}")).andExpect(status().isUnauthorized());
  mvc.perform(get("/api/v1/places/"+p+"/reviews")).andExpect(status().isUnauthorized());
  mvc.perform(get("/api/v1/places/"+p+"/reviews/me")).andExpect(status().isUnauthorized());
  db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",a.id));
  assertEquals(403,assertThrows(ApiException.class,()->service.submit(a.id,p,write(5))).status);
  call(post("/api/v1/places/"+p+"/reviews").contentType("application/json").content("{\"rating\":5}"),a,401);
 }
 @Test void hiddenMissingPlaceModerationAndBlockFiltering()throws Exception {
  var a=user();var b=user();long p=place();
  assertEquals(404,assertThrows(ApiException.class,()->service.submit(a.id,Long.MAX_VALUE,write(5))).status);
  db.update("UPDATE places SET status='HIDDEN' WHERE id=:id",args("id",p));assertEquals(404,assertThrows(ApiException.class,()->service.submit(a.id,p,write(5))).status);
  db.update("UPDATE places SET status='ACTIVE' WHERE id=:id",args("id",p));
  service.submit(a.id,p,write(5));service.submit(b.id,p,write(3));
  assertEquals(2,((List<?>)service.page(a.id,p,20,Long.MAX_VALUE).get("items")).size());
  db.update("INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES(:a,:b)",args("a",a.id,"b",b.id));
  for(var viewer:List.of(a,b)) assertEquals(1,((List<?>)service.page(viewer.id,p,20,Long.MAX_VALUE).get("items")).size());
  long id=((Number)((Map<?,?>)service.mine(b.id,p).get("myReview")).get("id")).longValue();
  db.update("UPDATE reviews SET moderation_status='HIDDEN' WHERE id=:id",args("id",id));
  var updated=service.edit(b.id,id,write(1));assertEquals(1,updated.get("reviewCount"));assertEquals(5,((BigDecimal)updated.get("avgRating")).doubleValue());
  assertEquals("HIDDEN",((Map<?,?>)updated.get("myReview")).get("moderationStatus"));
 }
 @Test void concurrentDevicesAndUsersNeverDuplicateOrLoseAggregate()throws Exception {
  var a=user();var b=user();long p=place();var pool=Executors.newFixedThreadPool(4);
  try {
   var tasks=new ArrayList<Callable<Map<String,Object>>>();
   for(int i=0;i<12;i++) {UUID actor=i%2==0?a.id:b.id;int stars=i%2==0?5:3;tasks.add(()->service.submit(actor,p,write(stars)));}
   for(var f:pool.invokeAll(tasks)) f.get(20,TimeUnit.SECONDS);
   var result=service.mine(a.id,p);assertEquals(2,result.get("reviewCount"));assertEquals(4,((BigDecimal)result.get("avgRating")).doubleValue());
   assertEquals(2,db.count("SELECT COUNT(*) FROM reviews WHERE place_id=:p",args("p",p)));
  } finally {pool.shutdownNow();}
 }
 @Test void cursorHasNoDuplicateAuthorsAndDoesNotExposePrivateFields()throws Exception {
  var a=user();var b=user();long p=place();service.submit(a.id,p,write(5));service.submit(b.id,p,write(3));
  var first=call(get("/api/v1/places/"+p+"/reviews?size=1"),a,200);long cursor=first.path("nextBeforeId").asLong();
  var second=call(get("/api/v1/places/"+p+"/reviews?size=1&beforeId="+cursor),a,200);
  assertNotEquals(first.path("items").get(0).path("id"),second.path("items").get(0).path("id"));assertTrue(second.path("nextBeforeId").isNull());
  assertFalse(first.toString().contains("email"));assertFalse(first.toString().contains("password"));assertTrue(first.path("items").get(0).path("createdAt").asText().endsWith("Z"));
 }
 @Test void aggregateFailureRollsBackReviewAndCachedStats() {
  var a=user();long p=place();
  org.mockito.Mockito.doThrow(new IllegalStateException("probe rollback")).when(repo).aggregate(p);
  try {assertThrows(IllegalStateException.class,()->service.submit(a.id,p,write(5)));}
  finally {org.mockito.Mockito.reset(repo);}
  assertEquals(0,db.count("SELECT COUNT(*) FROM reviews WHERE place_id=:id",args("id",p)));
  assertEquals(0,((Number)repo.stats(p).get("reviewCount")).intValue());
 }
 @Test void sortedPagesUseStarsAcrossPagesAndDatabaseGuardsActiveIdentity()throws Exception {
  var a=user();var b=user();var c=user();long p=place();service.submit(a.id,p,write(3));service.submit(b.id,p,write(5));service.submit(c.id,p,write(1));
  var first=service.page(a.id,p,1,Long.MAX_VALUE,"highest");
  var item=(Map<?,?>)((List<?>)first.get("items")).get(0);assertEquals(5,((Number)item.get("rating")).intValue());
  var next=service.page(a.id,p,1,((Number)first.get("nextBeforeId")).longValue(),"highest");
  assertEquals(3,((Number)((Map<?,?>)((List<?>)next.get("items")).get(0)).get("rating")).intValue());
  assertEquals(1,((Number)((Map<?,?>)((List<?>)service.page(a.id,p,1,Long.MAX_VALUE,"lowest").get("items")).get(0)).get("rating")).intValue());
  assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->db.update("INSERT INTO reviews(user_id,place_id,rating) VALUES(:user,:place,5)",args("user",a.id,"place",p)));
 }
}
