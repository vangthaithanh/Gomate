package vn.gomate.semantic.repository;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class SemanticRepository {
 private final Db db;
 public SemanticRepository(Db db) { this.db=db; }

 public List<Map<String,Object>> interests() {
  return db.list("""
   SELECT io.id,io.code,io.label,ig.code AS group_code,ig.name AS group_name,
          CASE WHEN ig.code='CONTEXT_STRATEGY' THEN 'CONTEXT' ELSE 'SEMANTIC' END AS interest_type,
          io.description,io.active
   FROM interest_options io
   JOIN interest_groups ig ON ig.id=io.group_id
   ORDER BY ig.sort_order,io.sort_order,io.id
   """,Map.of());
 }

 public List<Map<String,Object>> tags() {
  return db.list("""
   SELECT id,code,label,active
   FROM place_tags
   ORDER BY code
   """,Map.of());
 }

 public List<Map<String,Object>> interestTagMappings() {
  return db.list("""
   SELECT io.code AS interest_code,pt.code AS tag_code,m.weight
   FROM interest_tag_mappings m
   JOIN interest_options io ON io.id=m.interest_option_id
   JOIN place_tags pt ON pt.id=m.tag_id
   ORDER BY io.code,pt.code
   """,Map.of());
 }

 public List<Map<String,Object>> placeTags(long placeId) {
  return db.list("""
   SELECT p.id AS place_id,p.external_id,p.name AS place_name,
          pt.code AS tag_code,pt.label AS tag_label,l.weight
   FROM place_tag_links l
   JOIN places p ON p.id=l.place_id
   JOIN place_tags pt ON pt.id=l.tag_id
   WHERE p.id=:placeId
   ORDER BY l.weight DESC,pt.code
   """,args("placeId",placeId));
 }

 public List<Map<String,Object>> userInterests(UUID userId) {
  return db.list("""
   SELECT io.code AS interest_code,io.label AS interest_label,ig.code AS group_code,
          ui.preference_weight,ui.selected_at
   FROM user_interests ui
   JOIN interest_options io ON io.id=ui.interest_option_id
   JOIN interest_groups ig ON ig.id=io.group_id
   WHERE ui.user_id=:userId
   ORDER BY ig.sort_order,io.sort_order,io.id
   """,args("userId",userId));
 }
}
