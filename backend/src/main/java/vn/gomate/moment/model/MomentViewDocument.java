package vn.gomate.moment.model;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("moment_views")
public class MomentViewDocument {
 @Id private String id;
 private String momentId;
 private UUID ownerUserId;
 private UUID viewerUserId;
 private Instant viewedAt;

 public String getId() { return id; }
 public void setId(String id) { this.id=id; }
 public String getMomentId() { return momentId; }
 public void setMomentId(String momentId) { this.momentId=momentId; }
 public UUID getOwnerUserId() { return ownerUserId; }
 public void setOwnerUserId(UUID ownerUserId) { this.ownerUserId=ownerUserId; }
 public UUID getViewerUserId() { return viewerUserId; }
 public void setViewerUserId(UUID viewerUserId) { this.viewerUserId=viewerUserId; }
 public Instant getViewedAt() { return viewedAt; }
 public void setViewedAt(Instant viewedAt) { this.viewedAt=viewedAt; }
}
