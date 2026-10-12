package vn.gomate.message.service;

import com.mongodb.MongoException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;
import vn.gomate.message.dto.MessageDtos;
import vn.gomate.message.model.MessageDocument;

@Service
public class MessageMongoService {
 private static final int DEFAULT_LIMIT=30;
 private static final int MAX_LIMIT=50;
 private final MongoTemplate mongo;

 public MessageMongoService(MongoTemplate mongo) {
  this.mongo=mongo;
 }

 public MessageDtos.MessageItem saveText(UUID conversationId,UUID senderUserId,String text,Map<String,Object> context) {
  try {
   var doc=new MessageDocument();
   doc.setMessageId(UUID.randomUUID().toString());
   doc.setConversationId(conversationId);
   doc.setSenderUserId(senderUserId);
   doc.setType("TEXT");
   doc.setText(text.trim());
   doc.setContext(context);
   doc.setCreatedAt(Instant.now());
   return item(mongo.save(doc));
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Không thể lưu tin nhắn lúc này. Vui lòng thử lại.",e);
  }
 }

 public List<MessageDtos.MessageItem> list(UUID conversationId,Integer limit,String before) {
  try {
   int safeLimit=safeLimit(limit);
   var criteria=Criteria.where("conversationId").is(conversationId);
   if(before!=null && !before.isBlank()) criteria=criteria.and("createdAt").lt(Instant.parse(before));
   var query=new Query(criteria)
    .with(Sort.by(Sort.Direction.DESC,"createdAt"))
    .limit(safeLimit);
   var rows=mongo.find(query,MessageDocument.class);
   return rows.stream().map(this::item).sorted(java.util.Comparator.comparing(MessageDtos.MessageItem::createdAt)).toList();
  } catch(IllegalArgumentException e) {
   throw ApiException.bad("Cursor tin nhắn không hợp lệ.");
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Không thể tải tin nhắn lúc này. Vui lòng thử lại.",e);
  }
 }

 public MessageDtos.MessageItem latest(UUID conversationId) {
  try {
   var query=new Query(Criteria.where("conversationId").is(conversationId))
    .with(Sort.by(Sort.Direction.DESC,"createdAt"))
    .limit(1);
   var doc=mongo.findOne(query,MessageDocument.class);
   return doc==null?null:item(doc);
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Không thể tải tin nhắn lúc này. Vui lòng thử lại.",e);
  }
 }

 public long unreadCount(UUID conversationId,UUID currentUserId,Instant after) {
  try {
   var criteria=Criteria.where("conversationId").is(conversationId).and("senderUserId").ne(currentUserId);
   if(after!=null) criteria=criteria.and("createdAt").gt(after);
   return mongo.count(new Query(criteria),MessageDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Không thể tải trạng thái tin nhắn lúc này. Vui lòng thử lại.",e);
  }
 }

 public long count(UUID conversationId) {
  try {
   return mongo.count(new Query(Criteria.where("conversationId").is(conversationId)),MessageDocument.class);
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Không thể tải tin nhắn lúc này. Vui lòng thử lại.",e);
  }
 }

 private MessageDtos.MessageItem item(MessageDocument doc) {
  return new MessageDtos.MessageItem(
   doc.getMessageId(),
   doc.getConversationId(),
   doc.getSenderUserId(),
   doc.getType(),
   doc.getText(),
   doc.getContext(),
   doc.getCreatedAt()
  );
 }

 private int safeLimit(Integer limit) {
  if(limit==null || limit<=0) return DEFAULT_LIMIT;
  return Math.min(limit,MAX_LIMIT);
 }
}
