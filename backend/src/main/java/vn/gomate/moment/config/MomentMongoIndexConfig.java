package vn.gomate.moment.config;

import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;
import vn.gomate.moment.model.MomentDocument;
import vn.gomate.moment.model.MomentMuteDocument;
import vn.gomate.moment.model.MomentReactionDocument;
import vn.gomate.moment.model.MomentViewDocument;

@Component
public class MomentMongoIndexConfig {
 private final MongoTemplate mongo;

 public MomentMongoIndexConfig(MongoTemplate mongo) {
  this.mongo=mongo;
 }

 @EventListener(ApplicationReadyEvent.class)
 public void ensureIndexes() {
  try {
   mongo.indexOps(MomentDocument.class)
    .ensureIndex(new Index().on("momentId",Sort.Direction.ASC).unique().named("ux_moments_moment_id"));
   mongo.indexOps(MomentDocument.class)
    .ensureIndex(new Index().on("ownerUserId",Sort.Direction.ASC).on("createdAt",Sort.Direction.DESC).named("idx_moments_owner_created"));
   mongo.indexOps(MomentDocument.class)
    .ensureIndex(new Index().on("expiresAt",Sort.Direction.DESC).on("createdAt",Sort.Direction.DESC).named("idx_moments_expires_created"));
   mongo.indexOps(MomentViewDocument.class)
    .ensureIndex(new Index().on("momentId",Sort.Direction.ASC).on("viewerUserId",Sort.Direction.ASC).unique().named("ux_moment_views_moment_viewer"));
   mongo.indexOps(MomentViewDocument.class)
    .ensureIndex(new Index().on("viewerUserId",Sort.Direction.ASC).on("viewedAt",Sort.Direction.DESC).named("idx_moment_views_viewer_time"));
   mongo.indexOps(MomentReactionDocument.class)
    .ensureIndex(new Index().on("momentId",Sort.Direction.ASC).on("reactorUserId",Sort.Direction.ASC).unique().named("ux_moment_reactions_moment_reactor"));
   mongo.indexOps(MomentReactionDocument.class)
    .ensureIndex(new Index().on("momentId",Sort.Direction.ASC).on("reactedAt",Sort.Direction.DESC).named("idx_moment_reactions_moment_time"));
   mongo.indexOps(MomentMuteDocument.class)
    .ensureIndex(new Index().on("muterUserId",Sort.Direction.ASC).on("mutedUserId",Sort.Direction.ASC).unique().named("ux_moment_mutes_pair"));
  } catch(Exception e) {
   LoggerFactory.getLogger(MomentMongoIndexConfig.class).warn("Could not ensure MongoDB moment indexes",e);
  }
 }
}
