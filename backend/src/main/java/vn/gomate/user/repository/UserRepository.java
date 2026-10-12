package vn.gomate.user.repository;

import java.sql.Timestamp;
import java.text.Normalizer;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import vn.gomate.user.dto.UserDtos;
import static vn.gomate.common.Db.args;

@Repository
public class UserRepository {
 private final Db db;

 public UserRepository(Db db) {
  this.db=db;
 }

 public Optional<Map<String,Object>> activeUserRow(UUID userId) {
  var rows=db.list("""
   SELECT u.id,u.email,u.role,u.status,u.created_at,u.last_login_at,u.google_subject,
    p.nickname,p.full_name,p.avatar_url,p.city,p.bio,
    s.onboarding_completed,s.interest_codes
   FROM users u
   JOIN user_profiles p ON p.user_id=u.id
   JOIN user_settings s ON s.user_id=u.id
   WHERE u.id=:userId AND u.status='ACTIVE'
   """,args("userId",userId));
  return rows.stream().findFirst();
 }

 public UserDtos.UserProfile profile(UUID viewerId,UUID targetUserId,boolean includePrivateEmail) {
  var row=activeUserRow(targetUserId).orElseThrow(vn.gomate.common.ApiException::notFound);
  var stats=stats(targetUserId);
  Boolean followingByMe=null;
  Boolean followsMe=null;
  Boolean mutualFriend=null;
  if(viewerId!=null && !viewerId.equals(targetUserId)) {
   followingByMe=isFollowing(viewerId,targetUserId);
   followsMe=isFollowing(targetUserId,viewerId);
   mutualFriend=followingByMe && followsMe;
  }
  return new UserDtos.UserProfile(
   (UUID)row.get("id"),
   (UUID)row.get("id"),
   includePrivateEmail?(String)row.get("email"):null,
   includePrivateEmail?(String)row.get("role"):null,
   (String)row.get("status"),
   (String)row.get("nickname"),
   displayName(row),
   (String)row.get("fullName"),
   (String)row.get("avatarUrl"),
   (String)row.get("city"),
   (String)row.get("bio"),
   includePrivateEmail?(String)row.get("interestCodes"):null,
   row.get("googleSubject")!=null,
   Boolean.TRUE.equals(row.get("onboardingCompleted")),
   stats,
   followingByMe,
   followsMe,
   mutualFriend,
   asLocalDateTime(row.get("createdAt")),
   asLocalDateTime(row.get("lastLoginAt"))
  );
 }

 public UserDtos.RelationshipStats stats(UUID userId) {
  long following=db.count("""
   SELECT COUNT(*) FROM user_follows f JOIN users u ON u.id=f.followed_user_id
   WHERE f.follower_user_id=:userId AND u.status='ACTIVE'
   """,args("userId",userId));
  long followers=db.count("""
   SELECT COUNT(*) FROM user_follows f JOIN users u ON u.id=f.follower_user_id
   WHERE f.followed_user_id=:userId AND u.status='ACTIVE'
   """,args("userId",userId));
  long mutual=db.count("""
   SELECT COUNT(*) FROM user_follows outbound
   JOIN user_follows inbound ON inbound.follower_user_id=outbound.followed_user_id
    AND inbound.followed_user_id=:userId
   JOIN users u ON u.id=outbound.followed_user_id
   WHERE outbound.follower_user_id=:userId AND u.status='ACTIVE'
   """,args("userId",userId));
  return new UserDtos.RelationshipStats(following,followers,mutual);
 }

 public boolean nicknameTakenByOther(String nicknameKey,UUID currentUserId) {
  return db.count("""
   SELECT COUNT(*) FROM user_profiles
   WHERE nickname_key=:nicknameKey AND user_id<>:currentUserId
   """,args("nicknameKey",nicknameKey,"currentUserId",currentUserId))>0;
 }

 public void updateProfile(UUID userId,String nickname,String nicknameKey,String fullName,String city,String bio,String avatarUrl) {
  db.update("""
   UPDATE user_profiles
   SET nickname=COALESCE(:nickname,nickname),
       nickname_key=COALESCE(:nicknameKey,nickname_key),
       full_name=COALESCE(:fullName,full_name),
       city=COALESCE(:city,city),
       bio=COALESCE(:bio,bio),
       avatar_url=COALESCE(:avatarUrl,avatar_url)
   WHERE user_id=:userId
   """,args(
   "userId",userId,
   "nickname",nickname,
   "nicknameKey",nicknameKey,
   "fullName",emptyToNull(fullName),
   "city",emptyToNull(city),
   "bio",emptyToNull(bio),
   "avatarUrl",emptyToNull(avatarUrl)
  ));
 }

 public List<UserDtos.UserSearchItem> search(UUID viewerId,String query,int limit,int offset) {
  String like="%"+normalizeSearch(query)+"%";
  return db.list("""
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,
    CASE WHEN outbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS following_by_me,
    CASE WHEN inbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS follows_me
   FROM users u
   JOIN user_profiles p ON p.user_id=u.id
   LEFT JOIN user_follows outbound ON outbound.follower_user_id=:viewerId AND outbound.followed_user_id=u.id
   LEFT JOIN user_follows inbound ON inbound.follower_user_id=u.id AND inbound.followed_user_id=:viewerId
   WHERE u.status='ACTIVE'
    AND u.id<>:viewerId
    AND (
     LOWER(p.nickname) LIKE :like
     OR LOWER(COALESCE(p.full_name,'')) LIKE :like
     OR LOWER(COALESCE(p.city,'')) LIKE :like
    )
   ORDER BY
    CASE WHEN outbound.follower_user_id IS NOT NULL AND inbound.follower_user_id IS NOT NULL THEN 0
         WHEN outbound.follower_user_id IS NOT NULL THEN 1
         WHEN inbound.follower_user_id IS NOT NULL THEN 2
         ELSE 3 END,
    LOWER(COALESCE(p.full_name,p.nickname)),
    u.id
   LIMIT :limit OFFSET :offset
   """,args("viewerId",viewerId,"like",like,"limit",limit,"offset",offset))
   .stream().map(this::searchItem).toList();
 }

 public List<UserDtos.UserSearchItem> suggestContacts(UUID viewerId,int limit,int offset) {
  return db.list("""
   SELECT u.id AS user_id,p.nickname,p.full_name,p.avatar_url,p.city,p.bio,
    CASE WHEN outbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS following_by_me,
    CASE WHEN inbound.follower_user_id IS NULL THEN FALSE ELSE TRUE END AS follows_me
   FROM users u
   JOIN user_profiles p ON p.user_id=u.id
   LEFT JOIN user_follows outbound ON outbound.follower_user_id=:viewerId AND outbound.followed_user_id=u.id
   LEFT JOIN user_follows inbound ON inbound.follower_user_id=u.id AND inbound.followed_user_id=:viewerId
   WHERE u.status='ACTIVE' AND u.id<>:viewerId
   ORDER BY
    CASE WHEN outbound.follower_user_id IS NOT NULL AND inbound.follower_user_id IS NOT NULL THEN 0
         WHEN outbound.follower_user_id IS NOT NULL THEN 1
         WHEN inbound.follower_user_id IS NOT NULL THEN 2
         ELSE 3 END,
    LOWER(COALESCE(p.full_name,p.nickname)),
    u.id
   LIMIT :limit OFFSET :offset
   """,args("viewerId",viewerId,"limit",limit,"offset",offset))
   .stream().map(this::searchItem).toList();
 }

 public long suggestContactsCount(UUID viewerId) {
  return db.count("""
   SELECT COUNT(*)
   FROM users u
   WHERE u.status='ACTIVE' AND u.id<>:viewerId
   """,args("viewerId",viewerId));
 }

 public long searchCount(UUID viewerId,String query) {
  String like="%"+normalizeSearch(query)+"%";
  return db.count("""
   SELECT COUNT(*)
   FROM users u
   JOIN user_profiles p ON p.user_id=u.id
   WHERE u.status='ACTIVE'
    AND u.id<>:viewerId
    AND (
     LOWER(p.nickname) LIKE :like
     OR LOWER(COALESCE(p.full_name,'')) LIKE :like
     OR LOWER(COALESCE(p.city,'')) LIKE :like
    )
   """,args("viewerId",viewerId,"like",like));
 }

 public boolean isFollowing(UUID followerUserId,UUID followedUserId) {
  return db.count("""
   SELECT COUNT(*) FROM user_follows
   WHERE follower_user_id=:followerUserId AND followed_user_id=:followedUserId
   """,args("followerUserId",followerUserId,"followedUserId",followedUserId))==1;
 }

 public String nicknameKey(String nickname) {
  return Normalizer.normalize(nickname.trim(),Normalizer.Form.NFC).toLowerCase(Locale.ROOT);
 }

 private UserDtos.UserSearchItem searchItem(Map<String,Object> row) {
  boolean following=Boolean.TRUE.equals(row.get("followingByMe"));
  boolean follows=Boolean.TRUE.equals(row.get("followsMe"));
  return new UserDtos.UserSearchItem(
   (UUID)row.get("userId"),
   (String)row.get("nickname"),
   displayName(row),
   (String)row.get("avatarUrl"),
   (String)row.get("city"),
   (String)row.get("bio"),
   following,
   follows,
   following && follows
  );
 }

 private String displayName(Map<String,Object> row) {
  String fullName=(String)row.get("fullName");
  return fullName==null || fullName.isBlank()?(String)row.get("nickname"):fullName;
 }

 private String normalizeSearch(String value) {
  return value==null?"":value.trim().toLowerCase(Locale.ROOT);
 }

 private String emptyToNull(String value) {
  if(value==null) return null;
  String trimmed=value.trim();
  return trimmed.isEmpty()?null:trimmed;
 }

 private LocalDateTime asLocalDateTime(Object value) {
  if(value instanceof LocalDateTime localDateTime) return localDateTime;
  if(value instanceof OffsetDateTime offsetDateTime) return offsetDateTime.toLocalDateTime();
  if(value instanceof Timestamp timestamp) return timestamp.toLocalDateTime();
  return null;
 }
}
