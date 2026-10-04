package vn.gomate;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SemanticFoundationTest {
 @Autowired Db db;
 @Autowired AuthService auth;
 @Autowired MockMvc mvc;

 @Test void semanticTaxonomyAndMappingsAreSeeded() {
  assertEquals(3,db.count("SELECT COUNT(*) FROM interest_groups",Map.of()));
  assertEquals(19,db.count("SELECT COUNT(*) FROM interest_options",Map.of()));
  assertEquals(36,db.count("SELECT COUNT(*) FROM place_tags",Map.of()));
  assertEquals(53,db.count("SELECT COUNT(*) FROM interest_tag_mappings",Map.of()));

  assertEquals(0,db.count("""
   SELECT COUNT(*) FROM interest_tag_mappings
   WHERE weight NOT IN (0.300,0.600,0.800,1.000)
   """,Map.of()));
  assertEquals(0,db.count("""
   SELECT COUNT(*) FROM interest_tag_mappings m
   JOIN interest_options io ON io.id=m.interest_option_id
   WHERE io.code IN ('GAN_TOI','DANG_HOT','DI_TRONG_NGAY','CO_REVIEW','UU_TIEN_KHAC')
   """,Map.of()));
  assertEquals(1,db.count("""
   SELECT COUNT(*) FROM interest_tag_mappings m
   JOIN interest_options io ON io.id=m.interest_option_id
   JOIN place_tags pt ON pt.id=m.tag_id
   WHERE io.code='NGHI_DUONG' AND pt.code='relaxing' AND m.weight=1.000
   """,Map.of()));
 }

 @Test void onboardingPersistsOnlySemanticUserInterests() {
  var session=auth.register(new AuthDtos.Register("semantic_"+UUID.randomUUID()+"@example.com","TestPass123!","semantic_"+UUID.randomUUID().toString().substring(0,8)));
  @SuppressWarnings("unchecked")
  UUID userId=(UUID)((Map<String,Object>)session.get("user")).get("id");

  auth.onboarding(userId,List.of("NGHI_DUONG","THIEN_NHIEN","GAN_TOI","CO_REVIEW"));

  assertEquals(2,db.count("SELECT COUNT(*) FROM user_interests WHERE user_id=:id",args("id",userId)));
  assertEquals(0,db.count("""
   SELECT COUNT(*) FROM user_interests ui
   JOIN interest_options io ON io.id=ui.interest_option_id
   WHERE ui.user_id=:id AND io.code IN ('GAN_TOI','CO_REVIEW')
   """,args("id",userId)));
 }

 @Test void semanticEndpointsReturnDataForAuthenticatedUser() throws Exception {
  var session=auth.register(new AuthDtos.Register("semantic_api_"+UUID.randomUUID()+"@example.com","TestPass123!","semaapi_"+UUID.randomUUID().toString().substring(0,8)));
  String token="Bearer "+session.get("accessToken");

  mvc.perform(get("/api/v1/semantic/interests").header("Authorization",token))
   .andExpect(status().isOk())
   .andExpect(jsonPath("$.length()").value(19))
   .andExpect(jsonPath("$[?(@.code=='NGHI_DUONG')].interestType").value("SEMANTIC"));

  mvc.perform(get("/api/v1/semantic/place-tags").header("Authorization",token))
   .andExpect(status().isOk())
   .andExpect(jsonPath("$.length()").value(36));

  mvc.perform(get("/api/v1/semantic/interest-tag-mappings").header("Authorization",token))
   .andExpect(status().isOk())
   .andExpect(jsonPath("$.length()").value(53));
 }

 @Test void aiHandoffContainsExpectedFinalEnrichment() throws Exception {
  String tags=resourceText("data/ai_handoff/semantic_v1/ai_place_tags_v1.csv");
  assertTrue(tags.contains("external_id,canonical_name,destination_key,category,tag_code,weight,source_type,source_ref,reason,semantic_status,runtime_eligible,semantic_data_version,status_reason"));
  assertTrue(tags.contains("da_lat:ho_xuan_huong,Hồ Xuân Hương,da_lat,lake,walking_area,0.8,MANUAL_REVIEW"));
  assertTrue(tags.contains("da_lat:ho_xuan_huong,Hồ Xuân Hương,da_lat,lake,relaxing,0.6,CATALOG_NAME_RULE"));
  assertTrue(tags.contains("da_lat:cho_da_lat,Chợ Đà Lạt,da_lat,market,local_market,0.8,CATALOG_NAME_RULE"));
  assertTrue(tags.contains("da_lat:quang_truong_lam_vien,Quảng Trường Lâm Viên,da_lat,landmark,group_friendly,0.6,CATALOG_NAME_RULE"));

  String manifest=resourceText("data/ai_handoff/semantic_v1/semantic_v1_manifest.json");
  assertTrue(manifest.contains("\"releaseStatus\": \"FINAL\""));
  assertTrue(manifest.contains("\"canonicalPlaceCount\": 188"));
  assertTrue(manifest.contains("\"readyCount\": 114"));
  assertTrue(manifest.contains("\"partialCount\": 65"));
  assertTrue(manifest.contains("\"needReviewCount\": 9"));
  assertTrue(manifest.contains("\"placeTagLinkCount\": 831"));
  assertTrue(manifest.contains("\"sanityScenarioCount\": 30"));

  String qa=resourceText("data/ai_handoff/semantic_v1/semantic_v1_qa_summary.json");
  assertTrue(qa.contains("\"validationErrors\": []"));
  assertTrue(qa.contains("\"runtimeSemanticStatusDistribution\""));
  assertTrue(qa.contains("\"sanityIssueCount\": 2"));

  String interestCoverage=resourceText("data/ai_handoff/semantic_v1/semantic_interest_coverage_v1.csv");
  assertTrue(interestCoverage.contains("NGHI_DUONG,92,74,1.518"));
  String categoryCoverage=resourceText("data/ai_handoff/semantic_v1/semantic_category_coverage_v1.csv");
  assertTrue(categoryCoverage.contains("nature,55,51,4,0,4.44"));
  String scenarios=resourceText("data/ai_handoff/semantic_v1/semantic_sanity_scenarios_v1.csv");
  assertTrue(scenarios.contains("da_lat,NGHI_DUONG,1,da_lat:ho_xuan_huong"));
 }

 private String resourceText(String path) throws IOException {
  var resource=new ClassPathResource(path);
  try(var input=resource.getInputStream()) {
   return new String(input.readAllBytes(),StandardCharsets.UTF_8);
  }
 }
}
