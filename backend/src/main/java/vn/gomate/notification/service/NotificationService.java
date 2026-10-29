package vn.gomate.notification.service;

import java.time.*;
import java.util.Map;
import java.util.UUID;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.notification.dto.NotificationDtos;
import vn.gomate.notification.repository.NotificationRepository;
import vn.gomate.notification.realtime.NotificationEventPublisher;

@Service
public class NotificationService {
 private final NotificationRepository repo;
 private final NotificationEventPublisher events;
 private final ObjectMapper json;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;
 public NotificationService(NotificationRepository repo,NotificationEventPublisher events,ObjectMapper json,vn.gomate.relationship.block.GlobalBlockPolicy blocks) { this.repo=repo; this.events=events; this.json=json; this.blocks=blocks; }

 @Transactional
 public void recordPostInteraction(UUID recipient,UUID actor,long post,Long comment,boolean reply) {
  if(recipient==null || recipient.equals(actor)) return;
  if(blocks.either(recipient,actor)) return;
  String type=comment==null?"POST_LIKE":reply?"POST_REPLY":"POST_COMMENT";
  String event=comment==null?post+":"+actor:comment.toString();
  String body=comment==null?"đã thích bài viết của bạn":reply?"đã trả lời bình luận của bạn":"đã bình luận về bài viết của bạn";
  String data;
  try { data=json.writeValueAsString(comment==null?Map.of("postId",post):Map.of("postId",post,"commentId",comment)); }
  catch(Exception failure) { throw new IllegalStateException(failure); }
  UUID id=repo.insertPostInteraction(recipient,actor,type,comment==null?"POST_LIKE":"POST_COMMENT",event,body,data);
  if(id!=null) events.changed(recipient,id,"CREATED");
 }

 @Transactional
 public void recordTripInvitation(UUID recipientId,UUID actorId,UUID invitationId,boolean accepted) {
  UUID id=repo.insertTripInvitation(recipientId,actorId,invitationId,accepted);
  if(id!=null) events.changed(recipientId,id,"CREATED");
 }

 @Transactional
 public void invitationStateChanged(UUID invitationId) {
  for(var row:repo.forInvitation(invitationId)) {
   events.changed((UUID)row.get("userId"),(UUID)row.get("id"),"UPDATED");
  }
 }

 @Transactional
 public void recordTripDateReminder(UUID recipientId,UUID reminderId,String title,int days,LocalDate start) {
  UUID id=repo.insertTripDateReminder(recipientId,reminderId,title,days,start);
  if(id!=null) events.changed(recipientId,id,"CREATED");
 }

 public NotificationDtos.Page list(UUID userId,int page,int size) {
  int safePage=Math.min(Math.max(0,page),100000);
  int safeSize=Math.min(Math.max(1,size),50);
  return new NotificationDtos.Page(repo.list(userId,safeSize,safePage*safeSize).stream().map(this::item).toList(),
   safePage,safeSize,repo.count(userId,false),repo.count(userId,true));
 }

 public NotificationDtos.Item detail(UUID userId,UUID id) {
  return repo.byId(userId,id).map(this::item).orElseThrow(ApiException::notFound);
 }

 @Transactional
 public NotificationDtos.Item markRead(UUID userId,UUID id) {
  if(repo.markRead(userId,id)==0) throw ApiException.notFound();
  events.changed(userId,id,"UPDATED");
  return detail(userId,id);
 }

 @Transactional
 public void markAllRead(UUID userId) {
  repo.markAllRead(userId);
  events.changed(userId,null,"INBOX_INVALIDATED");
 }

 private Instant instant(Object value) {
  if(value instanceof Instant t) return t;
  if(value instanceof OffsetDateTime t) return t.toInstant();
  return ((LocalDateTime)value).toInstant(ZoneOffset.UTC);
 }

 private NotificationDtos.Item item(Map<String,Object> row) {
  Object time=row.get("occurredAt");
  Instant instant=time instanceof OffsetDateTime offset?offset.toInstant():((LocalDateTime)time).toInstant(ZoneOffset.UTC);
  return new NotificationDtos.Item((UUID)row.get("id"),(String)row.get("type"),(UUID)row.get("actorId"),
   (String)row.get("actorName"),(String)row.get("avatarUrl"),(String)row.get("message"),
   Boolean.TRUE.equals(row.get("isRead")),instant,(UUID)row.get("invitationId"),
   (String)row.get("invitationStatus"),(UUID)row.get("tripId"),(String)row.get("tripName"),
   (UUID)row.get("reminderId"),row.get("reminderOffsetMinutes")==null?null:((Number)row.get("reminderOffsetMinutes")).intValue(),
   row.get("plannedStartAt")==null?null:instant(row.get("plannedStartAt")),dataId(row,"postId"),dataId(row,"commentId"),
   row.get("reminderDaysBefore")==null?null:((Number)row.get("reminderDaysBefore")).intValue(),
   (LocalDate)row.get("tripStartDate"),(LocalDate)row.get("reminderDate"),(String)row.get("reminderTimezone"));
 }

 private Long dataId(Map<String,Object> row,String key) {
  if(!java.util.Set.of("POST_LIKE","POST_COMMENT","POST_REPLY").contains(row.get("type")) || row.get("data")==null) return null;
  try {
   Object raw=row.get("data");
   var node=raw instanceof byte[] bytes?json.readTree(bytes):json.readTree(raw.toString());
   // H2 JSONB compatibility can return the bound JSON as a JSON string.
   if(node.isTextual()) node=json.readTree(node.asText());
   var value=node.get(key);
   return value!=null && value.isIntegralNumber() && value.canConvertToLong() && value.longValue()>0?value.longValue():null;
  } catch(Exception invalid) { return null; }
 }
}
