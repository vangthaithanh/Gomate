package vn.gomate.relationship.repository;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import vn.gomate.relationship.dto.SocialRelationshipDtos;
import static vn.gomate.common.Db.args;

@Repository
public class SocialRelationshipRepository {
 private final Db db;

 public SocialRelationshipRepository(Db db) {
  this.db=db;
 }

 public boolean isPrivate(UUID userId) {
  return db.count("SELECT COUNT(*) FROM user_settings WHERE user_id=:id AND account_visibility='PRIVATE'",args("id",userId))==1;
 }

 // All changes to this target's privacy, edges and requests use the same lock.
 public void lockTarget(UUID targetId) {
  db.one("SELECT user_id FROM user_settings WHERE user_id=:id FOR UPDATE",args("id",targetId));
 }

 public boolean pending(UUID requesterId,UUID targetId) {
  return db.count("SELECT COUNT(*) FROM follow_requests WHERE requester_id=:requester AND target_id=:target AND status='PENDING'",
   args("requester",requesterId,"target",targetId))>0;
 }

 public void requestFollow(UUID requesterId,UUID targetId) {
  db.update("INSERT INTO follow_requests(id,requester_id,target_id) VALUES(:id,:requester,:target)",
   args("id",UUID.randomUUID(),"requester",requesterId,"target",targetId));
 }

 public void cancelPending(UUID requesterId,UUID targetId) {
  db.update("UPDATE follow_requests SET status='CANCELLED',responded_at=CURRENT_TIMESTAMP WHERE requester_id=:requester AND target_id=:target AND status='PENDING'",
   args("requester",requesterId,"target",targetId));
 }

 public Map<String,Object> request(UUID id) {
  return db.one("SELECT id,requester_id,target_id,status FROM follow_requests WHERE id=:id",args("id",id));
 }

 public void respond(UUID id,String status) {
  db.update("UPDATE follow_requests SET status=:status,responded_at=CURRENT_TIMESTAMP WHERE id=:id AND status='PENDING'",args("id",id,"status",status));
 }

 public long requestCount(UUID ownerId) {
  return db.count("SELECT COUNT(*) FROM follow_requests r JOIN users u ON u.id=r.requester_id WHERE r.target_id=:id AND r.status='PENDING' AND u.status='ACTIVE'",args("id",ownerId));
 }

 public List<SocialRelationshipDtos.FollowRequest> requests(UUID ownerId,int limit,int offset) {
  return db.list("""
   SELECT r.id,r.requester_id,p.nickname,p.full_name,p.avatar_url,r.status,r.created_at
   FROM follow_requests r JOIN users u ON u.id=r.requester_id JOIN user_profiles p ON p.user_id=u.id
   WHERE r.target_id=:id AND r.status='PENDING' AND u.status='ACTIVE'
   ORDER BY r.created_at DESC,r.id LIMIT :limit OFFSET :offset
   """,args("id",ownerId,"limit",limit,"offset",offset)).stream().map(row -> {
    Object time=row.get("createdAt");
    OffsetDateTime created=time instanceof OffsetDateTime t?t:relatedAt(time).atOffset(java.time.ZoneOffset.UTC);
    return new SocialRelationshipDtos.FollowRequest((UUID)row.get("id"),(UUID)row.get("requesterId"),
     (String)row.get("nickname"),(String)row.get("fullName"),(String)row.get("avatarUrl"),(String)row.get("status"),created);
   }).toList();
 }

 public boolean activeUser(UUID userId) {
  return db.count("SELECT COUNT(*) FROM users WHERE id=:id AND status='ACTIVE'",args("id",userId))==1;
 }

 public int follow(UUID followerUserId,UUID followedUserId) {
  return db.update("""
   INSERT INTO user_follows(follower_user_id,followed_user_id)
   SELECT :followerUserId,:followedUserId
   WHERE NOT EXISTS (
    SELECT 1 FROM user_follows
    WHERE follower_user_id=:followerUserId AND followed_user_id=:followedUserId
   )
   """,args("followerUserId",followerUserId,"followedUserId",followedUserId));
 }

 public int unfollow(UUID followerUserId,UUID followedUserId) {
  return db.update("""
   DELETE FROM user_follows
   WHERE follower_user_id=:followerUserId AND followed_user_id=:followedUserId
   """,args("followerUserId",followerUserId,"followedUserId",followedUserId));
 }

 public boolean isFollowing(UUID followerUserId,UUID followedUserId) {
  return db.count("""
   SELECT COUNT(*) FROM user_follows
   WHERE follower_user_id=:followerUserId AND followed_user_id=:followedUserId
   """,args("followerUserId",followerUserId,"followedUserId",followedUserId))==1;
 }

 public long countFollowing(UUID userId) {
  return db.count("""
   SELECT COUNT(*) FROM user_follows f
   JOIN users u ON u.id=f.followed_user_id
   WHERE f.follower_user_id=:userId AND u.status='ACTIVE'
   """,args("userId",userId));
 }

 public long countFollowers(UUID userId) {
  return db.count("""
   SELECT COUNT(*) FROM user_follows f
   JOIN users u ON u.id=f.follower_user_id
   WHERE f.followed_user_id=:userId AND u.status='ACTIVE'
   """,args("userId",userId));
 }

 public long countMutualFriends(UUID userId) {
  return db.count("""
   SELECT COUNT(*) FROM user_follows outbound
   JOIN user_follows inbound ON inbound.follower_user_id=outbound.followed_user_id
    AND inbound.followed_user_id=:userId
   JOIN users u ON u.id=outbound.followed_user_id
   WHERE outbound.follower_user_id=:userId AND u.status='ACTIVE'
   """,args("userId",userId));
 }

 public List<SocialRelationshipDtos.UserSummary> following(UUID userId,int limit,int offset) {
  return users("""
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,
    EXISTS (SELECT 1 FROM user_settings s WHERE s.user_id=u.id AND s.account_visibility='PRIVATE') AS is_private,
    EXISTS (SELECT 1 FROM follow_requests r WHERE r.requester_id=:viewerId AND r.target_id=u.id AND r.status='PENDING') AS follow_request_pending,f.created_at AS related_at,
    TRUE AS following_by_me,
    CASE WHEN back.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS follows_me,
    CASE WHEN back.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS mutual_friend
   FROM user_follows f
   JOIN users u ON u.id=f.followed_user_id
   JOIN user_profiles p ON p.user_id=u.id
   LEFT JOIN user_follows back ON back.follower_user_id=u.id AND back.followed_user_id=:userId
   WHERE f.follower_user_id=:userId AND u.status='ACTIVE'
   ORDER BY f.created_at DESC,u.id
   LIMIT :limit OFFSET :offset
   """,userId,limit,offset);
 }

 public List<SocialRelationshipDtos.UserSummary> followers(UUID userId,int limit,int offset) {
  return users("""
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,
    EXISTS (SELECT 1 FROM user_settings s WHERE s.user_id=u.id AND s.account_visibility='PRIVATE') AS is_private,
    EXISTS (SELECT 1 FROM follow_requests r WHERE r.requester_id=:viewerId AND r.target_id=u.id AND r.status='PENDING') AS follow_request_pending,f.created_at AS related_at,
    CASE WHEN outbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS following_by_me,
    TRUE AS follows_me,
    CASE WHEN outbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS mutual_friend
   FROM user_follows f
   JOIN users u ON u.id=f.follower_user_id
   JOIN user_profiles p ON p.user_id=u.id
   LEFT JOIN user_follows outbound ON outbound.follower_user_id=:userId AND outbound.followed_user_id=u.id
   WHERE f.followed_user_id=:userId AND u.status='ACTIVE'
   ORDER BY f.created_at DESC,u.id
   LIMIT :limit OFFSET :offset
   """,userId,limit,offset);
 }

 public List<SocialRelationshipDtos.UserSummary> mutualFriends(UUID userId,int limit,int offset) {
  return users("""
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,
    EXISTS (SELECT 1 FROM user_settings s WHERE s.user_id=u.id AND s.account_visibility='PRIVATE') AS is_private,
    EXISTS (SELECT 1 FROM follow_requests r WHERE r.requester_id=:viewerId AND r.target_id=u.id AND r.status='PENDING') AS follow_request_pending,outbound.created_at AS related_at,
    TRUE AS following_by_me,
    TRUE AS follows_me,
    TRUE AS mutual_friend
   FROM user_follows outbound
   JOIN user_follows inbound ON inbound.follower_user_id=outbound.followed_user_id
    AND inbound.followed_user_id=:userId
   JOIN users u ON u.id=outbound.followed_user_id
   JOIN user_profiles p ON p.user_id=u.id
   WHERE outbound.follower_user_id=:userId AND u.status='ACTIVE'
   ORDER BY outbound.created_at DESC,u.id
   LIMIT :limit OFFSET :offset
   """,userId,limit,offset);
 }

 public long countPeople(UUID viewerId,UUID targetId,boolean friends) {
  String condition="EXISTS(SELECT 1 FROM user_follows f WHERE f.follower_user_id=u.id AND f.followed_user_id=:targetId)";
  if(friends) condition+=" AND EXISTS(SELECT 1 FROM user_follows f WHERE f.follower_user_id=:targetId AND f.followed_user_id=u.id)";
  return db.count("SELECT COUNT(*) FROM users u WHERE u.status='ACTIVE' AND "+condition+" AND "+vn.gomate.relationship.block.GlobalBlockPolicy.allowed(":viewerId","u.id"),args("viewerId",viewerId,"targetId",targetId));
 }
 public List<SocialRelationshipDtos.UserSummary> people(UUID viewerId,UUID targetId,boolean friends,int limit,int offset) {
  String condition=friends
   ? "EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=:targetId AND f.followed_user_id=u.id) AND EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=u.id AND f.followed_user_id=:targetId)"
   : "EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=u.id AND f.followed_user_id=:targetId)";
  return db.list("""
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,
    EXISTS (SELECT 1 FROM user_settings s WHERE s.user_id=u.id AND s.account_visibility='PRIVATE') AS is_private,
    EXISTS (SELECT 1 FROM follow_requests r WHERE r.requester_id=:viewerId AND r.target_id=u.id AND r.status='PENDING') AS follow_request_pending,
    CASE WHEN outbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS following_by_me,
    CASE WHEN inbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS follows_me,
    CASE WHEN outbound.follower_user_id IS NOT NULL AND inbound.follower_user_id IS NOT NULL THEN TRUE ELSE FALSE END AS mutual_friend
   FROM users u JOIN user_profiles p ON p.user_id=u.id
   LEFT JOIN user_follows outbound ON outbound.follower_user_id=:viewerId AND outbound.followed_user_id=u.id
   LEFT JOIN user_follows inbound ON inbound.follower_user_id=u.id AND inbound.followed_user_id=:viewerId
   WHERE u.status='ACTIVE' AND
    NOT EXISTS(SELECT 1 FROM user_blocks b WHERE (b.blocker_user_id=:viewerId AND b.blocked_user_id=u.id) OR (b.blocker_user_id=u.id AND b.blocked_user_id=:viewerId)) AND
   """+condition+" ORDER BY LOWER(COALESCE(p.full_name,p.nickname)),u.id LIMIT :limit OFFSET :offset",
   args("viewerId",viewerId,"targetId",targetId,"limit",limit,"offset",offset)).stream().map(this::user).toList();
 }

 private List<SocialRelationshipDtos.UserSummary> users(String sql,UUID userId,int limit,int offset) {
  return db.list(sql,args("userId",userId,"viewerId",userId,"limit",limit,"offset",offset))
   .stream()
   .map(this::user)
   .toList();
 }

 private SocialRelationshipDtos.UserSummary user(Map<String,Object> row) {
  return new SocialRelationshipDtos.UserSummary(
   (UUID)row.get("userId"),
   (String)row.get("nickname"),
   (String)row.get("fullName"),
   (String)row.get("avatarUrl"),
   (String)row.get("city"),
   (String)row.get("bio"),
   Boolean.TRUE.equals(row.get("followingByMe")),
   Boolean.TRUE.equals(row.get("followsMe")),
   Boolean.TRUE.equals(row.get("mutualFriend")),
   Boolean.TRUE.equals(row.get("isPrivate")),
   Boolean.TRUE.equals(row.get("followRequestPending")),
   relatedAt(row.get("relatedAt"))
  );
 }

 private LocalDateTime relatedAt(Object value) {
  if(value instanceof LocalDateTime localDateTime) return localDateTime;
  if(value instanceof OffsetDateTime offsetDateTime) return offsetDateTime.toLocalDateTime();
  if(value instanceof Timestamp timestamp) return timestamp.toLocalDateTime();
  return null;
 }
}
