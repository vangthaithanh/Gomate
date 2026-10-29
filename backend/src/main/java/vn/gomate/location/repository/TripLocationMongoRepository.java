package vn.gomate.location.repository;

import com.mongodb.MongoException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Repository;
import vn.gomate.common.ApiException;
import vn.gomate.location.model.TripCurrentLocationDocument;

@Repository
public class TripLocationMongoRepository {
 public void deleteByTrip(UUID tripId) {
  mongo.remove(new Query(Criteria.where("tripId").is(tripId)),TripCurrentLocationDocument.class);
 }
 public void deleteByMember(UUID tripId,UUID userId) {
  mongo.remove(new Query(Criteria.where("tripId").is(tripId).and("userId").is(userId)),TripCurrentLocationDocument.class);
 }
 private final MongoTemplate mongo;

 public TripLocationMongoRepository(MongoTemplate mongo) {
  this.mongo=mongo;
 }

 public TripCurrentLocationDocument upsert(UUID tripId,UUID userId,double latitude,double longitude,Double accuracyM,Instant capturedAt,Instant updatedAt) {
  try {
   var query=new Query(Criteria.where("tripId").is(tripId).and("userId").is(userId));
   var update=new Update()
    .set("tripId",tripId)
    .set("userId",userId)
    .set("latitude",latitude)
    .set("longitude",longitude)
    .set("accuracyM",accuracyM)
    .set("capturedAt",capturedAt)
    .set("updatedAt",updatedAt);
   mongo.upsert(query,update,TripCurrentLocationDocument.class);
   return mongo.findOne(query,TripCurrentLocationDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"LOCATION_STORE_UNAVAILABLE","Không thể cập nhật vị trí lúc này. Vui lòng thử lại.",e);
  }
 }

 public List<TripCurrentLocationDocument> findByTrip(UUID tripId) {
  try {
   return mongo.find(new Query(Criteria.where("tripId").is(tripId))
    .with(Sort.by(Sort.Direction.DESC,"updatedAt")),TripCurrentLocationDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"LOCATION_STORE_UNAVAILABLE","Không thể tải vị trí thành viên lúc này. Vui lòng thử lại.",e);
  }
 }
}
