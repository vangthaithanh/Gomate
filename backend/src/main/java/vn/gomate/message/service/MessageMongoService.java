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

 public MessageDtos.MessageItem savePostReference(UUID conversationId,UUID sender,long postId,UUID requestId,String targetKey,String text) {
  String id="post-share-"+UUID.nameUUIDFromBytes((sender+":"+requestId+":"+targetKey).getBytes(java.nio.charset.StandardCharsets.UTF_8));
  String hash=vn.gomate.social.post.PostService.digest((postId+":"+text).getBytes(java.nio.charset.StandardCharsets.UTF_8));
  try {
   var query=new Query(Criteria.where("_id").is(id));
   var update=new org.springframework.data.mongodb.core.query.Update()
    .setOnInsert("messageId",id).setOnInsert("conversationId",conversationId).setOnInsert("senderUserId",sender)
    .setOnInsert("type","POST_SHARE").setOnInsert("text",text)
    .setOnInsert("context",Map.of("postId",postId,"requestHash",hash)).setOnInsert("createdAt",Instant.now());
   MessageDocument doc;
   try {
    doc=mongo.findAndModify(query,update,org.springframework.data.mongodb.core.FindAndModifyOptions.options().upsert(true).returnNew(true),MessageDocument.class);
   } catch(org.springframework.dao.DuplicateKeyException e) {doc=mongo.findOne(query,MessageDocument.class);}
   if(doc==null) throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Chưa xác nhận được tin nhắn. Hãy thử lại.");
   if(!hash.equals(doc.getContext().get("requestHash")) || !conversationId.equals(doc.getConversationId()))
    throw new ApiException(409,"SHARE_REQUEST_CONFLICT","Mã gửi đã được dùng với nội dung khác.");
   return item(doc);
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Không thể lưu tin nhắn lúc này. Vui lòng thử lại.",e);
  }
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

 public static String textMessageId(UUID sender,UUID requestId,String scope) {
  return "dm-text-"+UUID.nameUUIDFromBytes((sender+":"+requestId+":"+scope).getBytes(java.nio.charset.StandardCharsets.UTF_8));
 }

 public static String shareMessageId(UUID sender,UUID requestId,String scope) {
  return "post-share-"+UUID.nameUUIDFromBytes((sender+":"+requestId+":"+scope).getBytes(java.nio.charset.StandardCharsets.UTF_8));
 }

 public MessageDtos.MessageItem saveText(UUID conversationId,UUID sender,String text,Map<String,Object> context,UUID requestId,String scope) {
  String id=textMessageId(sender,requestId,scope);
  try {
   String hash=textRequestHash(text,context);
   var query=new Query(Criteria.where("_id").is(id));
   var update=new org.springframework.data.mongodb.core.query.Update()
    .setOnInsert("messageId",id).setOnInsert("conversationId",conversationId).setOnInsert("senderUserId",sender)
    .setOnInsert("type","TEXT").setOnInsert("text",text).setOnInsert("context",context)
    .setOnInsert("requestHash",hash).setOnInsert("createdAt",Instant.now());
   MessageDocument doc;
   try {
    doc=mongo.findAndModify(query,update,org.springframework.data.mongodb.core.FindAndModifyOptions.options().upsert(true).returnNew(true),MessageDocument.class);
   } catch(org.springframework.dao.DuplicateKeyException e) {doc=mongo.findOne(query,MessageDocument.class);}
   if(doc==null) throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Chưa xác nhận được tin nhắn. Hãy thử lại.");
   if(!hash.equals(doc.getRequestHash()) || !conversationId.equals(doc.getConversationId()))
    throw new ApiException(409,"MESSAGE_REQUEST_CONFLICT","Mã gửi đã được dùng với nội dung khác.");
   return item(doc);
  } catch(DataAccessException|MongoException e) {
   throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Không thể lưu tin nhắn lúc này. Vui lòng thử lại.",e);
  }
 }

 // Only called under the pair lock when the old metadata never committed.
 public void rebindOrphan(String id,UUID conversationId,java.util.function.Predicate<UUID> metadataExists,String expectedHash) {
  var query=new Query(Criteria.where("_id").is(id));
  var doc=mongo.findOne(query,MessageDocument.class);
  if(doc!=null && !conversationId.equals(doc.getConversationId()) && !metadataExists.test(doc.getConversationId())) {
   Object hash="POST_SHARE".equals(doc.getType())?doc.getContext().get("requestHash"):doc.getRequestHash();
   if(!expectedHash.equals(hash)) throw new ApiException(409,"MESSAGE_REQUEST_CONFLICT","Mã gửi đã được dùng với nội dung khác.");
   mongo.updateFirst(new Query(Criteria.where("_id").is(id).and("conversationId").is(doc.getConversationId())),
    new org.springframework.data.mongodb.core.query.Update().set("conversationId",conversationId),MessageDocument.class);
  }
 }

 public static String textRequestHash(String text,Map<String,Object> context) {
  try {
   var mapper=new com.fasterxml.jackson.databind.ObjectMapper()
    .configure(com.fasterxml.jackson.databind.SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS,true);
   return vn.gomate.social.post.PostService.digest(mapper.writeValueAsBytes(java.util.Arrays.asList(text,context)));
  } catch(com.fasterxml.jackson.core.JsonProcessingException e) {throw ApiException.bad("Ngữ cảnh tin nhắn không hợp lệ.");}
 }

 public void removeUncommitted(String id,UUID conversationId,UUID sender) {
  mongo.remove(new Query(Criteria.where("_id").is(id).and("conversationId").is(conversationId).and("senderUserId").is(sender)),MessageDocument.class);
 }

 public boolean hasMessage(String id,UUID conversationId) {
  try {return mongo.exists(new Query(Criteria.where("_id").is(id).and("conversationId").is(conversationId)),MessageDocument.class);}
  catch(DataAccessException|MongoException e) {throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Chưa xác nhận được tin nhắn. Hãy thử lại.",e);}
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
   "POST_SHARE".equals(doc.getType())?Map.of("postId",doc.getContext().get("postId")):doc.getContext(),
   doc.getCreatedAt()
  );
 }

 private int safeLimit(Integer limit) {
  if(limit==null || limit<=0) return DEFAULT_LIMIT;
  return Math.min(limit,MAX_LIMIT);
 }
}
