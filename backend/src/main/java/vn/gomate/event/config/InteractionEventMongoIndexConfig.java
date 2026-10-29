package vn.gomate.event.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;

@Component
public class InteractionEventMongoIndexConfig implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(InteractionEventMongoIndexConfig.class);

    private final MongoTemplate mongo;

    public InteractionEventMongoIndexConfig(MongoTemplate mongo) {
        this.mongo = mongo;
    }

    @Override
    public void run(ApplicationArguments args) {
        try {
            var indexes = mongo.indexOps("interaction_events");
            indexes.ensureIndex(new Index().on("eventId", Sort.Direction.ASC).unique().named("ux_interaction_events_event_id"));
            indexes.ensureIndex(new Index().on("userId", Sort.Direction.ASC).on("createdAt", Sort.Direction.DESC).named("idx_interaction_events_user_created"));
            indexes.ensureIndex(new Index().on("eventType", Sort.Direction.ASC).on("createdAt", Sort.Direction.DESC).named("idx_interaction_events_type_created"));
            indexes.ensureIndex(new Index()
                .on("entityType", Sort.Direction.ASC)
                .on("entityId", Sort.Direction.ASC)
                .on("createdAt", Sort.Direction.DESC)
                .named("idx_interaction_events_entity_created"));
        } catch (Exception error) {
            log.warn("Could not ensure Mongo indexes for interaction_events: {}", error.getMessage());
        }
    }
}
