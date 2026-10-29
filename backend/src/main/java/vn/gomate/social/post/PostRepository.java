package vn.gomate.social.post;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class PostRepository {
 private final Db db;
 public PostRepository(Db db) { this.db=db; }
 public boolean validPlace(long id) {return db.count("SELECT COUNT(*) FROM places WHERE id=:id AND status='ACTIVE'",args("id",id))==1;}
 public boolean validUser(UUID id) {return db.count("SELECT COUNT(*) FROM users WHERE id=:id AND status='ACTIVE'",args("id",id))==1;}
 public void tagUser(long post,UUID user) {db.update("INSERT INTO post_user_tags(post_id,user_id) VALUES(:post,:user)",args("post",post,"user",user));}
 public List<Map<String,Object>> existingMedia(UUID id) {return db.list("SELECT * FROM post_media WHERE id=:id",args("id",id));}
 public void reserve(UUID id,UUID owner,String hash,String kind,String pid) {
  db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id) VALUES(:id,:owner,:hash,:kind,'UPLOADING',:pid,:thumb)",
   args("id",id,"owner",owner,"hash",hash,"kind",kind,"pid",pid,"thumb",pid+"_cover"));
 }
 public void ready(UUID id,String format,PostFileInspector.Metadata meta,long bytes) {
  if(db.update("UPDATE post_media SET state='READY',format=:format,mime_type=:mime,bytes=:bytes,duration_ms=:duration,width=:width,height=:height WHERE id=:id AND state='UPLOADING'",
   args("format",format,"mime",meta.mime(),"bytes",bytes,"duration",meta.durationMs(),"width",meta.width(),"height",meta.height(),"id",id))!=1)
    throw new IllegalStateException("Media reservation changed");
 }
 public void markCleanup(UUID id) {db.update("UPDATE post_media SET state='CLEANUP' WHERE id=:id AND post_id IS NULL",args("id",id));}
 public void deleteCleanup(UUID id) {db.update("DELETE FROM post_media WHERE id=:id AND post_id IS NULL AND state='CLEANUP'",args("id",id));}
 public List<Map<String,Object>> expired(java.time.OffsetDateTime cutoff) {
  return db.list("SELECT id FROM post_media WHERE (post_id IS NULL AND (state='CLEANUP' OR created_at<:cutoff)) OR (cleaned_at IS NULL AND post_id IN (SELECT id FROM posts WHERE deleted_at IS NOT NULL)) LIMIT 50",args("cutoff",cutoff));
 }
 public Map<String,Object> post(long id) {
  return db.one("""
   SELECT p.*,s.account_visibility,u.status AS author_status,up.nickname,up.full_name,up.avatar_url,pl.name AS place_name
   FROM posts p JOIN users u ON u.id=p.author_id JOIN user_profiles up ON up.user_id=u.id
   JOIN user_settings s ON s.user_id=u.id LEFT JOIN places pl ON pl.id=p.place_id WHERE p.id=:id
   """,args("id",id));
 }
 public Optional<Map<String,Object>> published(UUID owner,UUID request) {
  return db.list("SELECT id,request_hash FROM posts WHERE author_id=:owner AND client_request_id=:request",args("owner",owner,"request",request)).stream().findFirst();
 }
 public String lockAccount(UUID owner) {
  return (String)db.one("SELECT account_visibility FROM user_settings WHERE user_id=:id FOR UPDATE",args("id",owner)).get("accountVisibility");
 }
 public Map<String,Object> media(UUID id,boolean lock) {
  return db.one("SELECT * FROM post_media WHERE id=:id"+(lock?" FOR UPDATE":""),args("id",id));
 }
 public List<Map<String,Object>> mediaFor(long id) {
  return db.list("SELECT * FROM post_media WHERE post_id=:id ORDER BY sort_order",args("id",id));
 }
 public long insert(UUID owner,PostDtos.Publish req,String hash,String audience) {
  db.update("INSERT INTO posts(author_id,client_request_id,request_hash,content,audience,place_id) VALUES(:owner,:request,:hash,:content,:audience,:place)",
   args("owner",owner,"request",req.clientRequestId(),"hash",hash,"content",req.caption(),"audience",audience,"place",req.placeId()));
  return ((Number)published(owner,req.clientRequestId()).orElseThrow().get("id")).longValue();
 }
 public void attach(UUID id,long post,int order) {
  if(db.update("UPDATE post_media SET post_id=:post,sort_order=:order,state='ATTACHED' WHERE id=:id AND state='READY' AND post_id IS NULL",args("post",post,"order",order,"id",id))!=1) throw new IllegalStateException("Media attachment changed");
 }
 public void tag(long post,String name) {
  String hash=PostService.digest(name.getBytes(java.nio.charset.StandardCharsets.UTF_8));
  db.update("INSERT INTO hashtags(name,name_hash) VALUES(:name,:hash) ON CONFLICT DO NOTHING",args("name",name,"hash",hash));
  if(db.update("INSERT INTO post_hashtags(post_id,hashtag_id) SELECT :post,id FROM hashtags WHERE name_hash=:hash AND name=:name",args("post",post,"name",name,"hash",hash))!=1) throw new IllegalStateException("Hashtag identity conflict");
 }
 public List<String> tags(long id) {
  return db.list("SELECT h.name FROM hashtags h JOIN post_hashtags ph ON ph.hashtag_id=h.id WHERE ph.post_id=:id ORDER BY h.name",args("id",id)).stream().map(r->(String)r.get("name")).toList();
 }
 public List<UUID> people(long id) {
  return db.list("SELECT user_id FROM post_user_tags WHERE post_id=:id ORDER BY user_id",args("id",id)).stream().map(r->(UUID)r.get("userId")).toList();
 }
 public long pinnedCount(UUID owner) {return db.count("SELECT COUNT(*) FROM posts WHERE author_id=:owner AND deleted_at IS NULL AND pinned_at IS NOT NULL",args("owner",owner));}
 public void pin(long id,boolean value) {db.update("UPDATE posts SET pinned_at="+(value?"CURRENT_TIMESTAMP":"NULL")+" WHERE id=:id",args("id",id));}
 public void audience(long id,String value) {db.update("UPDATE posts SET audience=:value WHERE id=:id",args("id",id,"value",value));}
 public void delete(long id) {db.update("UPDATE posts SET deleted_at=CURRENT_TIMESTAMP,pinned_at=NULL WHERE id=:id AND deleted_at IS NULL",args("id",id));}
 public boolean deleted(long post) {return db.count("SELECT COUNT(*) FROM posts WHERE id=:id AND deleted_at IS NOT NULL",args("id",post))==1;}
 public void cleaned(UUID id) {db.update("UPDATE post_media SET cleaned_at=CURRENT_TIMESTAMP WHERE id=:id",args("id",id));}
 public List<Map<String,Object>> profile(UUID viewer,UUID author,int limit,PostService.Cursor cursor) {
  var params=args("viewer",viewer,"author",author,"limit",limit);
  String key="CASE WHEN p.pinned_at IS NULL THEN 1 ELSE 0 END",time="COALESCE(p.pinned_at,p.created_at)";
  String after="";
  if(cursor!=null) {
   params.putAll(args("rank",cursor.rank(),"time",cursor.time(),"created",cursor.created(),"id",cursor.id()));
   after=" AND ("+key+">:rank OR ("+key+"=:rank AND ("+time+"<:time OR ("+time+"=:time AND (p.created_at<:created OR (p.created_at=:created AND p.id<:id))))))";
  }
  return db.list("""
   SELECT p.* FROM posts p JOIN users u ON u.id=p.author_id JOIN user_settings s ON s.user_id=p.author_id
   WHERE p.author_id=:author AND u.status='ACTIVE' AND p.deleted_at IS NULL AND (
    p.author_id=:viewer OR (
     p.audience='ACCOUNT' AND (s.account_visibility='PUBLIC' OR EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=:viewer AND f.followed_user_id=p.author_id))
     OR p.audience='FRIENDS' AND EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=:viewer AND f.followed_user_id=p.author_id)
       AND EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=p.author_id AND f.followed_user_id=:viewer)
    ))
   """+after+" ORDER BY "+key+" ASC,"+time+" DESC,p.created_at DESC,p.id DESC LIMIT :limit",params);
 }
}
