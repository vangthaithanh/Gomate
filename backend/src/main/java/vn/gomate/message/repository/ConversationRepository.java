package vn.gomate.message.repository;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class ConversationRepository {
 private final Db db;

 public ConversationRepository(Db db) {
  this.db=db;
 }

 public Optional<Map<String,Object>> directByPair(UUID lowUserId,UUID highUserId) {
  return db.list("""
   SELECT * FROM conversations
   WHERE type='DIRECT' AND user_low_id=:lowUserId AND user_high_id=:highUserId
   """,args("lowUserId",lowUserId,"highUserId",highUserId)).stream().findFirst();
 }

 public Optional<Map<String,Object>> conversation(UUID conversationId) {
  return db.list("SELECT * FROM conversations WHERE id=:conversationId",args("conversationId",conversationId)).stream().findFirst();
 }

 public boolean activeUser(UUID userId) {
  return db.count("SELECT COUNT(*) FROM users WHERE id=:userId AND status='ACTIVE'",args("userId",userId))==1;
 }

 public boolean mutualFriend(UUID userA,UUID userB) {
  return db.count("""
   SELECT COUNT(*)
   FROM user_follows a
   JOIN user_follows b ON b.follower_user_id=:userB AND b.followed_user_id=:userA
   WHERE a.follower_user_id=:userA AND a.followed_user_id=:userB
   """,args("userA",userA,"userB",userB))==1;
 }

 public void createDirect(UUID conversationId,UUID actorId,UUID targetId,UUID lowUserId,UUID highUserId,String status) {
  db.update("""
   INSERT INTO conversations(id,type,status,created_by,requester_id,recipient_id,user_low_id,user_high_id,accepted_at)
   VALUES(:conversationId,'DIRECT',:status,:actorId,:actorId,:targetId,:lowUserId,:highUserId,
    CASE WHEN :status='ACCEPTED' THEN CURRENT_TIMESTAMP ELSE NULL END)
   """,args("conversationId",conversationId,"status",status,"actorId",actorId,"targetId",targetId,"lowUserId",lowUserId,"highUserId",highUserId));
  addMember(conversationId,actorId);
  addMember(conversationId,targetId);
 }

 public void createGroupForTrip(UUID conversationId,UUID tripId,UUID creatorId) {
  db.update("""
   INSERT INTO conversations(id,type,status,created_by,linked_trip_id)
   VALUES(:conversationId,'GROUP','ACCEPTED',:creatorId,:tripId)
   """,args("conversationId",conversationId,"creatorId",creatorId,"tripId",tripId));
 }

 public void addMember(UUID conversationId,UUID userId) {
  addMember(conversationId,userId,"MEMBER");
 }

 public void addMember(UUID conversationId,UUID userId,String role) {
  db.update("""
   INSERT INTO conversation_members(conversation_id,user_id,role)
   VALUES(:conversationId,:userId,:role)
   """,args("conversationId",conversationId,"userId",userId,"role",role));
 }

 public boolean participant(UUID conversationId,UUID userId) {
  return db.count("""
   SELECT COUNT(*) FROM conversation_members
   WHERE conversation_id=:conversationId AND user_id=:userId AND status='ACTIVE'
   """,args("conversationId",conversationId,"userId",userId))==1;
 }

 public Optional<Map<String,Object>> participantRow(UUID conversationId,UUID userId) {
  return db.list("""
   SELECT * FROM conversation_members
   WHERE conversation_id=:conversationId AND user_id=:userId
   """,args("conversationId",conversationId,"userId",userId)).stream().findFirst();
 }

 public boolean anyBlocked(UUID conversationId) {
  return db.count("""
   SELECT COUNT(*) FROM conversation_members
   WHERE conversation_id=:conversationId AND blocked=TRUE
   """,args("conversationId",conversationId))>0;
 }

 public List<Map<String,Object>> listAccepted(UUID userId,int limit,int offset) {
  return db.list("""
   SELECT c.*, me.muted AS muted, me.blocked AS blocked_by_me, peer.blocked AS blocked_by_peer,
    peer_user.id AS peer_user_id, peer_profile.nickname AS peer_nickname, peer_profile.full_name AS peer_full_name,
    peer_profile.avatar_url AS peer_avatar_url, peer_profile.city AS peer_city, peer_profile.bio AS peer_bio,
    t.id AS linked_trip_id, t.title AS group_title,
    (SELECT COUNT(*) FROM conversation_members cm WHERE cm.conversation_id=c.id AND cm.status='ACTIVE') AS member_count,
    me.last_read_at
   FROM conversation_members me
   JOIN conversations c ON c.id=me.conversation_id
   LEFT JOIN conversation_members peer ON peer.conversation_id=c.id AND peer.user_id<>:userId AND c.type='DIRECT'
   LEFT JOIN users peer_user ON peer_user.id=peer.user_id
   LEFT JOIN user_profiles peer_profile ON peer_profile.user_id=peer_user.id
   LEFT JOIN trips t ON t.id=c.linked_trip_id AND c.type='GROUP'
   WHERE me.user_id=:userId AND me.status='ACTIVE' AND c.status='ACCEPTED'
    AND (
     (c.type='DIRECT' AND peer_user.status='ACTIVE')
     OR
     (c.type='GROUP' AND t.id IS NOT NULL)
    )
   ORDER BY c.updated_at DESC,c.id
   LIMIT :limit OFFSET :offset
   """,args("userId",userId,"limit",limit,"offset",offset));
 }

 public List<Map<String,Object>> listPendingForRecipient(UUID userId,int limit,int offset) {
  return db.list("""
   SELECT c.*, me.muted AS muted, me.blocked AS blocked_by_me, peer.blocked AS blocked_by_peer,
    peer_user.id AS peer_user_id, peer_profile.nickname AS peer_nickname, peer_profile.full_name AS peer_full_name,
    peer_profile.avatar_url AS peer_avatar_url, peer_profile.city AS peer_city, peer_profile.bio AS peer_bio,
    me.last_read_at
   FROM conversation_members me
   JOIN conversations c ON c.id=me.conversation_id
   JOIN conversation_members peer ON peer.conversation_id=c.id AND peer.user_id<>:userId
   JOIN users peer_user ON peer_user.id=peer.user_id
   JOIN user_profiles peer_profile ON peer_profile.user_id=peer_user.id
   WHERE me.user_id=:userId AND me.status='ACTIVE' AND c.type='DIRECT' AND c.status='PENDING'
    AND c.recipient_id=:userId AND peer_user.status='ACTIVE'
   ORDER BY c.updated_at DESC,c.id
   LIMIT :limit OFFSET :offset
   """,args("userId",userId,"limit",limit,"offset",offset));
 }

 public Map<String,Object> summaryRow(UUID conversationId,UUID viewerId) {
  return db.one("""
   SELECT c.*, me.muted AS muted, me.blocked AS blocked_by_me, peer.blocked AS blocked_by_peer,
    peer_user.id AS peer_user_id, peer_profile.nickname AS peer_nickname, peer_profile.full_name AS peer_full_name,
    peer_profile.avatar_url AS peer_avatar_url, peer_profile.city AS peer_city, peer_profile.bio AS peer_bio,
    t.id AS linked_trip_id, t.title AS group_title,
    (SELECT COUNT(*) FROM conversation_members cm WHERE cm.conversation_id=c.id AND cm.status='ACTIVE') AS member_count,
    me.last_read_at
   FROM conversations c
   JOIN conversation_members me ON me.conversation_id=c.id AND me.user_id=:viewerId
   LEFT JOIN conversation_members peer ON peer.conversation_id=c.id AND peer.user_id<>:viewerId AND c.type='DIRECT'
   LEFT JOIN users peer_user ON peer_user.id=peer.user_id
   LEFT JOIN user_profiles peer_profile ON peer_profile.user_id=peer_user.id
   LEFT JOIN trips t ON t.id=c.linked_trip_id AND c.type='GROUP'
   WHERE c.id=:conversationId AND me.status='ACTIVE'
    AND (
     (c.type='DIRECT' AND peer_user.status='ACTIVE')
     OR
     (c.type='GROUP' AND t.id IS NOT NULL)
    )
   """,args("conversationId",conversationId,"viewerId",viewerId));
 }

 public List<Map<String,Object>> members(UUID conversationId,UUID viewerId) {
  return db.list("""
   SELECT cm.user_id, cm.role, up.nickname, up.full_name, up.avatar_url,
          CASE WHEN cm.user_id=:viewerId THEN TRUE ELSE FALSE END AS is_current_user
   FROM conversation_members cm
   JOIN users u ON u.id=cm.user_id
   JOIN user_profiles up ON up.user_id=u.id
   WHERE cm.conversation_id=:conversationId AND cm.status='ACTIVE' AND u.status='ACTIVE'
   ORDER BY CASE cm.role WHEN 'LEADER' THEN 0 ELSE 1 END, cm.joined_at, cm.user_id
   """,args("conversationId",conversationId,"viewerId",viewerId));
 }

 public void accept(UUID conversationId) {
  db.update("""
   UPDATE conversations
   SET status='ACCEPTED',accepted_at=COALESCE(accepted_at,CURRENT_TIMESTAMP),updated_at=CURRENT_TIMESTAMP
   WHERE id=:conversationId AND status<>'ACCEPTED'
   """,args("conversationId",conversationId));
 }

 public void removePending(UUID conversationId) {
  db.update("""
   UPDATE conversations
   SET status='REMOVED',removed_at=CURRENT_TIMESTAMP,updated_at=CURRENT_TIMESTAMP
   WHERE id=:conversationId AND status='PENDING'
   """,args("conversationId",conversationId));
 }

 public void reopenAsPending(UUID conversationId,UUID requesterId,UUID recipientId,String status) {
  db.update("""
   UPDATE conversations
   SET status=:status,requester_id=:requesterId,recipient_id=:recipientId,
       removed_at=NULL,accepted_at=CASE WHEN :status='ACCEPTED' THEN CURRENT_TIMESTAMP ELSE NULL END,
       updated_at=CURRENT_TIMESTAMP
   WHERE id=:conversationId
   """,args("conversationId",conversationId,"requesterId",requesterId,"recipientId",recipientId,"status",status));
 }

 public void touch(UUID conversationId) {
  db.update("UPDATE conversations SET updated_at=CURRENT_TIMESTAMP WHERE id=:conversationId",args("conversationId",conversationId));
 }

 public void markRead(UUID conversationId,UUID userId) {
  db.update("""
   UPDATE conversation_members SET last_read_at=CURRENT_TIMESTAMP
   WHERE conversation_id=:conversationId AND user_id=:userId
   """,args("conversationId",conversationId,"userId",userId));
 }

 public void setMuted(UUID conversationId,UUID userId,boolean muted) {
  db.update("""
   UPDATE conversation_members SET muted=:muted
   WHERE conversation_id=:conversationId AND user_id=:userId
   """,args("conversationId",conversationId,"userId",userId,"muted",muted));
 }

 public void setBlocked(UUID conversationId,UUID userId,boolean blocked) {
  db.update("""
   UPDATE conversation_members SET blocked=:blocked
   WHERE conversation_id=:conversationId AND user_id=:userId
   """,args("conversationId",conversationId,"userId",userId,"blocked",blocked));
 }

 public LocalDateTime localDateTime(Object value) {
  if(value instanceof LocalDateTime localDateTime) return localDateTime;
  if(value instanceof OffsetDateTime offsetDateTime) return offsetDateTime.toLocalDateTime();
  if(value instanceof Timestamp timestamp) return timestamp.toLocalDateTime();
  return null;
 }
}
