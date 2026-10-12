package vn.gomate.location.model;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("trip_current_locations")
public class TripCurrentLocationDocument {
 @Id
 private String id;
 private UUID tripId;
 private UUID userId;
 private double latitude;
 private double longitude;
 private Double accuracyM;
 private Instant capturedAt;
 private Instant updatedAt;

 public String getId() { return id; }
 public void setId(String id) { this.id=id; }
 public UUID getTripId() { return tripId; }
 public void setTripId(UUID tripId) { this.tripId=tripId; }
 public UUID getUserId() { return userId; }
 public void setUserId(UUID userId) { this.userId=userId; }
 public double getLatitude() { return latitude; }
 public void setLatitude(double latitude) { this.latitude=latitude; }
 public double getLongitude() { return longitude; }
 public void setLongitude(double longitude) { this.longitude=longitude; }
 public Double getAccuracyM() { return accuracyM; }
 public void setAccuracyM(Double accuracyM) { this.accuracyM=accuracyM; }
 public Instant getCapturedAt() { return capturedAt; }
 public void setCapturedAt(Instant capturedAt) { this.capturedAt=capturedAt; }
 public Instant getUpdatedAt() { return updatedAt; }
 public void setUpdatedAt(Instant updatedAt) { this.updatedAt=updatedAt; }
}
