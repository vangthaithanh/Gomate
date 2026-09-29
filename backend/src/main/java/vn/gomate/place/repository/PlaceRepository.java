package vn.gomate.place.repository;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import vn.gomate.map.routing.model.Coordinate;
import vn.gomate.media.dto.MediaUploadResult;
import static vn.gomate.common.Db.args;

@Repository
public class PlaceRepository {
 private final Db db;
 public PlaceRepository(Db db) { this.db=db; }

 public List<Map<String,Object>> listActive() {
  return db.list("""
   SELECT p.id AS place_id,p.name,c.code AS category,c.name AS category_name,
          p.latitude,p.longitude,p.province,p.district,p.address,
          (SELECT pm.url FROM place_media pm
           WHERE pm.place_id=p.id AND pm.media_type='IMAGE'
           ORDER BY pm.sort_order,pm.id LIMIT 1) AS thumbnail_url
   FROM places p
   JOIN place_categories c ON c.id=p.category_id
   WHERE p.status='ACTIVE' AND c.active=TRUE
   ORDER BY p.name,p.id
   """,Map.of());
 }

 public List<Map<String,Object>> searchActive(String q) {
  String like="%"+q.toLowerCase(Locale.ROOT)+"%";
  return db.list("""
   SELECT p.id AS place_id,p.name,c.code AS category,c.name AS category_name,
          p.latitude,p.longitude,p.province,p.district,p.address,
          (SELECT pm.url FROM place_media pm
           WHERE pm.place_id=p.id AND pm.media_type='IMAGE'
           ORDER BY pm.sort_order,pm.id LIMIT 1) AS thumbnail_url
   FROM places p
   JOIN place_categories c ON c.id=p.category_id
   WHERE p.status='ACTIVE' AND c.active=TRUE
     AND (
      LOWER(p.name) LIKE :q OR LOWER(p.province) LIKE :q OR
      LOWER(COALESCE(p.district,'')) LIKE :q OR LOWER(COALESCE(p.address,'')) LIKE :q
     )
   ORDER BY p.name,p.id
   """,args("q",like));
 }

 public Optional<Map<String,Object>> detail(long id) {
  return db.list("""
   SELECT p.id,p.name,p.description,p.province,p.district,p.address,
          p.latitude,p.longitude,p.opening_hours,p.price_level,p.avg_rating,
          p.review_count,p.save_count,p.source_type,p.status,p.created_at,p.updated_at,
          c.id AS category_id,c.code AS category_code,c.name AS category_name
   FROM places p
   JOIN place_categories c ON c.id=p.category_id
   WHERE p.id=:id AND p.status<>'DELETED'
   """,args("id",id)).stream().findFirst();
 }

 public List<Map<String,Object>> media(long placeId) {
  return db.list("""
   SELECT id,media_type,url,caption,sort_order,created_at
   FROM place_media
   WHERE place_id=:placeId
   ORDER BY sort_order,id
   """,args("placeId",placeId));
 }

 public Optional<Coordinate> activeCoordinate(long placeId) {
  return db.list("""
   SELECT longitude, latitude
   FROM places
   WHERE id=:placeId AND status='ACTIVE'
   """,args("placeId",placeId)).stream().findFirst().map(row -> new Coordinate(
   ((Number)row.get("longitude")).doubleValue(),
   ((Number)row.get("latitude")).doubleValue()
  ));
 }

 public long upsertCategory(String code,String name,String description) {
  return ((Number)db.one("""
   WITH existing_code AS (
    SELECT id FROM place_categories WHERE code=:code
   ),
   name_conflict AS (
    SELECT id FROM place_categories WHERE name=:name AND code<>:code
   ),
   updated AS (
    UPDATE place_categories
    SET name=CASE WHEN EXISTS(SELECT 1 FROM name_conflict) THEN name ELSE :name END,
        description=:description,
        active=TRUE
    WHERE code=:code
    RETURNING id
   ),
   inserted AS (
    INSERT INTO place_categories(code,name,description,active)
    SELECT :code,:name,:description,TRUE
    WHERE NOT EXISTS(SELECT 1 FROM existing_code)
      AND NOT EXISTS(SELECT 1 FROM name_conflict)
    ON CONFLICT (code) DO UPDATE SET
     name=EXCLUDED.name,
     description=EXCLUDED.description,
     active=TRUE
    RETURNING id
   )
   SELECT id FROM updated
   UNION ALL
   SELECT id FROM inserted
   UNION ALL
   SELECT id FROM name_conflict
   LIMIT 1
   """,args("code",code,"name",name,"description",description)).get("id")).longValue();
 }

 public long upsertImportedPlace(ImportedPlace place,long categoryId) {
  return ((Number)db.one("""
   INSERT INTO places(
    category_id,name,description,province,district,address,latitude,longitude,
    source_type,external_source,external_id,status,updated_at
   )
   VALUES(
    :categoryId,:name,:description,:province,:district,:address,:latitude,:longitude,
    :sourceType,:externalSource,:externalId,'ACTIVE',CURRENT_TIMESTAMP
   )
   ON CONFLICT (external_source, external_id) DO UPDATE SET
    category_id=EXCLUDED.category_id,
    name=EXCLUDED.name,
    description=EXCLUDED.description,
    province=EXCLUDED.province,
    district=EXCLUDED.district,
    address=EXCLUDED.address,
    latitude=EXCLUDED.latitude,
    longitude=EXCLUDED.longitude,
    source_type=EXCLUDED.source_type,
    status='ACTIVE',
    updated_at=CURRENT_TIMESTAMP
   RETURNING id
   """,args(
    "categoryId",categoryId,
    "name",place.name(),
    "description",place.description(),
    "province",place.province(),
    "district",place.district(),
    "address",place.address(),
    "latitude",place.latitude(),
    "longitude",place.longitude(),
    "sourceType",place.sourceType(),
    "externalSource",place.externalSource(),
    "externalId",place.externalId()
   )).get("id")).longValue();
 }

 public boolean mediaExists(String publicId) {
  return db.count("SELECT COUNT(*) FROM place_media WHERE public_id=:publicId",args("publicId",publicId))>0;
 }

 public boolean imageMediaExistsForPlace(long placeId) {
  return db.count("""
   SELECT COUNT(*) FROM place_media
   WHERE place_id=:placeId AND media_type='IMAGE'
   """,args("placeId",placeId))>0;
 }

 public void insertPlaceMedia(long placeId,MediaUploadResult uploaded,String caption,int sortOrder) {
  db.update("""
   INSERT INTO place_media(place_id,media_type,url,public_id,caption,sort_order)
   VALUES(:placeId,:mediaType,:url,:publicId,:caption,:sortOrder)
   """,args(
    "placeId",placeId,
    "mediaType",uploaded.resourceType().name(),
    "url",uploaded.secureUrl(),
    "publicId",uploaded.publicId(),
    "caption",caption,
    "sortOrder",sortOrder
   ));
 }

 public record ImportedPlace(
  String name,
  String description,
  String province,
  String district,
  String address,
  java.math.BigDecimal latitude,
  java.math.BigDecimal longitude,
  String sourceType,
  String externalSource,
  String externalId
 ) {}
}
