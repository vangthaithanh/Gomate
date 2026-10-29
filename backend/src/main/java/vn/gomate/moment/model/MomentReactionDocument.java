package vn.gomate.moment.model;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("moment_reactions")
public class MomentReactionDocument {
 @Id private String id;
 private String reactionId;
 private String momentId;
 private UUID ownerUserId;
 private UUID reactorUserId;
 private String type;
 private Instant reactedAt;

 public String getId() { return id; }
 public void setId(String id) { this.id=id; }
 public String getReactionId() { return reactionId; }
 public void setReactionId(String reactionId) { this.reactionId=reactionId; }
 public String getMomentId() { return momentId; }
 public void setMomentId(String momentId) { this.momentId=momentId; }
 public UUID getOwnerUserId() { return ownerUserId; }
 public void setOwnerUserId(UUID ownerUserId) { this.ownerUserId=ownerUserId; }
 public UUID getReactorUserId() { return reactorUserId; }
 public void setReactorUserId(UUID reactorUserId) { this.reactorUserId=reactorUserId; }
 public String getType() { return type; }
 public void setType(String type) { this.type=type; }
 public Instant getReactedAt() { return reactedAt; }
 public void setReactedAt(Instant reactedAt) { this.reactedAt=reactedAt; }
}
