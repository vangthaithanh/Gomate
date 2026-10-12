package vn.gomate.event.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Service;
import vn.gomate.event.model.InteractionEventDocument;

@Service
public class InteractionEventService {
    private static final Logger log = LoggerFactory.getLogger(InteractionEventService.class);
    public static final String HOME_RECOMMENDATION_SERVED = "HOME_RECOMMENDATION_SERVED";
    public static final String USER_FOLLOWED = "USER_FOLLOWED";
    public static final String USER_UNFOLLOWED = "USER_UNFOLLOWED";
    public static final String DIRECT_CONVERSATION_OPENED = "DIRECT_CONVERSATION_OPENED";
    public static final String MESSAGE_SENT = "MESSAGE_SENT";
    public static final String MESSAGE_REQUEST_ACCEPTED = "MESSAGE_REQUEST_ACCEPTED";
    public static final String USER_BLOCKED_IN_MESSAGE = "USER_BLOCKED_IN_MESSAGE";

    private final MongoTemplate mongo;

    public InteractionEventService(MongoTemplate mongo) {
        this.mongo = mongo;
    }

    public void recordHomeRecommendationServed(UUID userId, Map<String, Object> recommendationResult) {
        Map<String, Object> metadata = safeRecommendationMetadata(recommendationResult);
        InteractionEventDocument event = new InteractionEventDocument(
            UUID.randomUUID().toString(),
            userId,
            HOME_RECOMMENDATION_SERVED,
            "RECOMMENDATION",
            null,
            "spring.recommendations.home",
            Instant.now(),
            metadata
        );
        try {
            mongo.insert(event);
        } catch (Exception error) {
            log.warn(
                "Could not persist interaction event type={} userId={}: {}",
                HOME_RECOMMENDATION_SERVED,
                userId,
                error.getMessage()
            );
        }
    }

    public void recordUserFollowed(UUID actorUserId, UUID targetUserId, boolean mutualAfter) {
        recordUserRelationshipEvent(actorUserId, targetUserId, USER_FOLLOWED, mutualAfter);
    }

    public void recordUserUnfollowed(UUID actorUserId, UUID targetUserId, boolean mutualAfter) {
        recordUserRelationshipEvent(actorUserId, targetUserId, USER_UNFOLLOWED, mutualAfter);
    }

    public void recordDirectConversationOpened(UUID actorUserId, UUID conversationId) {
        recordConversationEvent(actorUserId, conversationId, DIRECT_CONVERSATION_OPENED);
    }

    public void recordMessageSent(UUID actorUserId, UUID conversationId) {
        recordConversationEvent(actorUserId, conversationId, MESSAGE_SENT);
    }

    public void recordMessageRequestAccepted(UUID actorUserId, UUID conversationId) {
        recordConversationEvent(actorUserId, conversationId, MESSAGE_REQUEST_ACCEPTED);
    }

    public void recordUserBlockedInMessage(UUID actorUserId, UUID conversationId) {
        recordConversationEvent(actorUserId, conversationId, USER_BLOCKED_IN_MESSAGE);
    }

    private void recordUserRelationshipEvent(UUID actorUserId, UUID targetUserId, String eventType, boolean mutualAfter) {
        InteractionEventDocument event = new InteractionEventDocument(
            UUID.randomUUID().toString(),
            actorUserId,
            eventType,
            "USER",
            targetUserId.toString(),
            "SOCIAL_RELATIONSHIP",
            Instant.now(),
            Map.of("mutualAfter", mutualAfter)
        );
        try {
            mongo.insert(event);
        } catch (Exception error) {
            log.warn(
                "Could not persist interaction event type={} userId={} targetUserId={}: {}",
                eventType,
                actorUserId,
                targetUserId,
                error.getMessage()
            );
        }
    }

    private void recordConversationEvent(UUID actorUserId, UUID conversationId, String eventType) {
        InteractionEventDocument event = new InteractionEventDocument(
            UUID.randomUUID().toString(),
            actorUserId,
            eventType,
            "CONVERSATION",
            conversationId.toString(),
            "DIRECT_MESSAGE",
            Instant.now(),
            Map.of()
        );
        try {
            mongo.insert(event);
        } catch (Exception error) {
            log.warn(
                "Could not persist interaction event type={} userId={} conversationId={}: {}",
                eventType,
                actorUserId,
                conversationId,
                error.getMessage()
            );
        }
    }

    private Map<String, Object> safeRecommendationMetadata(Map<String, Object> result) {
        Map<String, Object> metadata = new LinkedHashMap<>();
        if (result == null) {
            return metadata;
        }
        copyIfPresent(result, metadata, "modelVersion");
        copyIfPresent(result, metadata, "destinationKey");
        copyIfPresent(result, metadata, "scoringMode");
        copyIfPresent(result, metadata, "coldStart");
        copyIfPresent(result, metadata, "totalCandidates");
        metadata.put("optionCodes", stringList(result.get("optionCodes")));
        metadata.put("contextCodes", stringList(result.get("contextCodes")));

        List<Map<String, Object>> itemSummary = new ArrayList<>();
        Object items = result.get("items");
        if (items instanceof Iterable<?> iterable) {
            for (Object value : iterable) {
                if (!(value instanceof Map<?, ?> item)) {
                    continue;
                }
                Map<String, Object> summary = new LinkedHashMap<>();
                copyMapValue(item, summary, "placeId");
                copyMapValue(item, summary, "externalId");
                copyMapValue(item, summary, "destinationKey");
                copyMapValue(item, summary, "score");
                copyMapValue(item, summary, "modelSource");
                itemSummary.add(summary);
                if (itemSummary.size() >= 50) {
                    break;
                }
            }
        }
        metadata.put("items", itemSummary);
        metadata.put("finalCount", itemSummary.size());
        return metadata;
    }

    private void copyIfPresent(Map<String, Object> source, Map<String, Object> target, String key) {
        Object value = source.get(key);
        if (value != null) {
            target.put(key, simpleValue(value));
        }
    }

    private void copyMapValue(Map<?, ?> source, Map<String, Object> target, String key) {
        Object value = source.get(key);
        if (value != null) {
            target.put(key, simpleValue(value));
        }
    }

    private Object simpleValue(Object value) {
        if (value instanceof Number || value instanceof Boolean) {
            return value;
        }
        return value.toString();
    }

    private List<String> stringList(Object value) {
        if (!(value instanceof Iterable<?> iterable)) {
            return List.of();
        }
        List<String> result = new ArrayList<>();
        for (Object item : iterable) {
            if (item != null) {
                result.add(item.toString());
            }
        }
        return result;
    }
}
