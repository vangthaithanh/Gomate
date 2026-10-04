package vn.gomate;

import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.common.Db;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PlaceApiTest {
 @Autowired MockMvc mvc; @Autowired Db db;

 @Test void placeReadApisReturnEmptyStateAndNotFound() throws Exception {
  mvc.perform(get("/api/v1/places")).andExpect(status().isOk()).andExpect(content().json("[]"));
  mvc.perform(get("/api/v1/places/search").param("q","Da Lat")).andExpect(status().isOk()).andExpect(content().json("[]"));
  mvc.perform(get("/api/v1/places/999999")).andExpect(status().isNotFound());
 }

 @Test void flywayCreatesOnlyAuthPlaceTripAndSemanticTables() {
  var tables=db.list("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'",Map.of());
  var actual=new TreeSet<>(tables.stream().map(t->(String)t.get("tableName")).toList());
  assertEquals(new TreeSet<>(Set.of(
   "flyway_schema_history",
   "users","user_profiles","user_settings","refresh_sessions",
   "place_categories","places","place_media",
   "trips","trip_members","trip_stops","trip_reminders",
   "interest_groups","interest_options","user_interests",
   "place_tags","place_tag_links","interest_tag_mappings"
  )),actual);
 }
}
