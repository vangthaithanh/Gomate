package vn.gomate.place.review;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;

@Service
public class PlaceReviewService {
 public record Write(BigDecimal rating,String content) {}
 private final PlaceReviewRepository repo;
 public PlaceReviewService(PlaceReviewRepository repo) {this.repo=repo;}
 private int rating(Write body) {
  if(body==null || body.rating()==null || body.rating().stripTrailingZeros().scale()>0 || body.rating().compareTo(BigDecimal.ONE)<0 || body.rating().compareTo(BigDecimal.valueOf(5))>0)
   throw ApiException.bad("Chọn số sao nguyên từ 1 đến 5.");
  if(body.content()!=null && body.content().length()>1000) throw ApiException.bad("Nhận xét tối đa 1000 ký tự.");
  return body.rating().intValueExact();
 }
 private String content(Write body) {return body.content()==null?null:body.content().trim();}
 @Transactional
 public Map<String,Object> submit(UUID actor,long place,Write body) {
  int stars=rating(body);repo.activeActor(actor);repo.lockPlace(place);
  var existing=repo.mine(actor,place);
  long id=existing==null?repo.create(actor,place,stars,content(body)):((Number)existing.get("id")).longValue();
  if(existing!=null) repo.update(id,stars,content(body));
  repo.aggregate(place);return result(actor,place);
 }
 @Transactional
 public Map<String,Object> edit(UUID actor,long id,Write body) {
  int stars=rating(body);repo.activeActor(actor);var row=repo.review(id);
  if(!actor.equals(row.get("userId"))) throw new ApiException(403,"FORBIDDEN","Bạn chỉ được sửa đánh giá của mình.");
  long place=((Number)row.get("placeId")).longValue();repo.lockPlace(place);
  row=repo.review(id);
  if(!"ACTIVE".equals(row.get("publicationStatus"))) throw ApiException.notFound();
  repo.update(id,stars,content(body));repo.aggregate(place);return result(actor,place);
 }
 @Transactional
 public Map<String,Object> delete(UUID actor,long id) {
  repo.activeActor(actor);var row=repo.review(id);
  if(!actor.equals(row.get("userId"))) throw new ApiException(403,"FORBIDDEN","Bạn chỉ được xóa đánh giá của mình.");
  long place=((Number)row.get("placeId")).longValue();repo.lockPlace(place);
  repo.delete(id);repo.aggregate(place);return result(actor,place);
 }
 @Transactional(readOnly=true)
 public Map<String,Object> mine(UUID actor,long place) {repo.publicPlace(place);return result(actor,place);}
 private Map<String,Object> result(UUID actor,long place) {
  var result=new LinkedHashMap<>(repo.stats(place));var row=repo.mine(actor,place);
  result.put("myReview",row==null?null:owned(row));return result;
 }
 private Map<String,Object> owned(Map<String,Object> row) {
  var copy=new LinkedHashMap<String,Object>();
  for(String key:List.of("id","placeId","rating","content","publicationStatus","moderationStatus","createdAt","updatedAt")) copy.put(key,utc(row.get(key)));
  return copy;
 }
 private Object utc(Object value) {
  if(value instanceof java.time.OffsetDateTime time) return time.withOffsetSameInstant(java.time.ZoneOffset.UTC);
  if(value instanceof LocalDateTime time) return time.atZone(java.time.ZoneId.systemDefault()).withZoneSameInstant(java.time.ZoneOffset.UTC).toOffsetDateTime();
  return value;
 }
 @Transactional(readOnly=true)
 public Map<String,Object> page(UUID actor,long place,int size,long before) {
  return page(actor,place,size,before,"newest");
 }
 @Transactional(readOnly=true)
 public Map<String,Object> page(UUID actor,long place,int size,long before,String sort) {
  repo.publicPlace(place);
  if(size<1 || size>50 || before<1 || !Set.of("newest","highest","lowest").contains(sort)) throw ApiException.bad("Trang đánh giá không hợp lệ.");
  var rows=repo.page(actor,place,size+1,before,sort);var items=new ArrayList<Map<String,Object>>();
  for(var row:rows.subList(0,Math.min(size,rows.size()))) {
   var item=new LinkedHashMap<String,Object>();row.forEach((key,value)->item.put(key,utc(value)));items.add(item);
  }
  var result=new LinkedHashMap<>(repo.stats(place));result.put("items",items);
  result.put("nextBeforeId",rows.size()>size?items.get(items.size()-1).get("id"):null);return result;
 }
}
