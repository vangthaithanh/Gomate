package vn.gomate.event.model;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("interaction_events")
public class InteractionEventDocument {
    @Id
    private String id;
    private String eventId;
    private UUID userId;
    private String eventType;
    private String entityType;
    private String entityId;
    private String source;
    private Instant createdAt;
    private Map<String, Object> metadata;

    protected InteractionEventDocument() {
    }

    public InteractionEventDocument(
        String eventId,
        UUID userId,
        String eventType,
        String entityType,
        String entityId,
        String source,
        Instant createdAt,
        Map<String, Object> metadata
    ) {
        this.eventId = eventId;
        this.userId = userId;
        this.eventType = eventType;
        this.entityType = entityType;
        this.entityId = entityId;
        this.source = source;
        this.createdAt = createdAt;
        this.metadata = metadata;
    }

    public String getId() {
        return id;
    }

    public String getEventId() {
        return eventId;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getEventType() {
        return eventType;
    }

    public String getEntityType() {
        return entityType;
    }

    public String getEntityId() {
        return entityId;
    }

    public String getSource() {
        return source;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Map<String, Object> getMetadata() {
        return metadata;
    }
}
