package vn.gomate.social.post;

import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.scheduling.annotation.*;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.common.ApiException;
import vn.gomate.media.service.MediaService;
import vn.gomate.media.model.MediaResourceType;
import static vn.gomate.common.Db.args;

@Service
@EnableScheduling
public class PostMediaService {
 private final PostRepository repo;
 private final PostFileInspector inspector;
 private final ObjectProvider<MediaService> providers;
 private final TransactionTemplate tx;
 public PostMediaService(PostRepository repo,PostFileInspector inspector,ObjectProvider<MediaService> providers,org.springframework.transaction.PlatformTransactionManager tm) {
  this.repo=repo;this.inspector=inspector;this.providers=providers;this.tx=new TransactionTemplate(tm);
 }
 private MediaService media() {
  var service=providers.getIfAvailable();
  if(service==null) throw new ApiException(503,"POST_MEDIA_UNAVAILABLE","Dịch vụ media chưa được cấu hình.");
  return service;
 }
 public PostDtos.Uploaded upload(UUID owner,UUID id,String kind,MultipartFile input) {
  if(input==null || input.isEmpty()) throw ApiException.bad("Thiếu tệp media.");
  if(input.getSize()>("VIDEO".equals(kind)?100000000:10000000)) throw new ApiException(413,"POST_MEDIA_TOO_LARGE","Ảnh tối đa 10 MB, video tối đa 100 MB.");
  Path source=null,thumb=null;
  try {
   source=Files.createTempFile("gomate-post-",".media"); input.transferTo(source);
   var meta=inspector.inspect(source,kind,input.getContentType());
   String hash;
   try(var in=new DigestInputStream(Files.newInputStream(source),MessageDigest.getInstance("SHA-256"))) {
    in.transferTo(java.io.OutputStream.nullOutputStream());hash=HexFormat.of().formatHex(in.getMessageDigest().digest());
   }
   final String contentHash=hash;
   var ready=tx.execute(status -> {
    repo.lockAccount(owner);
    var rows=repo.existingMedia(id);
    if(!rows.isEmpty()) {
     var row=rows.get(0);
     if(!owner.equals(row.get("ownerId"))) throw ApiException.notFound();
     if(!contentHash.equals(row.get("contentHash")) || !kind.equals(row.get("kind"))) throw new ApiException(409,"UPLOAD_KEY_REUSED","Mã tải media đã dùng cho tệp khác.");
     if(!Set.of("READY","ATTACHED").contains(row.get("state"))) throw new ApiException(409,"POST_MEDIA_BUSY","Media đang được xử lý hoặc dọn dẹp; vui lòng thử lại.");
     return row;
    }
    repo.reserve(id,owner,contentHash,kind,publicId(owner,id));
    return null;
   });
   if(ready!=null) return uploaded(ready);
   try {
    thumb=Files.createTempFile("gomate-post-cover-",".jpg");inspector.thumbnail(source,thumb);
    var type=type(kind);
    var actual=media().uploadProtected(source.toFile(),publicId(owner,id),type);
    if(actual.format()==null || actual.format().isBlank() || actual.bytes()==null || actual.bytes()<=0 || actual.bytes()>(type==MediaResourceType.VIDEO?100000000L:10000000L) || actual.width()==null || actual.width()<=0 || actual.height()==null || actual.height()<=0 || (type==MediaResourceType.VIDEO && (actual.durationSeconds()==null || !Double.isFinite(actual.durationSeconds()) || actual.durationSeconds()<=0 || actual.durationSeconds()>30)))
     throw new ApiException(422,"POST_MEDIA_METADATA","Nhà cung cấp không xác nhận được media hợp lệ.");
    media().uploadProtected(thumb.toFile(),publicId(owner,id)+"_cover",MediaResourceType.IMAGE);
    tx.executeWithoutResult(status -> repo.ready(id,actual.format(),meta,actual.bytes()));
    return uploaded(repo.media(id,false));
   } catch(Exception e) {
    try {tx.executeWithoutResult(status -> repo.markCleanup(id));cleanup(id);}
    catch(Exception cleanup) {LoggerFactory.getLogger(getClass()).warn("Post media cleanup pending publicId={}",publicId(owner,id));}
    if(e instanceof ApiException api) throw api;
    throw new ApiException(503,"POST_MEDIA_UPLOAD_FAILED","Tải media thất bại; nội dung nháp được giữ nguyên.");
   }
  } catch(ApiException e) {throw e;}
  catch(Exception e) {throw new ApiException(503,"POST_MEDIA_PREPARATION_FAILED","Không chuẩn bị được media.");}
  finally {for(Path file:new Path[]{source,thumb}) if(file!=null) try {Files.deleteIfExists(file);}catch(Exception ignored){}}
 }
 private PostDtos.Uploaded uploaded(Map<String,Object> row) {
  return new PostDtos.Uploaded((UUID)row.get("id"),(String)row.get("kind"),row.get("durationMs")==null?null:((Number)row.get("durationMs")).longValue(),((Number)row.get("bytes")).longValue());
 }
 public static MediaResourceType type(String kind) {return "VIDEO".equals(kind)?MediaResourceType.VIDEO:MediaResourceType.IMAGE;}
 private String publicId(UUID owner,UUID id) {return "gomate/posts/"+owner+"/"+id;}
 public String delivery(Map<String,Object> row,boolean thumbnail) {
  return media().protectedDownload((String)row.get(thumbnail?"thumbnailPublicId":"publicId"),thumbnail?"jpg":(String)row.get("format"),thumbnail?MediaResourceType.IMAGE:type((String)row.get("kind")));
 }
 public void cleanup(UUID id) {
  tx.executeWithoutResult(status -> {
   var row=repo.media(id,true);
   boolean deleted=row.get("postId")!=null && repo.deleted(((Number)row.get("postId")).longValue());
   if(deleted && row.get("cleanedAt")!=null) return;
   if(!deleted && (row.get("postId")!=null || !"CLEANUP".equals(row.get("state")))) return;
   media().deleteProtected((String)row.get("publicId"),type((String)row.get("kind")));
   media().deleteProtected((String)row.get("thumbnailPublicId"),MediaResourceType.IMAGE);
   if(deleted) repo.cleaned(id); else repo.deleteCleanup(id);
  });
 }
 @Scheduled(initialDelay=900000,fixedDelay=900000)
 public void reconcile() {
  var expired=repo.expired(OffsetDateTime.now(ZoneOffset.UTC).minusHours(24));
  for(var row:expired) {
   UUID id=(UUID)row.get("id");
   try {tx.executeWithoutResult(status -> repo.markCleanup(id));cleanup(id);}
   catch(Exception e) {LoggerFactory.getLogger(getClass()).warn("Post staging cleanup retry mediaId={}",id);}
  }
 }
}
