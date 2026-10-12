package vn.gomate.message.config;

import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;
import vn.gomate.message.model.MessageDocument;

@Component
public class MessageMongoIndexConfig {
 private final MongoTemplate mongo;

 public MessageMongoIndexConfig(MongoTemplate mongo) {
  this.mongo=mongo;
 }

 @EventListener(ApplicationReadyEvent.class)
 public void ensureIndexes() {
  try {
   var ops=mongo.indexOps(MessageDocument.class);
   ops.ensureIndex(new Index().on("messageId",Sort.Direction.ASC).unique().named("ux_messages_message_id"));
   ops.ensureIndex(new Index().on("conversationId",Sort.Direction.ASC).on("createdAt",Sort.Direction.DESC).named("idx_messages_conversation_created"));
   ops.ensureIndex(new Index().on("senderUserId",Sort.Direction.ASC).on("createdAt",Sort.Direction.DESC).named("idx_messages_sender_created"));
  } catch(Exception e) {
   LoggerFactory.getLogger(MessageMongoIndexConfig.class).warn("Could not ensure MongoDB message indexes",e);
  }
 }
}
