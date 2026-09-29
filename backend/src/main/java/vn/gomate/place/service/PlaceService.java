package vn.gomate.place.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;
import vn.gomate.place.dto.PlaceDtos;
import vn.gomate.place.repository.PlaceRepository;

@Service
public class PlaceService {
 private final PlaceRepository repo;
 public PlaceService(PlaceRepository repo) { this.repo=repo; }

 public List<PlaceDtos.Summary> list() {
  return repo.listActive().stream().map(this::summary).toList();
 }

 public List<PlaceDtos.Summary> search(String q) {
  String normalized=q==null?"":q.trim();
  if(normalized.isEmpty()) return list();
  return repo.searchActive(normalized).stream().map(this::summary).toList();
 }

 public PlaceDtos.Detail detail(long id) {
  Map<String,Object> row=repo.detail(id).orElseThrow(ApiException::notFound);
  var category=new PlaceDtos.Category(asLong(row.get("categoryId")),(String)row.get("categoryCode"),(String)row.get("categoryName"));
  var media=repo.media(id).stream().map(this::media).toList();
  return new PlaceDtos.Detail(
   asLong(row.get("id")),
   (String)row.get("name"),
   category,
   (String)row.get("description"),
   (String)row.get("province"),
   (String)row.get("district"),
   (String)row.get("address"),
   (BigDecimal)row.get("latitude"),
   (BigDecimal)row.get("longitude"),
   row.get("openingHours")==null?null:row.get("openingHours").toString(),
   asInt(row.get("priceLevel")),
   (BigDecimal)row.get("avgRating"),
   asInt(row.get("reviewCount")),
   asInt(row.get("saveCount")),
   (String)row.get("sourceType"),
   (String)row.get("status"),
   (LocalDateTime)row.get("createdAt"),
   (LocalDateTime)row.get("updatedAt"),
   media
  );
 }

 private PlaceDtos.Summary summary(Map<String,Object> row) {
  return new PlaceDtos.Summary(
   asLong(row.get("placeId")),
   (String)row.get("name"),
   (String)row.get("category"),
   (String)row.get("categoryName"),
   (BigDecimal)row.get("latitude"),
   (BigDecimal)row.get("longitude"),
   (String)row.get("province"),
   (String)row.get("district"),
   (String)row.get("address"),
   (String)row.get("thumbnailUrl")
  );
 }

 private PlaceDtos.Media media(Map<String,Object> row) {
  return new PlaceDtos.Media(
   asLong(row.get("id")),
   (String)row.get("mediaType"),
   (String)row.get("url"),
   (String)row.get("caption"),
   asInt(row.get("sortOrder")),
   (LocalDateTime)row.get("createdAt")
  );
 }

 private static Long asLong(Object value) {
  if(value==null) return null;
  if(value instanceof Number number) return number.longValue();
  return Long.valueOf(value.toString());
 }

 private static Integer asInt(Object value) {
  if(value==null) return null;
  if(value instanceof Number number) return number.intValue();
  return Integer.valueOf(value.toString());
 }
}
