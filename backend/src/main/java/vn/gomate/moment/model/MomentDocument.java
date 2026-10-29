package vn.gomate.moment.model;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("moments")
public class MomentDocument {
 @Id private String id;
 private String momentId;
 private UUID ownerUserId;
 private String mediaUrl;
 private String mediaPublicId;
 private String mediaType;
 private Integer width;
 private Integer height;
 private Long bytes;
 private String caption;
 private String locationText;
 private Long placeId;
 private Double latitude;
 private Double longitude;
 private String visibility;
 private Instant createdAt;
 private Instant expiresAt;
 private Instant deletedAt;

 public String getId() { return id; }
 public void setId(String id) { this.id=id; }
 public String getMomentId() { return momentId; }
 public void setMomentId(String momentId) { this.momentId=momentId; }
 public UUID getOwnerUserId() { return ownerUserId; }
 public void setOwnerUserId(UUID ownerUserId) { this.ownerUserId=ownerUserId; }
 public String getMediaUrl() { return mediaUrl; }
 public void setMediaUrl(String mediaUrl) { this.mediaUrl=mediaUrl; }
 public String getMediaPublicId() { return mediaPublicId; }
 public void setMediaPublicId(String mediaPublicId) { this.mediaPublicId=mediaPublicId; }
 public String getMediaType() { return mediaType; }
 public void setMediaType(String mediaType) { this.mediaType=mediaType; }
 public Integer getWidth() { return width; }
 public void setWidth(Integer width) { this.width=width; }
 public Integer getHeight() { return height; }
 public void setHeight(Integer height) { this.height=height; }
 public Long getBytes() { return bytes; }
 public void setBytes(Long bytes) { this.bytes=bytes; }
 public String getCaption() { return caption; }
 public void setCaption(String caption) { this.caption=caption; }
 public String getLocationText() { return locationText; }
 public void setLocationText(String locationText) { this.locationText=locationText; }
 public Long getPlaceId() { return placeId; }
 public void setPlaceId(Long placeId) { this.placeId=placeId; }
 public Double getLatitude() { return latitude; }
 public void setLatitude(Double latitude) { this.latitude=latitude; }
 public Double getLongitude() { return longitude; }
 public void setLongitude(Double longitude) { this.longitude=longitude; }
 public String getVisibility() { return visibility; }
 public void setVisibility(String visibility) { this.visibility=visibility; }
 public Instant getCreatedAt() { return createdAt; }
 public void setCreatedAt(Instant createdAt) { this.createdAt=createdAt; }
 public Instant getExpiresAt() { return expiresAt; }
 public void setExpiresAt(Instant expiresAt) { this.expiresAt=expiresAt; }
 public Instant getDeletedAt() { return deletedAt; }
 public void setDeletedAt(Instant deletedAt) { this.deletedAt=deletedAt; }
}
