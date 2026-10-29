package vn.gomate.social.comment;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.social.post.*;

@Service
public class CommentService {
 private final CommentRepository repo;
 private final PostService posts;
 private final PostRepository postRepo;
 private final PostFeedRepository feed;
 private final ObjectMapper json;
 private final vn.gomate.notification.service.NotificationService notifications;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;
 public CommentService(CommentRepository repo,PostService posts,PostRepository postRepo,PostFeedRepository feed,ObjectMapper json,vn.gomate.notification.service.NotificationService notifications,vn.gomate.relationship.block.GlobalBlockPolicy blocks) {this.repo=repo;this.posts=posts;this.postRepo=postRepo;this.feed=feed;this.json=json;this.notifications=notifications;this.blocks=blocks;}
 public void lock(UUID actor,long post) {
  var p=posts.authorize(actor,post);
  blocks.lockPair(actor,(UUID)p.get("authorId"));feed.lock(post);posts.authorize(actor,post);
 }
 public Map<String,Object> authorize(UUID actor,long id) {
  var c=repo.visible(id);blocks.requireAllowed(actor,(UUID)c.get("userId"));if(c.get("parentCommentId")!=null) blocks.requireAllowed(actor,(UUID)repo.visible(((Number)c.get("parentCommentId")).longValue()).get("userId"));posts.authorize(actor,((Number)c.get("postId")).longValue());return c;
 }
 public static void length(String text,int max) {if(text==null || Pattern.compile("\\X").matcher(text).results().limit(max+1L).count()>max) throw ApiException.bad("Nội dung vượt giới hạn "+max+" ký tự.");}
 public record Cursor(UUID viewer,long post,Long root,long after) {}
 public CommentDtos.Page list(UUID actor,long post,Long root,int size,String token) {
  if(size<1 || size>50) throw ApiException.bad("Kích thước trang từ 1 đến 50.");
  posts.authorize(actor,post);
  if(root!=null) {var r=authorize(actor,root);if(r.get("parentCommentId")!=null || ((Number)r.get("postId")).longValue()!=post) throw ApiException.notFound();}
  long after=root==null?Long.MAX_VALUE:0;
  if(token!=null) try {var c=json.readValue(Base64.getUrlDecoder().decode(token),Cursor.class);if(!actor.equals(c.viewer()) || c.post()!=post || !Objects.equals(root,c.root()) || c.after()<1) throw new IllegalArgumentException();after=c.after();}catch(Exception e) {throw ApiException.bad("Con trỏ không hợp lệ.");}
  var rows=repo.page(actor,post,root,after,size+1);var page=rows.subList(0,Math.min(size,rows.size()));
  var ids=page.stream().map(r->((Number)r.get("id")).longValue()).toList();
  var media=repo.media(ids);var items=new ArrayList<Map<String,Object>>();
  var eligible=repo.visibleIds(actor,ids);
  var hiddenTargets=blocks.hidden(actor,page.stream().map(r->(UUID)r.get("replyToUserId")).filter(Objects::nonNull).toList());
  for(var r:page) {
   long id=((Number)r.get("id")).longValue();
   if(!eligible.contains(id)) continue;
   var projected=new LinkedHashMap<String,Object>(r);
   if(r.get("replyToUserId")!=null && hiddenTargets.contains((UUID)r.get("replyToUserId"))) {projected.put("replyToUserId",null);projected.put("replyToUserName",null);}
   items.add(project(actor,projected,media.stream().filter(m->((Number)m.get("commentId")).longValue()==id).toList()));
  }
  posts.authorize(actor,post);
  String next=null;
  if(rows.size()>size) try {next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(new Cursor(actor,post,root,((Number)page.get(page.size()-1).get("id")).longValue())));}catch(Exception e) {throw new IllegalStateException(e);}
  return new CommentDtos.Page(items,next);
 }
 private Map<String,Object> project(UUID actor,Map<String,Object> r,List<Map<String,Object>> media) {
  long id=((Number)r.get("id")).longValue();
  var out=new LinkedHashMap<String,Object>();
  for(String key:List.of("id","postId","userId","userName","avatarUrl","parentCommentId","replyToUserId","replyToUserName","likeCount","likedByMe","replyCount")) out.put(key,r.get(key));
  out.put("commentId",id);out.put("body",r.get("content"));out.put("createdAt",PostService.instant(r.get("createdAt")));out.put("isMine",actor.equals(r.get("userId")));
  out.put("media",media.stream().map(m->Map.of("id",m.get("id"),"url","/comments/"+id+"/media/"+m.get("id"),"thumbnailUrl","/comments/"+id+"/media/"+m.get("id")+"/thumbnail")).toList());
  return out;
 }
 private Map<String,Object> detail(UUID actor,long id) {
  var row=authorize(actor,id);var all=repo.page(actor,((Number)row.get("postId")).longValue(),(Long)row.get("parentCommentId"),row.get("parentCommentId")==null?id+1:id-1,1);
  if(all.isEmpty()) throw ApiException.notFound();return project(actor,all.get(0),repo.media(List.of(id)));
 }
 @Transactional public Map<String,Object> create(UUID actor,long post,CommentDtos.Create req) {
  length(req.body(),2000);
  if(req.clientRequestId()==null || req.mediaIds()==null || req.mediaIds().size()>6 || req.mediaIds().stream().anyMatch(Objects::isNull) || new HashSet<>(req.mediaIds()).size()!=req.mediaIds().size() || (req.body().isBlank() && req.mediaIds().isEmpty())) throw ApiException.bad("Bình luận cần nội dung hoặc từ 1 đến 6 ảnh.");
  lock(actor,post);
  String hash;
  try {hash=PostService.digest(json.writeValueAsBytes(Arrays.asList(post,req.body(),req.parentId(),req.mediaIds())));}catch(Exception e) {throw new IllegalStateException(e);}
  var existing=repo.existing(actor,req.clientRequestId());
  if(!existing.isEmpty()) {var row=existing.get(0);if(!hash.equals(row.get("requestHash"))) throw new ApiException(409,"COMMENT_KEY_REUSED","Mã gửi đã được dùng cho nội dung khác.");return detail(actor,((Number)row.get("id")).longValue());}
  Long root=null;UUID replyTo=null;
  if(req.parentId()!=null) {
   var parent=authorize(actor,req.parentId());if(((Number)parent.get("postId")).longValue()!=post) throw ApiException.bad("Bình luận gốc không thuộc bài viết.");
   root=parent.get("parentCommentId")==null?req.parentId():((Number)parent.get("parentCommentId")).longValue();replyTo=(UUID)parent.get("userId");
   authorize(actor,root);
  }
  for(UUID id:req.mediaIds()) {var m=repo.media(id,true);if(!actor.equals(m.get("ownerId")) || ((Number)m.get("postId")).longValue()!=post) throw ApiException.notFound();if(!"READY".equals(m.get("state"))) throw new ApiException(409,"COMMENT_MEDIA_NOT_READY","Ảnh chưa sẵn sàng hoặc đã được dùng.");}
  boolean inserted=repo.insert(actor,post,req,hash,root,replyTo);
  var committed=repo.existing(actor,req.clientRequestId()).get(0);
  if(!hash.equals(committed.get("requestHash"))) throw new ApiException(409,"COMMENT_KEY_REUSED","Mã gửi đã được dùng cho nội dung khác.");
  long id=((Number)committed.get("id")).longValue();
  if(inserted) {
   for(int i=0;i<req.mediaIds().size();i++) repo.attach(req.mediaIds().get(i),id,i);
   UUID recipient=replyTo==null?(UUID)posts.authorize(actor,post).get("authorId"):replyTo;
   notifications.recordPostInteraction(recipient,actor,post,id,replyTo!=null);
  }
  return detail(actor,id);
 }
 @Transactional public Map<String,Object> like(UUID actor,long id,boolean value) {
  var c=authorize(actor,id);lock(actor,((Number)c.get("postId")).longValue());authorize(actor,id);
  repo.like(actor,id,value);
  return detail(actor,id);
 }
 @Transactional public void delete(UUID actor,long id) {
  var c=repo.row(id);lock(actor,((Number)c.get("postId")).longValue());if(!actor.equals(c.get("userId"))) throw ApiException.notFound();
  repo.delete(id);
 }
}
