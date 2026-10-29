package vn.gomate.social.comment;

import java.nio.file.*;
import java.security.*;
import java.time.*;
import java.util.*;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.common.ApiException;
import vn.gomate.media.service.MediaService;
import vn.gomate.media.model.MediaResourceType;
import vn.gomate.social.post.*;

@Service
public class CommentMediaService {
 private final CommentRepository repo;
 private final CommentService comments;
 private final PostFileInspector inspector;
 private final ObjectProvider<MediaService> providers;
 private final TransactionTemplate tx;
 public CommentMediaService(CommentRepository repo,CommentService comments,PostFileInspector inspector,ObjectProvider<MediaService> providers,org.springframework.transaction.PlatformTransactionManager tm) {this.repo=repo;this.comments=comments;this.inspector=inspector;this.providers=providers;this.tx=new TransactionTemplate(tm);}
 private MediaService provider() {var p=providers.getIfAvailable();if(p==null) throw new ApiException(503,"COMMENT_MEDIA_UNAVAILABLE","Dịch vụ ảnh chưa khả dụng.");return p;}
 public Map<String,Object> upload(UUID actor,long post,UUID id,MultipartFile input) {
  if(input==null || input.isEmpty()) throw ApiException.bad("Thiếu ảnh bình luận.");
  if(input.getSize()>10000000) throw new ApiException(413,"COMMENT_IMAGE_TOO_LARGE","Ảnh tối đa 10 MB.");
  Path file=null,cover=null;
  String pid="gomate/comments/"+actor+"/"+id;
  try {
   file=Files.createTempFile("gomate-comment-",".media");input.transferTo(file);
   var meta=inspector.inspect(file,"IMAGE",input.getContentType());String hash;
   try(var stream=new DigestInputStream(Files.newInputStream(file),MessageDigest.getInstance("SHA-256"))) {stream.transferTo(java.io.OutputStream.nullOutputStream());hash=HexFormat.of().formatHex(stream.getMessageDigest().digest());}
   final String digest=hash;
   var ready=tx.execute(status->{
    comments.lock(actor,post);
    var rows=repo.existingMedia(id);
    if(!rows.isEmpty()) {var m=rows.get(0);if(!actor.equals(m.get("ownerId")) || ((Number)m.get("postId")).longValue()!=post) throw ApiException.notFound();if(!digest.equals(m.get("contentHash"))) throw new ApiException(409,"UPLOAD_KEY_REUSED","Mã tải ảnh đã được dùng cho tệp khác.");if(!Set.of("READY","ATTACHED").contains(m.get("state"))) throw new ApiException(409,"COMMENT_MEDIA_BUSY","Ảnh đang được xử lý hoặc dọn dẹp.");return m;}
    repo.reserve(actor,post,id,digest,pid);return null;
   });
   if(ready!=null) return Map.of("mediaId",id);
   try {
    cover=Files.createTempFile("gomate-comment-cover-",".jpg");inspector.thumbnail(file,cover);
    var actual=provider().uploadProtected(file.toFile(),pid,MediaResourceType.IMAGE);
    if(actual.format()==null || actual.format().isBlank() || actual.bytes()==null || actual.bytes()<=0 || actual.bytes()>10000000 || actual.width()==null || actual.width()<=0 || actual.height()==null || actual.height()<=0) throw ApiException.bad("Nhà cung cấp chưa xác nhận ảnh hợp lệ.");
    provider().uploadProtected(cover.toFile(),pid+"_cover",MediaResourceType.IMAGE);
    tx.executeWithoutResult(status->repo.ready(id,meta,actual));
    return Map.of("mediaId",id);
   } catch(Exception e) {
    try {repo.markCleanup(id);cleanup(id);}catch(Exception ignored) {org.slf4j.LoggerFactory.getLogger(getClass()).warn("Comment cleanup pending publicId={}",pid);}
    if(e instanceof ApiException a) throw a;throw new ApiException(503,"COMMENT_UPLOAD_FAILED","Không tải được ảnh; bản nháp được giữ nguyên.");
   }
  } catch(ApiException e) {throw e;}catch(Exception e) {throw new ApiException(503,"COMMENT_UPLOAD_FAILED","Không chuẩn bị được ảnh bình luận.");}
  finally {for(Path p:new Path[]{file,cover}) if(p!=null) try {Files.deleteIfExists(p);}catch(Exception ignored){}}
 }
 public String delivery(Map<String,Object> m,boolean cover) {return provider().protectedDownload((String)m.get(cover?"thumbnailPublicId":"publicId"),cover?"jpg":(String)m.get("format"),MediaResourceType.IMAGE);}
 public void cleanup(UUID id) {
  tx.executeWithoutResult(status->{
   var m=repo.media(id,true);
   if(m.get("cleanedAt")!=null) return;
   if(m.get("commentId")!=null) {if(!repo.deleted(m.get("commentId"))) return;}
   else if(!"CLEANUP".equals(m.get("state"))) return;
   provider().deleteProtected((String)m.get("publicId"),MediaResourceType.IMAGE);provider().deleteProtected((String)m.get("thumbnailPublicId"),MediaResourceType.IMAGE);
   repo.cleaned(id,m.get("commentId")!=null);
  });
 }
 @Scheduled(initialDelay=900000,fixedDelay=900000) public void reconcile() {
  var rows=repo.expired(OffsetDateTime.now(ZoneOffset.UTC).minusHours(24));
  for(var r:rows) {var id=(UUID)r.get("id");try {repo.markCleanup(id);cleanup(id);}catch(Exception e) {org.slf4j.LoggerFactory.getLogger(getClass()).warn("Comment media cleanup retry mediaId={}",id);}}
 }
}
