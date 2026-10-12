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
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,f.created_at AS related_at,
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
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,f.created_at AS related_at,
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
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,outbound.created_at AS related_at,
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

 private List<SocialRelationshipDtos.UserSummary> users(String sql,UUID userId,int limit,int offset) {
  return db.list(sql,args("userId",userId,"limit",limit,"offset",offset))
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
