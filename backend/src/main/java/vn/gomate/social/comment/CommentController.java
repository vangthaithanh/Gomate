package vn.gomate.social.comment;

import java.util.*;
import jakarta.validation.Valid;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.auth.CurrentUser;
import vn.gomate.common.ApiException;
import vn.gomate.social.post.*;
import vn.gomate.media.provider.ProtectedMediaOrigin;

@RestController @RequestMapping("/api/v1")
public class CommentController {
 private final CommentService service;
 private final CommentRepository repo;
 private final CommentMediaService media;
 private final ProtectedMediaOrigin origin;
 private final PostImageBuffer images;
 public CommentController(CommentService service,CommentRepository repo,CommentMediaService media,ProtectedMediaOrigin origin,PostImageBuffer images) {this.service=service;this.repo=repo;this.media=media;this.origin=origin;this.images=images;}
 @GetMapping("/posts/{postId}/comments") public CommentDtos.Page list(@PathVariable long postId,@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {return service.list(CurrentUser.id(),postId,null,size,cursor);}
 @GetMapping("/comments/{id}/replies") public CommentDtos.Page replies(@PathVariable long id,@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {var c=service.authorize(CurrentUser.id(),id);return service.list(CurrentUser.id(),((Number)c.get("postId")).longValue(),id,size,cursor);}
 @PostMapping("/posts/{postId}/comments") @ResponseStatus(org.springframework.http.HttpStatus.CREATED) public Map<String,Object> create(@PathVariable long postId,@Valid @RequestBody CommentDtos.Create body) {return service.create(CurrentUser.id(),postId,body);}
 @DeleteMapping("/comments/{id}") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT) public void delete(@PathVariable long id) {service.delete(CurrentUser.id(),id);}
 @PutMapping("/comments/{id}/like") public Map<String,Object> like(@PathVariable long id) {return service.like(CurrentUser.id(),id,true);}
 @DeleteMapping("/comments/{id}/like") public Map<String,Object> unlike(@PathVariable long id) {return service.like(CurrentUser.id(),id,false);}
 @PostMapping(value="/posts/{postId}/comments/media",consumes="multipart/form-data") public Map<String,Object> upload(@PathVariable long postId,@RequestParam UUID uploadId,@RequestPart("file") MultipartFile file) {return media.upload(CurrentUser.id(),postId,uploadId,file);}
 @GetMapping({"/comments/{id}/media/{mediaId}","/comments/{id}/media/{mediaId}/thumbnail"}) public void binary(@PathVariable long id,@PathVariable UUID mediaId,jakarta.servlet.http.HttpServletRequest request,HttpServletResponse response) throws Exception {
  var c=service.authorize(CurrentUser.id(),id);var m=repo.media(mediaId);
  if(!Objects.equals(m.get("commentId"),c.get("id")) || !"ATTACHED".equals(m.get("state"))) throw ApiException.notFound();
  boolean cover=request.getRequestURI().endsWith("/thumbnail");
  try(var body=images.open("comment:"+mediaId+":"+cover,()->origin.open(media.delivery(m,cover),null))) {
   response.setContentType(cover?"image/jpeg":(String)m.get("mimeType"));response.setHeader("Cache-Control","private, no-store, max-age=0");response.setHeader("Pragma","no-cache");response.setHeader("X-Content-Type-Options","nosniff");response.setContentLengthLong(body.total());
   body.stream().transferTo(response.getOutputStream());
  }catch(Exception e) {if(!response.isCommitted()) throw new ApiException(503,"COMMENT_MEDIA_UNAVAILABLE","Không tải được ảnh bình luận.");}
 }
}
