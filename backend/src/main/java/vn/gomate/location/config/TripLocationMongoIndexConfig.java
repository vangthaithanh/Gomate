package vn.gomate.location.config;

import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;
import vn.gomate.location.model.TripCurrentLocationDocument;

@Component
public class TripLocationMongoIndexConfig {
 private final MongoTemplate mongo;

 public TripLocationMongoIndexConfig(MongoTemplate mongo) {
  this.mongo=mongo;
 }

 @EventListener(ApplicationReadyEvent.class)
 public void ensureIndexes() {
  try {
   var ops=mongo.indexOps(TripCurrentLocationDocument.class);
   ops.ensureIndex(new Index().on("tripId",Sort.Direction.ASC).on("userId",Sort.Direction.ASC).unique().named("ux_trip_current_locations_trip_user"));
   ops.ensureIndex(new Index().on("tripId",Sort.Direction.ASC).on("updatedAt",Sort.Direction.DESC).named("idx_trip_current_locations_trip_updated"));
   ops.ensureIndex(new Index().on("updatedAt",Sort.Direction.DESC).named("idx_trip_current_locations_updated"));
  } catch(Exception e) {
   LoggerFactory.getLogger(TripLocationMongoIndexConfig.class).warn("Could not ensure MongoDB trip location indexes",e);
  }
 }
}
