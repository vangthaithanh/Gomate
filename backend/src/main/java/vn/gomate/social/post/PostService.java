package vn.gomate.social.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.text.Normalizer;
import java.time.*;
import java.util.*;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.relationship.service.SocialRelationshipService;
import static vn.gomate.common.Db.args;

@Service
public class PostService {
 private final PostRepository repo;
 private final SocialRelationshipService relationships;
 private final ObjectMapper json;
 private final PostFeedRepository feedRepo;
 public PostService(PostRepository repo,SocialRelationshipService relationships,ObjectMapper json,PostFeedRepository feedRepo) {
  this.repo=repo; this.relationships=relationships; this.json=json; this.feedRepo=feedRepo;
 }
 public static String digest(byte[] data) {
  try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data)); }
  catch(Exception e) { throw new IllegalStateException(e); }
 }
 public static List<String> normalizeTags(List<String> values) {
  if(values==null) throw ApiException.bad("Thiếu danh sách hashtag.");
  var tags=new TreeSet<String>();
  for(String raw:values) {
   if(raw==null) throw ApiException.bad("Hashtag không hợp lệ.");
   String tag=Normalizer.normalize(raw.strip(),Normalizer.Form.NFC).replaceFirst("^#+","").toLowerCase(Locale.ROOT);
   if(!tag.matches("[\\p{L}\\p{M}\\p{N}_]+")) throw ApiException.bad("Hashtag chỉ gồm chữ, số hoặc dấu gạch dưới.");
   tags.add(tag);
  }
  if(tags.size()>5) throw ApiException.bad("Mỗi bài tối đa 5 hashtag khác nhau.");
  return List.copyOf(tags);
 }
 @Transactional
 public PostDtos.Detail publish(UUID owner,PostDtos.Publish req) {
  if(req.clientRequestId()==null || req.caption()==null || Pattern.compile("\\X").matcher(req.caption()).results().limit(2201).count()>2200)
   throw ApiException.bad("Chú thích tối đa 2200 ký tự.");
  if(req.mediaIds()==null || req.mediaIds().isEmpty() || req.mediaIds().size()>12 || new HashSet<>(req.mediaIds()).size()!=req.mediaIds().size() || req.mediaIds().contains(null))
   throw ApiException.bad("Chọn từ 1 đến 12 media khác nhau.");
  List<String> tags=normalizeTags(req.hashtags());
  if(req.taggedUserIds()==null || req.taggedUserIds().contains(null)) throw ApiException.bad("Người được gắn thẻ không hợp lệ.");
  var people=req.taggedUserIds().stream().distinct().sorted().toList();
  String hash;
  try { hash=digest(json.writeValueAsBytes(Arrays.asList(req.caption(),req.audience(),req.mediaIds(),tags,people,req.placeId()))); }
  catch(Exception e) { throw new IllegalStateException(e); }
  try {
   relationships.lockInteractions(owner,people);
  } catch(ApiException error) {
   // A missing tagged account has no settings row to lock. Keep this translation
   // scoped to lock failure; blocked-user checks and idempotent replay stay below.
   if(error.status==404 && repo.validUser(owner) && people.stream().anyMatch(user -> !repo.validUser(user)))
    throw new ApiException(422,"INVALID_TAGGED_USER","Người được gắn thẻ không còn khả dụng.");
   throw error;
  }
  String visibility=repo.lockAccount(owner);
  var existing=repo.published(owner,req.clientRequestId());
  if(existing.isPresent()) {
   if(!hash.equals(existing.get().get("requestHash"))) throw new ApiException(409,"PUBLISH_KEY_REUSED","Mã đăng bài đã được dùng cho nội dung khác.");
   return detail(owner,((Number)existing.get().get("id")).longValue());
  }
  boolean privateAccount="PRIVATE".equals(visibility);
  if(!Set.of(privateAccount?"FOLLOWERS":"EVERYONE","FRIENDS","ONLY_ME").contains(req.audience()))
   throw new ApiException(422,"INVALID_POST_AUDIENCE","Đối tượng xem không phù hợp quyền riêng tư hiện tại. Hãy chọn lại.");
  if(req.placeId()!=null && !repo.validPlace(req.placeId()))
   throw new ApiException(422,"INVALID_PLACE","Địa điểm không còn khả dụng.");
  for(UUID person:people) relationships.requireInteraction(owner,person);
  for(UUID user:people) if(!repo.validUser(user))
   throw new ApiException(422,"INVALID_TAGGED_USER","Người được gắn thẻ không còn khả dụng.");
  for(UUID media:req.mediaIds()) {
   var row=repo.media(media,true);
   if(!owner.equals(row.get("ownerId"))) throw ApiException.notFound();
   if(!"READY".equals(row.get("state")) || row.get("postId")!=null) throw new ApiException(409,"MEDIA_NOT_READY","Media chưa sẵn sàng hoặc đã được dùng.");
   if("VIDEO".equals(row.get("kind")) && (row.get("durationMs")==null || ((Number)row.get("durationMs")).longValue()>30000))
    throw new ApiException(422,"POST_VIDEO_DURATION","Video mới phải được cắt còn tối đa 30 giây.");
  }
  long id=repo.insert(owner,req,hash,Set.of("EVERYONE","FOLLOWERS").contains(req.audience())?"ACCOUNT":req.audience());
  for(int i=0;i<req.mediaIds().size();i++) repo.attach(req.mediaIds().get(i),id,i);
  for(String tag:tags) repo.tag(id,tag);
  for(UUID person:people) repo.tagUser(id,person);
  return detail(owner,id);
 }
 public Map<String,Object> authorize(UUID viewer,long id) {
  var post=repo.post(id);
  UUID owner=(UUID)post.get("authorId");
  relationships.requireInteraction(viewer,owner);
  if(!"ACTIVE".equals(post.get("authorStatus")) || post.get("deletedAt")!=null) throw ApiException.notFound();
  String audience=effective(post);
  boolean allowed=viewer.equals(owner) || "EVERYONE".equals(audience)
   || ("FOLLOWERS".equals(audience) && relationships.isFollowing(viewer,owner))
   || ("FRIENDS".equals(audience) && relationships.isMutualFriend(viewer,owner));
  if(!allowed) throw ApiException.notFound();
  return post;
 }
 public void lockShareInteraction(UUID actor,long id,UUID recipient) {
  var author=(UUID)repo.post(id).get("authorId");
  var ids=new ArrayList<UUID>();ids.add(author);if(recipient!=null) ids.add(recipient);
  relationships.lockInteractions(actor,ids);
  authorize(actor,id);
 }
 public void lockInteraction(UUID actor,long id) {
  var post=repo.post(id);relationships.lockInteraction(actor,(UUID)post.get("authorId"));
 }
 public String effective(Map<String,Object> post) {
  String value=(String)post.get("audience");
  return "ACCOUNT".equals(value)?("PRIVATE".equals(post.get("accountVisibility"))?"FOLLOWERS":"EVERYONE"):value;
 }
 public PostDtos.Detail detail(UUID viewer,long id) {
  var post=authorize(viewer,id);
  return project(post,repo.mediaFor(id),repo.tags(id),relationships.visiblePeople(viewer,repo.people(id)),feedRepo.engagement(viewer,id));
 }
 public PostDtos.Detail project(Map<String,Object> post,List<Map<String,Object>> rows,List<String> tags,List<UUID> people,PostDtos.Engagement stats) {
  long id=((Number)post.get("id")).longValue();
  Object time=post.get("createdAt");
  OffsetDateTime created=time instanceof OffsetDateTime t?t:((LocalDateTime)time).atOffset(ZoneOffset.UTC);
  var media=rows.stream().map(r -> new PostDtos.Media((UUID)r.get("id"),(String)r.get("kind"),(String)r.get("mimeType"),
   ((Number)r.get("bytes")).longValue(),r.get("durationMs")==null?null:((Number)r.get("durationMs")).longValue(),
   ((Number)r.get("width")).intValue(),((Number)r.get("height")).intValue(),((Number)r.get("sortOrder")).intValue(),
   "/posts/"+id+"/media/"+r.get("id"),"/posts/"+id+"/media/"+r.get("id")+"/thumbnail")).toList();
  return new PostDtos.Detail(id,(UUID)post.get("authorId"),(String)(post.get("fullName")==null?post.get("nickname"):post.get("fullName")),
   (String)post.get("content"),effective(post),tags,people,post.get("placeId")==null?null:((Number)post.get("placeId")).longValue(),media,created,
   post.get("pinnedAt")!=null,instant(post.get("pinnedAt")),(String)post.get("avatarUrl"),(String)post.get("placeName"),stats.likeCount(),stats.likedByMe(),stats.savedByMe(),stats.commentCount());
 }
 public static OffsetDateTime instant(Object value) {return value==null?null:value instanceof OffsetDateTime t?t:((LocalDateTime)value).atOffset(ZoneOffset.UTC);}
 public record Cursor(int rank,OffsetDateTime time,OffsetDateTime created,long id,UUID author,UUID viewer) {}
 public PostDtos.Page list(UUID viewer,UUID author,int size,String token) {
  relationships.requireInteraction(viewer,author);
  if(size<1 || size>50) throw ApiException.bad("Kích thước trang từ 1 đến 50.");
  Cursor cursor=null;
  if(token!=null) try {
   cursor=json.readValue(Base64.getUrlDecoder().decode(token),Cursor.class);
   if(!author.equals(cursor.author()) || !viewer.equals(cursor.viewer()) || cursor.rank()<0 || cursor.rank()>1 || cursor.time()==null || cursor.created()==null || cursor.id()<1) throw new IllegalArgumentException();
  } catch(Exception e) {throw ApiException.bad("Con trỏ trang không hợp lệ.");}
  var rows=repo.profile(viewer,author,size+1,cursor);
  var items=new ArrayList<PostDtos.Detail>();
  // Recheck detail authorization in case privacy/follow changes between queries.
  for(var row:rows.subList(0,Math.min(size,rows.size()))) try {items.add(detail(viewer,((Number)row.get("id")).longValue()));}
   catch(ApiException e) {if(e.status!=404) throw e;}
  String next=null;
  if(rows.size()>size && !items.isEmpty()) try {
   var last=items.get(items.size()-1);var pinned=last.pinnedAt();var created=last.createdAt();
   next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(new Cursor(pinned==null?1:0,pinned==null?created:pinned,created,last.id(),author,viewer)));
  } catch(Exception e) {throw new IllegalStateException(e);}
  return new PostDtos.Page(List.copyOf(items),next);
 }
 private Map<String,Object> owned(UUID viewer,long id,boolean allowDeleted) {
  repo.lockAccount(viewer);
  var post=repo.post(id);
  if(!viewer.equals(post.get("authorId")) || (!allowDeleted && post.get("deletedAt")!=null)) throw ApiException.notFound();
  return post;
 }
 @Transactional public PostDtos.Detail pin(UUID viewer,long id,boolean value) {
  var post=owned(viewer,id,false);
  if(value && post.get("pinnedAt")==null) {
   if(repo.pinnedCount(viewer)>=3) throw new ApiException(422,"POST_PIN_LIMIT","Chỉ được ghim tối đa 3 bài viết. Bỏ ghim bài cũ trước.");
   repo.pin(id,true);
  } else if(!value) repo.pin(id,false);
  return detail(viewer,id);
 }
 @Transactional public PostDtos.Detail audience(UUID viewer,long id,String value) {
  var post=owned(viewer,id,false);
  boolean privateAccount="PRIVATE".equals(post.get("accountVisibility"));
  if(value==null || !Set.of(privateAccount?"FOLLOWERS":"EVERYONE","FRIENDS","ONLY_ME").contains(value))
   throw new ApiException(422,"INVALID_POST_AUDIENCE","Đối tượng xem không phù hợp quyền riêng tư hiện tại.");
  repo.audience(id,Set.of("EVERYONE","FOLLOWERS").contains(value)?"ACCOUNT":value);
  return detail(viewer,id);
 }
 @Transactional public void delete(UUID viewer,long id) {owned(viewer,id,true);repo.delete(id);}
}
