package vn.gomate.message.service;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
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

 public ConversationService(ConversationRepository repo,TripRepository trips,MessageMongoService messages,InteractionEventService events) {
  this.repo=repo;
  this.trips=trips;
  this.messages=messages;
  this.events=events;
 }

 @Transactional
 public MessageDtos.ConversationSummary openDirect(UUID currentUserId,UUID targetUserId) {
  validateTarget(currentUserId,targetUserId);
  UUID low=low(currentUserId,targetUserId);
  UUID high=high(currentUserId,targetUserId);
  var existing=repo.directByPair(low,high);
  UUID conversationId;
  if(existing.isEmpty()) {
   conversationId=UUID.randomUUID();
   String status=repo.mutualFriend(currentUserId,targetUserId)?"ACCEPTED":"PENDING";
   repo.createDirect(conversationId,currentUserId,targetUserId,low,high,status);
  } else {
   conversationId=(UUID)existing.get().get("id");
   String status=(String)existing.get().get("status");
   if("REMOVED".equals(status) || "CLOSED".equals(status)) {
    String nextStatus=repo.mutualFriend(currentUserId,targetUserId)?"ACCEPTED":"PENDING";
    repo.reopenAsPending(conversationId,currentUserId,targetUserId,nextStatus);
   }
  }
  events.recordDirectConversationOpened(currentUserId,conversationId);
  return summary(conversationId,currentUserId);
 }

 public List<MessageDtos.ConversationSummary> listAccepted(UUID currentUserId,int page,int size) {
  var paging=paging(page,size);
  return repo.listAccepted(currentUserId,paging.size(),paging.offset()).stream()
   .map(row -> summary(row,currentUserId))
   .toList();
 }

 public List<MessageDtos.ConversationSummary> listPending(UUID currentUserId,int page,int size) {
  var paging=paging(page,size);
  return repo.listPendingForRecipient(currentUserId,paging.size(),paging.offset()).stream()
   .map(row -> summary(row,currentUserId))
   .toList();
 }

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

 public List<MessageDtos.MessageItem> listMessages(UUID conversationId,UUID currentUserId,Integer limit,String before) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  ensureGroupTripMembership(conversation,currentUserId);
  return messages.list(conversationId,limit,before);
 }

 @Transactional
 public MessageDtos.MessageItem sendText(UUID conversationId,UUID currentUserId,MessageDtos.SendTextRequest req) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  ensureGroupTripMembership(conversation,currentUserId);
  if(repo.anyBlocked(conversationId)) throw new ApiException(403,"CONVERSATION_BLOCKED","Đoạn chat đang bị chặn.");
  String status=(String)conversation.get("status");
  if(!"ACCEPTED".equals(status) && !"PENDING".equals(status)) throw new ApiException(403,"CONVERSATION_NOT_ACTIVE","Đoạn chat không còn hoạt động.");
  if("PENDING".equals(status) && !currentUserId.equals((UUID)conversation.get("requesterId"))) {
   throw new ApiException(403,"PENDING_REQUEST_NOT_ACCEPTED","Hãy chấp nhận tin nhắn trước khi trả lời.");
  }
  String text=req.text().trim();
  if(text.isEmpty()) throw ApiException.bad("Nội dung tin nhắn không được để trống.");
  var saved=messages.saveText(conversationId,currentUserId,text,req.context());
  repo.touch(conversationId);
  events.recordMessageSent(currentUserId,conversationId);
  return saved;
 }

 @Transactional
 public MessageDtos.ConversationSummary renameGroup(UUID conversationId,UUID currentUserId,MessageDtos.RenameConversationRequest req) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
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
   (String)current.get("status"),
   (String)current.get("timezone")
  );
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public MessageDtos.ConversationSummary accept(UUID conversationId,UUID currentUserId) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  if("ACCEPTED".equals(conversation.get("status"))) return summary(conversationId,currentUserId);
  if(!"PENDING".equals(conversation.get("status"))) throw new ApiException(422,"REQUEST_NOT_PENDING","Tin nhắn chờ không còn ở trạng thái chờ.");
  if(!currentUserId.equals((UUID)conversation.get("recipientId"))) {
   throw new ApiException(403,"ONLY_RECIPIENT_CAN_ACCEPT","Chỉ người nhận mới có thể chấp nhận tin nhắn chờ.");
  }
  repo.accept(conversationId);
  repo.markRead(conversationId,currentUserId);
  events.recordMessageRequestAccepted(currentUserId,conversationId);
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public void deletePending(UUID conversationId,UUID currentUserId) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  if(!"PENDING".equals(conversation.get("status"))) throw new ApiException(422,"REQUEST_NOT_PENDING","Chỉ có thể xoá tin nhắn đang chờ.");
  if(!currentUserId.equals((UUID)conversation.get("recipientId"))) {
   throw new ApiException(403,"ONLY_RECIPIENT_CAN_DELETE","Chỉ người nhận mới có thể xoá tin nhắn chờ.");
  }
  repo.removePending(conversationId);
 }

 @Transactional
 public MessageDtos.ConversationSummary markRead(UUID conversationId,UUID currentUserId) {
  ensureParticipant(conversationId,currentUserId);
  repo.markRead(conversationId,currentUserId);
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public MessageDtos.ConversationSummary setMuted(UUID conversationId,UUID currentUserId,boolean muted) {
  ensureParticipant(conversationId,currentUserId);
  repo.setMuted(conversationId,currentUserId,muted);
  return summary(conversationId,currentUserId);
 }

 @Transactional
 public MessageDtos.ConversationSummary setBlocked(UUID conversationId,UUID currentUserId,boolean blocked) {
  var conversation=conversation(conversationId);
  ensureParticipant(conversationId,currentUserId);
  if(!"DIRECT".equals(conversation.get("type"))) throw ApiException.bad("Chỉ hỗ trợ block direct message trong V1.");
  repo.setBlocked(conversationId,currentUserId,blocked);
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
    (String)row.get("peerCity"),
    (String)row.get("peerBio")
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
  if(tripId==null || !trips.isActiveMember(tripId,currentUserId)) throw ApiException.notFound();
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
