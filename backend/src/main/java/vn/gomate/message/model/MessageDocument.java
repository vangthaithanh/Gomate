package vn.gomate.message.model;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("messages")
public class MessageDocument {
 @Id
 private String id;
 private String messageId;
 private UUID conversationId;
 private UUID senderUserId;
 private String type;
 private String text;
 private Map<String,Object> context;
 private Instant createdAt;

 public String getId() { return id; }
 public void setId(String id) { this.id=id; }
 public String getMessageId() { return messageId; }
 public void setMessageId(String messageId) { this.messageId=messageId; }
 public UUID getConversationId() { return conversationId; }
 public void setConversationId(UUID conversationId) { this.conversationId=conversationId; }
 public UUID getSenderUserId() { return senderUserId; }
 public void setSenderUserId(UUID senderUserId) { this.senderUserId=senderUserId; }
 public String getType() { return type; }
 public void setType(String type) { this.type=type; }
 public String getText() { return text; }
 public void setText(String text) { this.text=text; }
 public Map<String,Object> getContext() { return context; }
 public void setContext(Map<String,Object> context) { this.context=context; }
 public Instant getCreatedAt() { return createdAt; }
 public void setCreatedAt(Instant createdAt) { this.createdAt=createdAt; }
}
