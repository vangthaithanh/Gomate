package vn.gomate.message.service;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.event.service.InteractionEventService;
import vn.gomate.message.dto.MessageDtos;
import vn.gomate.message.repository.ConversationRepository;
import vn.gomate.trip.repository.TripRepository;

@Service
public class ConversationService {
 private static final int DEFAULT_SIZE=20;
 private static final int MAX_SIZE=50;

 private final ConversationRepository repo;
 private final TripRepository trips;
 private final MessageMongoService messages;
 private final InteractionEventService events;
 private final vn.gomate.social.post.PostService posts;
 private final vn.gomate.user.service.UserService users;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;
 private final vn.gomate.relationship.block.GlobalBlockService globalBlocks;
 private final org.springframework.transaction.support.TransactionTemplate transactions;

 public ConversationService(ConversationRepository repo,TripRepository trips,MessageMongoService messages,InteractionEventService events,vn.gomate.social.post.PostService posts,vn.gomate.user.service.UserService users,org.springframework.transaction.PlatformTransactionManager manager,vn.gomate.relationship.block.GlobalBlockPolicy blocks,vn.gomate.relationship.block.GlobalBlockService globalBlocks) {
  this.repo=repo;
  this.trips=trips;
  this.messages=messages;
  this.events=events;
  this.posts=posts;
  this.users=users;
  this.blocks=blocks;this.globalBlocks=globalBlocks;
  this.transactions=new org.springframework.transaction.support.TransactionTemplate(manager);
  this.transactions.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
 }

 @Transactional
 public List<Map<String,Object>> shareTargets(UUID viewer,long postId,String query) {
  posts.authorize(viewer,postId);
  var result=new java.util.ArrayList<Map<String,Object>>();
  for(var row:repo.shareCandidates(viewer,vn.gomate.common.SearchText.query(query))) try {
   shareTarget(viewer,(String)row.get("type"),(UUID)row.get("targetId"),postId,false);
   result.add(row);
  } catch(ApiException e) {if(e.status!=403 && e.status!=404) throw e;}
  return result;
 }

 @Transactional
 public void preparePostShare(UUID viewer,long postId,String type,UUID targetId) {
  posts.authorize(viewer,postId);
  shareTarget(viewer,type,targetId,postId,false);
 }

 public MessageDtos.MessageItem sharePost(UUID viewer,long postId,String type,UUID targetId,UUID requestId,String text) {
  UUID candidate=stableConversation(viewer,requestId,"share:"+type+":"+targetId);
  String key=MessageMongoService.shareMessageId(viewer,requestId,type+":"+targetId);
  boolean[] created={false};
  return sendTransaction(viewer,targetId,candidate,key,created,() -> {
   // Serialize source-Post permission with Block even for GROUP reference sends.
   // Lock all user settings in one order before acquiring any chat row.
   posts.lockShareInteraction(viewer,postId,"USER".equals(type)?targetId:null);
   if("USER".equals(type)) repo.lockDirectPair(viewer,targetId);
   posts.authorize(viewer,postId);
   UUID id=shareTarget(viewer,type,targetId,postId,false);
   if(id==null) {
    id=candidate;
    created[0]=true;
    repo.createDirect(id,viewer,targetId,low(viewer,targetId),high(viewer,targetId),"ACCEPTED");
   }
   repo.touch(id);
   messages.rebindOrphan(key,id,old -> repo.conversation(old).isPresent(),vn.gomate.social.post.PostService.digest((postId+":"+text).getBytes(java.nio.charset.StandardCharsets.UTF_8)));
   return messages.savePostReference(id,viewer,postId,requestId,type+":"+targetId,text);
  });
 }

 private UUID shareTarget(UUID viewer,String type,UUID targetId,long postId,boolean create) {
  if("GROUP".equals(type)) {
   var group=conversation(targetId);
   if(!"GROUP".equals(group.get("type")) || !"ACCEPTED".equals(group.get("status"))) throw ApiException.notFound();
   ensureParticipant(targetId,viewer);
   ensureGroupTripMembership(group,viewer);
   if(repo.anyBlocked(targetId)) throw ApiException.denied();
   // Approved P4 rule: group receives an ID only; every reader rechecks Post/media access.
   return targetId;
  }
  if(!"USER".equals(type) || viewer.equals(targetId) || !repo.activeUser(targetId)) throw ApiException.notFound();
  blocks.requireAllowed(viewer,targetId);
  // DM and GROUP both carry an ID only; each recipient rechecks access on open.
  var direct=repo.directByPair(low(viewer,targetId),high(viewer,targetId));
  if(direct.isPresent()) {
   UUID id=(UUID)direct.get().get("id");
   if(!"ACCEPTED".equals(direct.get().get("status")) || !repo.participant(id,viewer) || !repo.participant(id,targetId) || repo.anyBlocked(id)) throw ApiException.denied();
   return id;
  }
  if(!repo.mutualFriend(viewer,targetId)) throw ApiException.denied();
  return null;
 }

 @Transactional
 public MessageDtos.ConversationSummary openDirect(UUID currentUserId,UUID targetUserId) {
  validateTarget(currentUserId,targetUserId);
  requireInitiation(currentUserId,targetUserId);
  var existing=repo.directByPair(low(currentUserId,targetUserId),high(currentUserId,targetUserId));
  if(existing.isPresent() && Set.of("PENDING","ACCEPTED").contains(existing.get().get("status")))
   return summary((UUID)existing.get().get("id"),currentUserId);
  var profile=users.publicProfile(currentUserId,targetUserId);
  return new MessageDtos.ConversationSummary(null,"DIRECT","DRAFT",null,profile.displayName(),
   new MessageDtos.Peer(targetUserId,profile.nickname(),profile.displayName(),profile.avatarUrl(),profile.city(),profile.bio()),
   List.of(),2,true,false,false,false,false,0,null,null,null);
 }

 public MessageDtos.DirectSendResult sendDirect(UUID viewer,MessageDtos.DirectSendRequest req) {
  validateTarget(viewer,req.targetUserId());
  if(req.clientRequestId()==null) throw ApiException.bad("Thiếu mã gửi tin nhắn.");
  String text=cleanText(req.text());
  UUID target=req.targetUserId(),candidate=stableConversation(viewer,req.clientRequestId(),"text:"+target);
  String scope="DIRECT:"+target,key=MessageMongoService.textMessageId(viewer,req.clientRequestId(),scope);
  boolean[] created={false};
  return sendTransaction(viewer,target,candidate,key,created,() -> {
   repo.lockDirectPair(viewer,target);
   validateTarget(viewer,target);
   var existing=repo.directByPair(low(viewer,target),high(viewer,target));
   UUID id;
   if(existing.isEmpty()) {
    requireInitiation(viewer,target);
    id=candidate;
    created[0]=true;
    repo.createDirect(id,viewer,target,low(viewer,target),high(viewer,target),repo.mutualFriend(viewer,target)?"ACCEPTED":"PENDING");
   } else {
    id=(UUID)existing.get().get("id");
    repo.lockConversation(id);
    if(Set.of("REMOVED","CLOSED").contains(existing.get().get("status"))) {
     requireInitiation(viewer,target);
     if(messages.hasMessage(key,id)) throw new ApiException(409,"MESSAGE_REQUEST_RESOLVED","Lần gửi này đã được xử lý. Hãy gửi một tin nhắn mới.");
     if(repo.anyBlocked(id)) throw ApiException.denied();
     repo.reopenAsPending(id,viewer,target,repo.mutualFriend(viewer,target)?"ACCEPTED":"PENDING");
    }
   }
   ensureCanSend(id,viewer);
   repo.touch(id);
   messages.rebindOrphan(key,id,old -> repo.conversation(old).isPresent(),MessageMongoService.textRequestHash(text,req.context()));
   var message=messages.saveText(id,viewer,text,req.context(),req.clientRequestId(),scope);
   events.recordMessageSent(viewer,id);
   return new MessageDtos.DirectSendResult(summary(id,viewer),message);
  });
 }

 private <T> T sendTransaction(UUID viewer,UUID target,UUID candidate,String messageKey,boolean[] created,java.util.function.Supplier<T> action) {
  try {return transactions.execute(tx -> action.get());}
  catch(RuntimeException failure) {
   if(created[0]) try {
    // Covers rollback AND commit failure. A concurrent retry is protected by the same pair lock.
    transactions.executeWithoutResult(tx -> {
     repo.lockDirectPair(viewer,target);
     if(repo.conversation(candidate).isEmpty()) messages.removeUncommitted(messageKey,candidate,viewer);
    });
   } catch(RuntimeException cleanup) {
    org.slf4j.LoggerFactory.getLogger(ConversationService.class).warn("DM compensation requires retry: conversation={}, message={}",candidate,messageKey);
   }
   if(failure instanceof org.springframework.dao.DataAccessException || failure instanceof com.mongodb.MongoException)
    throw new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Chưa xác nhận được tin nhắn. Hãy thử lại.",failure);
   throw failure;
  }
 }

 private UUID stableConversation(UUID sender,UUID requestId,String scope) {
  return UUID.nameUUIDFromBytes(("gomate-dm:"+sender+":"+requestId+":"+scope).getBytes(java.nio.charset.StandardCharsets.UTF_8));
 }

 private void requireInitiation(UUID viewer,UUID target) {
  blocks.requireAllowed(viewer,target);
  if(!users.canInitiateMessage(viewer,target)) throw new ApiException(403,"DM_INITIATION_NOT_ALLOWED","Bạn chưa được phép bắt đầu nhắn tin với tài khoản này.");
 }

 private String cleanText(String text) {
  if(text==null || text.trim().isEmpty() || text.length()>4000) throw ApiException.bad("Tin nhắn cần có nội dung và tối đa 4.000 ký tự.");
  return text.trim();
 }

 private Map<String,Object> lockDirect(UUID id) {
  var row=conversation(id);
  if("DIRECT".equals(row.get("type"))) {
   repo.lockDirectPair((UUID)row.get("userLowId"),(UUID)row.get("userHighId"));
   repo.lockConversation(id);
   row=conversation(id);
  }
  return row;
 }

 private void ensureCanSend(UUID id,UUID viewer) {
  var row=conversation(id);
  ensureParticipant(id,viewer);
  if("DIRECT".equals(row.get("type")) && (!repo.activeUser((UUID)row.get("userLowId")) || !repo.activeUser((UUID)row.get("userHighId")))) throw ApiException.notFound();
  ensureGroupTripMembership(row,viewer);
  if(repo.anyBlocked(id)) throw new ApiException(403,"CONVERSATION_BLOCKED","Đoạn chat đang bị chặn.");
  if(!Set.of("ACCEPTED","PENDING").contains(row.get("status"))) throw new ApiException(403,"CONVERSATION_NOT_ACTIVE","Đoạn chat không còn hoạt động.");
  if("PENDING".equals(row.get("status")) && !viewer.equals(row.get("requesterId")))
   throw new ApiException(403,"PENDING_REQUEST_NOT_ACCEPTED","Hãy chấp nhận tin nhắn trước khi trả lời.");
 }

 public List<MessageDtos.ConversationSummary> listAccepted(UUID currentUserId,int page,int size) {
  var paging=paging(page,size);
  return repo.listAccepted(currentUserId,paging.size(),paging.offset()).stream()
   .map(row -> summary(row,currentUserId))
   .toList();
 }

 public List<Map<String,Object>> blockedGroupMembers(UUID id,UUID viewer) {
  var group=conversation(id);
  ensureParticipant(id,viewer);ensureGroupTripMembership(group,viewer);
  if(!"GROUP".equals(group.get("type"))) throw ApiException.notFound();
  var members=repo.members(id,viewer);
  var own=blocks.ownBlocked(viewer,members.stream().map(r->(UUID)r.get("userId")).toList());
  return members.stream().filter(r -> own.contains((UUID)r.get("userId"))).map(r -> {
   var item=new java.util.LinkedHashMap<String,Object>();
   item.put("userId",r.get("userId"));item.put("displayName",r.get("fullName")==null?r.get("nickname"):r.get("fullName"));item.put("avatarUrl",r.get("avatarUrl"));return (Map<String,Object>)item;
  }).toList();
 }

 public List<MessageDtos.ConversationSummary> listPending(UUID currentUserId,int page,int size) {
  var paging=paging(page,size);
  return repo.listPendingForRecipient(currentUserId,paging.size(),paging.offset()).stream()
   .map(row -> summary(row,currentUserId))
   .toList();
 }

 @Transactional
 public MessageDtos.ConversationDetail detail(UUID conversationId,UUID currentUserId,Integer limit,String before) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  ensureGroupTripMembership(conversation,currentUserId);
  var items=messages.list(conversationId,limit,before);
  boolean hasMore=items.size()==safeLimit(limit) && messages.count(conversationId)>items.size();
  return new MessageDtos.ConversationDetail(
   summary(conversationId,currentUserId),
   items,
   new MessageDtos.Page(safeLimit(limit),before,hasMore)
  );
 }

 @Transactional
 public List<MessageDtos.MessageItem> listMessages(UUID conversationId,UUID currentUserId,Integer limit,String before) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  ensureGroupTripMembership(conversation,currentUserId);
  return messages.list(conversationId,limit,before);
 }

 @Transactional
 public MessageDtos.MessageItem sendText(UUID conversationId,UUID currentUserId,MessageDtos.SendTextRequest req) {
  ensureParticipant(conversationId,currentUserId);
  lockDirect(conversationId);
  ensureCanSend(conversationId,currentUserId);
  String text=cleanText(req.text());
  repo.touch(conversationId);
  var saved=req.clientRequestId()==null?messages.saveText(conversationId,currentUserId,text,req.context()):
   messages.saveText(conversationId,currentUserId,text,req.context(),req.clientRequestId(),"CHAT:"+conversationId);
  events.recordMessageSent(currentUserId,conversationId);
  return saved;
 }

 @Transactional
 public MessageDtos.ConversationSummary renameGroup(UUID conversationId,UUID currentUserId,MessageDtos.RenameConversationRequest req) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  ensureGroupTripMembership(conversation,currentUserId);
  if(!"GROUP".equals(conversation.get("type"))) throw ApiException.bad("Chỉ hỗ trợ đổi tên nhóm chat.");
  UUID tripId=(UUID)conversation.get("linkedTripId");
  if(tripId==null) throw ApiException.notFound();
  if(!trips.isActiveLeader(tripId,currentUserId)) throw ApiException.denied();
  var current=trips.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  String title=cleanTitle(req.name());
  trips.updateTrip(
   tripId,
   title,
   (String)current.get("description"),
   (java.time.LocalDate)current.get("startDate"),
   (java.time.LocalDate)current.get("endDate"),
   (String)current.get("timezone")
  );
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public MessageDtos.ConversationSummary accept(UUID conversationId,UUID currentUserId) {
  ensureParticipant(conversationId,currentUserId);
  var conversation=lockDirect(conversationId);
  if(!"DIRECT".equals(conversation.get("type")) || !currentUserId.equals((UUID)conversation.get("recipientId"))) {
   throw new ApiException(403,"ONLY_RECIPIENT_CAN_ACCEPT","Chỉ người nhận mới có thể chấp nhận tin nhắn chờ.");
  }
  if("ACCEPTED".equals(conversation.get("status"))) return summary(conversationId,currentUserId);
  if(!"PENDING".equals(conversation.get("status"))) throw new ApiException(422,"REQUEST_NOT_PENDING","Tin nhắn chờ không còn ở trạng thái chờ.");
  if(repo.anyBlocked(conversationId)) throw ApiException.denied();
  repo.accept(conversationId);
  repo.markRead(conversationId,currentUserId);
  events.recordMessageRequestAccepted(currentUserId,conversationId);
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public void deletePending(UUID conversationId,UUID currentUserId) {
  ensureParticipant(conversationId,currentUserId);
  var conversation=lockDirect(conversationId);
  if(!"DIRECT".equals(conversation.get("type")) || !currentUserId.equals((UUID)conversation.get("recipientId"))) {
   throw new ApiException(403,"ONLY_RECIPIENT_CAN_DELETE","Chỉ người nhận mới có thể xoá tin nhắn chờ.");
  }
  if("REMOVED".equals(conversation.get("status"))) return;
  if(!"PENDING".equals(conversation.get("status"))) throw new ApiException(422,"REQUEST_NOT_PENDING","Chỉ có thể xoá tin nhắn đang chờ.");
  repo.removePending(conversationId);
 }

 @Transactional
 public MessageDtos.ConversationSummary markRead(UUID conversationId,UUID currentUserId) {
  ensureParticipant(conversationId,currentUserId);
  ensureGroupTripMembership(conversation(conversationId),currentUserId);
  repo.markRead(conversationId,currentUserId);
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public MessageDtos.ConversationSummary setMuted(UUID conversationId,UUID currentUserId,boolean muted) {
  ensureParticipant(conversationId,currentUserId);
  ensureGroupTripMembership(conversation(conversationId),currentUserId);
  repo.setMuted(conversationId,currentUserId,muted);
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public MessageDtos.ConversationSummary setBlocked(UUID conversationId,UUID currentUserId,boolean blocked) {
  ensureParticipant(conversationId,currentUserId);
  var conversation=lockDirect(conversationId);
  if(!"DIRECT".equals(conversation.get("type"))) throw ApiException.bad("Chỉ hỗ trợ block direct message trong V1.");
  UUID target=currentUserId.equals(conversation.get("userLowId"))?(UUID)conversation.get("userHighId"):(UUID)conversation.get("userLowId");
  globalBlocks.set(currentUserId,target,blocked);
  if(blocked) events.recordUserBlockedInMessage(currentUserId,conversationId);
  return summary(conversationId,currentUserId);
 }

 private MessageDtos.ConversationSummary summary(UUID conversationId,UUID currentUserId) {
  return summary(repo.summaryRow(conversationId,currentUserId),currentUserId);
 }

  private MessageDtos.ConversationSummary summary(Map<String,Object> row,UUID currentUserId) {
  UUID conversationId=(UUID)row.get("id");
  String type=(String)row.get("type");
  MessageDtos.MessageItem latest=safeLatest(conversationId);
  Instant lastReadAt=instant(row.get("lastReadAt"));
  long unread=safeUnreadCount(conversationId,currentUserId,lastReadAt);
  String displayName;
  MessageDtos.Peer peer=null;
  if("GROUP".equals(type)) {
   displayName=(String)row.get("groupTitle");
   if(displayName==null || displayName.isBlank()) displayName=(String)row.get("title");
  } else {
   displayName=(String)row.get("peerFullName");
   if(displayName==null || displayName.isBlank()) displayName=(String)row.get("peerNickname");
   peer=new MessageDtos.Peer(
    (UUID)row.get("peerUserId"),
    (String)row.get("peerNickname"),
    displayName,
    (String)row.get("peerAvatarUrl"),
    blocks.either(currentUserId,(UUID)row.get("peerUserId"))?null:(String)row.get("peerCity"),
    blocks.either(currentUserId,(UUID)row.get("peerUserId"))?null:(String)row.get("peerBio")
   );
  }
  return new MessageDtos.ConversationSummary(
   conversationId,
   type,
   (String)row.get("status"),
   (UUID)row.get("linkedTripId"),
   displayName,
   peer,
   "GROUP".equals(type)?repo.members(conversationId,currentUserId).stream().map(rowMember -> member(rowMember,currentUserId)).toList():List.of(),
   asInteger(row.get("memberCount")),
   currentUserId.equals((UUID)row.get("requesterId")),
   currentUserId.equals((UUID)row.get("recipientId")),
   Boolean.TRUE.equals(row.get("muted")),
   Boolean.TRUE.equals(row.get("blockedByMe")),
   Boolean.TRUE.equals(row.get("blockedByPeer")),
   unread,
   latest,
   repo.localDateTime(row.get("createdAt")),
   repo.localDateTime(row.get("updatedAt"))
  );
 }

 private MessageDtos.Member member(Map<String,Object> row,UUID currentUserId) {
  String displayName=(String)row.get("fullName");
  if(displayName==null || displayName.isBlank()) displayName=(String)row.get("nickname");
  return new MessageDtos.Member(
   (UUID)row.get("userId"),
   displayName,
   (String)row.get("avatarUrl"),
   (String)row.get("role"),
   currentUserId.equals((UUID)row.get("userId"))
  );
 }

 private MessageDtos.MessageItem safeLatest(UUID conversationId) {
  try {
   return messages.latest(conversationId);
  } catch(ApiException e) {
   if(e.status==503) return null;
   throw e;
  }
 }

 private long safeUnreadCount(UUID conversationId,UUID currentUserId,Instant lastReadAt) {
  try {
   return messages.unreadCount(conversationId,currentUserId,lastReadAt);
  } catch(ApiException e) {
   if(e.status==503) return 0;
   throw e;
  }
 }

 private void validateTarget(UUID currentUserId,UUID targetUserId) {
  if(targetUserId==null) throw ApiException.bad("Thiếu người nhận.");
  if(currentUserId.equals(targetUserId)) throw ApiException.bad("Không thể mở hội thoại với chính mình.");
  if(!repo.activeUser(targetUserId)) throw new ApiException(404,"USER_NOT_FOUND","Không tìm thấy người dùng.");
 }

 private Map<String,Object> conversation(UUID conversationId) {
  return repo.conversation(conversationId).orElseThrow(ApiException::notFound);
 }

 private void ensureParticipant(UUID conversationId,UUID currentUserId) {
  if(!repo.participant(conversationId,currentUserId)) throw ApiException.notFound();
 }

 private void ensureGroupTripMembership(Map<String,Object> conversation,UUID currentUserId) {
  if(!"GROUP".equals(conversation.get("type"))) return;
  UUID tripId=(UUID)conversation.get("linkedTripId");
  if(tripId==null) throw ApiException.notFound();
  // Serialize group access with leave/remove; DIRECT behavior is unchanged.
  var trip=trips.tripForUpdate(tripId).orElseThrow(ApiException::notFound);
  if(!"GROUP".equals(trip.get("tripType")) || !trips.isActiveMember(tripId,currentUserId)
   || !trips.groupConversationId(tripId).filter(conversation.get("id")::equals).isPresent()) {
   throw ApiException.notFound();
  }
 }

 private UUID low(UUID a,UUID b) {
  return a.compareTo(b)<0?a:b;
 }

 private UUID high(UUID a,UUID b) {
  return a.compareTo(b)<0?b:a;
 }

 private Paging paging(int page,int size) {
  int safePage=Math.max(0,page);
  int safeSize=size<=0?DEFAULT_SIZE:Math.min(size,MAX_SIZE);
  return new Paging(safePage,safeSize,safePage*safeSize);
 }

 private int safeLimit(Integer limit) {
  if(limit==null || limit<=0) return 30;
  return Math.min(limit,50);
 }

 private Instant instant(Object value) {
  if(value==null) return null;
  if(value instanceof Instant instant) return instant;
  if(value instanceof LocalDateTime localDateTime) return localDateTime.toInstant(ZoneOffset.UTC);
  if(value instanceof java.sql.Timestamp timestamp) return timestamp.toInstant();
  if(value instanceof java.time.OffsetDateTime offsetDateTime) return offsetDateTime.toInstant();
  return null;
 }

 private Integer asInteger(Object value) {
  if(value==null) return null;
  if(value instanceof Number number) return number.intValue();
  return Integer.valueOf(value.toString());
 }

 private String cleanTitle(String value) {
  String title=value==null?"":value.trim();
  if(title.isEmpty()) throw ApiException.bad("Tên nhóm không được để trống.");
  return title;
 }

 private record Paging(int page,int size,int offset) {}
}
