package vn.gomate.social.comment;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class CommentRepository {
 private final Db db;
 public CommentRepository(Db db) {this.db=db;}
 // A hidden/deleted root hides its entire thread, including binary reads.
 public static final String VISIBLE="c.publication_status='ACTIVE' AND c.moderation_status='VISIBLE' AND (c.parent_comment_id IS NULL OR EXISTS(SELECT 1 FROM comments r WHERE r.id=c.parent_comment_id AND r.publication_status='ACTIVE' AND r.moderation_status='VISIBLE'))";
 public static String visibleTo(String actor) {
  return VISIBLE+" AND "+vn.gomate.relationship.block.GlobalBlockPolicy.allowed(actor,"c.user_id")
   +" AND (c.parent_comment_id IS NULL OR EXISTS(SELECT 1 FROM comments cr WHERE cr.id=c.parent_comment_id AND "+vn.gomate.relationship.block.GlobalBlockPolicy.allowed(actor,"cr.user_id")+"))";
 }
 public Map<String,Object> row(long id) {return db.one("SELECT * FROM comments WHERE id=:id",args("id",id));}
 public Map<String,Object> visible(long id) {return db.one("SELECT c.* FROM comments c WHERE c.id=:id AND "+VISIBLE,args("id",id));}
 public List<Map<String,Object>> existing(UUID actor,UUID key) {return db.list("SELECT * FROM comments WHERE user_id=:actor AND client_request_id=:key",args("actor",actor,"key",key));}
 public List<Map<String,Object>> page(UUID actor,long post,Long root,long after,int limit) {
  return db.list("""
   SELECT c.*,COALESCE(up.full_name,up.nickname) AS user_name,up.avatar_url,COALESCE(replied.full_name,replied.nickname) AS reply_to_user_name,
    (SELECT COUNT(*) FROM comment_likes l WHERE l.comment_id=c.id) AS like_count,
    EXISTS(SELECT 1 FROM comment_likes l WHERE l.comment_id=c.id AND l.user_id=:actor) AS liked_by_me,
    (SELECT COUNT(*) FROM comments child WHERE child.parent_comment_id=c.id AND child.publication_status='ACTIVE' AND child.moderation_status='VISIBLE' AND %s) AS reply_count
   FROM comments c JOIN user_profiles up ON up.user_id=c.user_id
   LEFT JOIN user_profiles replied ON replied.user_id=c.reply_to_user_id
   WHERE c.post_id=:post AND
   """.formatted(vn.gomate.relationship.block.GlobalBlockPolicy.allowed(":actor","child.user_id"))+VISIBLE+" AND "+vn.gomate.relationship.block.GlobalBlockPolicy.allowed(":actor","c.user_id")+" AND (c.parent_comment_id IS NULL OR EXISTS(SELECT 1 FROM comments cr WHERE cr.id=c.parent_comment_id AND "+vn.gomate.relationship.block.GlobalBlockPolicy.allowed(":actor","cr.user_id")+"))"+(root==null?" AND c.parent_comment_id IS NULL AND c.id<:after ORDER BY c.id DESC":" AND c.parent_comment_id=:root AND c.id>:after ORDER BY c.id ASC")+" LIMIT :limit",
   args("actor",actor,"post",post,"root",root,"after",after,"limit",limit));
 }
 public Set<Long> visibleIds(UUID actor,List<Long> ids) {
  if(ids.isEmpty()) return Set.of();
  var result=new HashSet<Long>();
  for(var r:db.list("SELECT c.id FROM comments c WHERE c.id IN (:ids) AND "+visibleTo(":actor"),args("ids",ids,"actor",actor))) result.add(((Number)r.get("id")).longValue());
  return result;
 }
 public List<Map<String,Object>> media(List<Long> ids) {
  return ids.isEmpty()?List.of():db.list("SELECT * FROM comment_media WHERE comment_id IN (:ids) AND state='ATTACHED' ORDER BY sort_order",args("ids",ids));
 }
 public Map<String,Object> media(UUID id) {return media(id,false);}
 public Map<String,Object> media(UUID id,boolean lock) {return db.one("SELECT * FROM comment_media WHERE id=:id"+(lock?" FOR UPDATE":""),args("id",id));}
 public boolean insert(UUID actor,long post,CommentDtos.Create req,String hash,Long root,UUID reply) {
  return db.update("INSERT INTO comments(post_id,user_id,client_request_id,request_hash,content,parent_comment_id,reply_to_user_id) VALUES(:post,:actor,:key,:hash,:body,:root,:reply) ON CONFLICT DO NOTHING",args("post",post,"actor",actor,"key",req.clientRequestId(),"hash",hash,"body",req.body(),"root",root,"reply",reply))>0;
 }
 public void attach(UUID media,long comment,int order) {
  if(db.update("UPDATE comment_media SET comment_id=:c,sort_order=:sort,state='ATTACHED' WHERE id=:id AND state='READY' AND comment_id IS NULL",args("c",comment,"sort",order,"id",media))!=1) throw new vn.gomate.common.ApiException(409,"COMMENT_MEDIA_NOT_READY","Ảnh không còn sẵn sàng.");
 }
 public void like(UUID actor,long id,boolean value) {
  if(value) db.update("INSERT INTO comment_likes(comment_id,user_id) VALUES(:id,:actor) ON CONFLICT DO NOTHING",args("id",id,"actor",actor));
  else db.update("DELETE FROM comment_likes WHERE comment_id=:id AND user_id=:actor",args("id",id,"actor",actor));
 }
 public void delete(long id) {db.update("UPDATE comments SET publication_status='DELETED',updated_at=CURRENT_TIMESTAMP WHERE id=:id OR parent_comment_id=:id",args("id",id));}
 public List<Map<String,Object>> existingMedia(UUID id) {return db.list("SELECT * FROM comment_media WHERE id=:id",args("id",id));}
 public void reserve(UUID actor,long post,UUID id,String digest,String pid) {db.update("INSERT INTO comment_media(id,owner_id,post_id,content_hash,state,public_id,thumbnail_public_id) VALUES(:id,:actor,:post,:hash,'UPLOADING',:pid,:thumb)",args("id",id,"actor",actor,"post",post,"hash",digest,"pid",pid,"thumb",pid+"_cover"));}
 public void ready(UUID id,vn.gomate.social.post.PostFileInspector.Metadata meta,vn.gomate.media.dto.MediaUploadResult actual) {if(db.update("UPDATE comment_media SET state='READY',format=:format,mime_type=:mime,bytes=:bytes,width=:width,height=:height WHERE id=:id AND state='UPLOADING'",args("id",id,"format",actual.format(),"mime",meta.mime(),"bytes",actual.bytes(),"width",actual.width(),"height",actual.height()))!=1) throw new IllegalStateException("Upload state changed");}
 public void markCleanup(UUID id) {db.update("UPDATE comment_media SET state='CLEANUP' WHERE id=:id AND comment_id IS NULL",args("id",id));}
 public boolean deleted(Object comment) {return db.count("SELECT COUNT(*) FROM comments c JOIN posts p ON p.id=c.post_id WHERE c.id=:c AND (c.publication_status='DELETED' OR p.deleted_at IS NOT NULL)",args("c",comment))!=0;}
 public void cleaned(UUID id,boolean attached) {db.update(attached?"UPDATE comment_media SET cleaned_at=CURRENT_TIMESTAMP WHERE id=:id":"DELETE FROM comment_media WHERE id=:id",args("id",id));}
 public List<Map<String,Object>> expired(java.time.OffsetDateTime before) {return db.list("""
  SELECT m.id FROM comment_media m LEFT JOIN comments c ON c.id=m.comment_id LEFT JOIN posts p ON p.id=m.post_id
  WHERE m.cleaned_at IS NULL AND ((m.comment_id IS NULL AND (m.state='CLEANUP' OR m.created_at<:before)) OR c.publication_status='DELETED' OR p.deleted_at IS NOT NULL)
  ORDER BY m.created_at LIMIT 50
  """,args("before",before));}

}
