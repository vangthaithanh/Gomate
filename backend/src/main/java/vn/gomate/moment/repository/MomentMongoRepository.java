package vn.gomate.moment.repository;

import com.mongodb.MongoException;
import com.mongodb.client.result.DeleteResult;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Repository;
import vn.gomate.common.ApiException;
import vn.gomate.moment.model.MomentDocument;
import vn.gomate.moment.model.MomentMuteDocument;
import vn.gomate.moment.model.MomentReactionDocument;
import vn.gomate.moment.model.MomentViewDocument;

@Repository
public class MomentMongoRepository {
 private final MongoTemplate mongo;

 public MomentMongoRepository(MongoTemplate mongo) {
  this.mongo=mongo;
 }

 public MomentDocument save(MomentDocument doc) {
  try {
   return mongo.save(doc);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public Optional<MomentDocument> findActive(String momentId,Instant now) {
  try {
   var criteria=Criteria.where("momentId").is(momentId)
    .and("deletedAt").is(null)
    .and("expiresAt").gt(now);
   return Optional.ofNullable(mongo.findOne(new Query(criteria),MomentDocument.class));
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public Optional<MomentDocument> findOwnedHistory(String momentId,UUID ownerUserId) {
  try {
   var criteria=Criteria.where("momentId").is(momentId)
    .and("ownerUserId").is(ownerUserId)
    .and("deletedAt").is(null);
   return Optional.ofNullable(mongo.findOne(new Query(criteria),MomentDocument.class));
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public List<MomentDocument> ownerHistory(UUID ownerUserId,int limit) {
  try {
   return mongo.find(new Query(Criteria.where("ownerUserId").is(ownerUserId).and("deletedAt").is(null))
    .with(Sort.by(Sort.Direction.DESC,"createdAt"))
    .limit(Math.max(1,Math.min(limit,200))),MomentDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public List<MomentDocument> activeOwn(UUID ownerUserId,Instant now) {
  try {
   return mongo.find(new Query(Criteria.where("ownerUserId").is(ownerUserId)
    .and("deletedAt").is(null)
    .and("expiresAt").gt(now))
    .with(Sort.by(Sort.Direction.DESC,"createdAt")),MomentDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public List<MomentDocument> activeByOwners(Collection<UUID> ownerIds,Instant now,int limit) {
  if(ownerIds==null || ownerIds.isEmpty()) return List.of();
  try {
   return mongo.find(new Query(Criteria.where("ownerUserId").in(ownerIds)
    .and("deletedAt").is(null)
    .and("expiresAt").gt(now))
    .with(Sort.by(Sort.Direction.DESC,"createdAt"))
    .limit(Math.max(1,Math.min(limit,500))),MomentDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public Set<String> viewedMomentIds(UUID viewerUserId,Collection<String> momentIds) {
  if(momentIds==null || momentIds.isEmpty()) return Set.of();
  try {
   var docs=mongo.find(new Query(Criteria.where("viewerUserId").is(viewerUserId).and("momentId").in(momentIds)),MomentViewDocument.class);
   return docs.stream().map(MomentViewDocument::getMomentId).collect(java.util.stream.Collectors.toSet());
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public boolean viewed(UUID viewerUserId,String momentId) {
  try {
   return mongo.exists(new Query(Criteria.where("viewerUserId").is(viewerUserId).and("momentId").is(momentId)),MomentViewDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public void markViewed(String momentId,UUID ownerUserId,UUID viewerUserId,Instant viewedAt) {
  try {
   var query=new Query(Criteria.where("momentId").is(momentId).and("viewerUserId").is(viewerUserId));
   var update=new Update()
    .setOnInsert("momentId",momentId)
    .setOnInsert("ownerUserId",ownerUserId)
    .setOnInsert("viewerUserId",viewerUserId)
    .setOnInsert("viewedAt",viewedAt);
   mongo.upsert(query,update,MomentViewDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public List<MomentReactionDocument> reactions(String momentId) {
  try {
   return mongo.find(new Query(Criteria.where("momentId").is(momentId))
    .with(Sort.by(Sort.Direction.DESC,"reactedAt")),MomentReactionDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public Optional<MomentReactionDocument> reaction(String momentId,UUID reactorUserId) {
  try {
   return Optional.ofNullable(mongo.findOne(new Query(Criteria.where("momentId").is(momentId).and("reactorUserId").is(reactorUserId)),MomentReactionDocument.class));
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public MomentReactionDocument saveReaction(MomentReactionDocument doc) {
  try {
   return mongo.save(doc);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public Set<UUID> mutedOwnerIds(UUID muterUserId) {
  try {
   var docs=mongo.find(new Query(Criteria.where("muterUserId").is(muterUserId)),MomentMuteDocument.class);
   return docs.stream().map(MomentMuteDocument::getMutedUserId).collect(java.util.stream.Collectors.toSet());
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public boolean muted(UUID muterUserId,UUID mutedUserId) {
  try {
   return mongo.exists(new Query(Criteria.where("muterUserId").is(muterUserId).and("mutedUserId").is(mutedUserId)),MomentMuteDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public void mute(UUID muterUserId,UUID mutedUserId,Instant createdAt) {
  try {
   var query=new Query(Criteria.where("muterUserId").is(muterUserId).and("mutedUserId").is(mutedUserId));
   var update=new Update()
    .setOnInsert("muterUserId",muterUserId)
    .setOnInsert("mutedUserId",mutedUserId)
    .setOnInsert("createdAt",createdAt);
   mongo.upsert(query,update,MomentMuteDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public void unmute(UUID muterUserId,UUID mutedUserId) {
  try {
   mongo.remove(new Query(Criteria.where("muterUserId").is(muterUserId).and("mutedUserId").is(mutedUserId)),MomentMuteDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public boolean hardDeleteOwned(String momentId,UUID ownerUserId,Instant deletedAt) {
  try {
   var query=new Query(Criteria.where("momentId").is(momentId).and("ownerUserId").is(ownerUserId).and("deletedAt").is(null));
   var result=mongo.updateFirst(query,new Update().set("deletedAt",deletedAt),MomentDocument.class);
   if(result.getModifiedCount()>0) {
    cleanupMomentEdges(momentId);
    return true;
   }
   return false;
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 public DeleteResult cleanupMomentEdges(String momentId) {
  try {
   mongo.remove(new Query(Criteria.where("momentId").is(momentId)),MomentViewDocument.class);
   mongo.remove(new Query(Criteria.where("momentId").is(momentId)),MomentReactionDocument.class);
   return DeleteResult.acknowledged(0);
  } catch(DataAccessException|MongoException e) {
   throw storeDown(e);
  }
 }

 private ApiException storeDown(Exception e) {
  return new ApiException(503,"MOMENT_STORE_UNAVAILABLE","Không thể tải khoảnh khắc lúc này. Vui lòng thử lại.",e);
 }
}
