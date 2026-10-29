package vn.gomate.moment.model;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("moment_mutes")
public class MomentMuteDocument {
 @Id private String id;
 private UUID muterUserId;
 private UUID mutedUserId;
 private Instant createdAt;

 public String getId() { return id; }
 public void setId(String id) { this.id=id; }
 public UUID getMuterUserId() { return muterUserId; }
 public void setMuterUserId(UUID muterUserId) { this.muterUserId=muterUserId; }
 public UUID getMutedUserId() { return mutedUserId; }
 public void setMutedUserId(UUID mutedUserId) { this.mutedUserId=mutedUserId; }
 public Instant getCreatedAt() { return createdAt; }
 public void setCreatedAt(Instant createdAt) { this.createdAt=createdAt; }
}
