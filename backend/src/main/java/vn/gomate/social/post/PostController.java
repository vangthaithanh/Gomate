package vn.gomate.social.post;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.net.*;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.auth.CurrentUser;
import vn.gomate.common.ApiException;

@RestController
@RequestMapping("/api/v1/posts")
public class PostController {
 private final PostService posts;
 private final PostMediaService media;
 private final PostRepository repo;
 private final vn.gomate.media.provider.ProtectedMediaOrigin origin;
 private final PostImageBuffer images;
 public PostController(PostService posts,PostMediaService media,PostRepository repo,vn.gomate.media.provider.ProtectedMediaOrigin origin,PostImageBuffer images) {this.posts=posts;this.media=media;this.repo=repo;this.origin=origin;this.images=images;}
 @PostMapping @ResponseStatus(HttpStatus.CREATED)
 public PostDtos.Detail publish(@Valid @RequestBody PostDtos.Publish body) {return posts.publish(CurrentUser.id(),body);}
 @GetMapping("/{postId}")
 public PostDtos.Detail detail(@PathVariable long postId) {return posts.detail(CurrentUser.id(),postId);}
 @PutMapping("/{postId}/pin") public PostDtos.Detail pin(@PathVariable long postId) {return posts.pin(CurrentUser.id(),postId,true);}
 @DeleteMapping("/{postId}/pin") public PostDtos.Detail unpin(@PathVariable long postId) {return posts.pin(CurrentUser.id(),postId,false);}
 @PatchMapping("/{postId}/audience") public PostDtos.Detail audience(@PathVariable long postId,@Valid @RequestBody PostDtos.Audience body) {return posts.audience(CurrentUser.id(),postId,body.audience());}
 @DeleteMapping("/{postId}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(@PathVariable long postId) {posts.delete(CurrentUser.id(),postId);}
 @PostMapping(value="/media",consumes="multipart/form-data")
 public PostDtos.Uploaded upload(@RequestParam UUID uploadId,@RequestParam String kind,@RequestPart("file") MultipartFile file) {
  return media.upload(CurrentUser.id(),uploadId,kind,file);
 }
 @GetMapping({"/{postId}/media/{mediaId}","/{postId}/media/{mediaId}/thumbnail"})
 public void binary(@PathVariable long postId,@PathVariable UUID mediaId,
  jakarta.servlet.http.HttpServletRequest request,HttpServletResponse response) throws Exception {
  posts.authorize(CurrentUser.id(),postId);
  var row=repo.media(mediaId,false);
  if(row.get("postId")==null || ((Number)row.get("postId")).longValue()!=postId || !"ATTACHED".equals(row.get("state"))) throw ApiException.notFound();
  boolean thumbnail=request.getRequestURI().endsWith("/thumbnail");
  String requestedRange=request.getHeader("Range");
  boolean buffered=requestedRange==null && (thumbnail || "IMAGE".equals(row.get("kind")));
  String key=mediaId+":"+thumbnail+":"+row.get(thumbnail?"thumbnailPublicId":"publicId");
  // Permission and attachment checks above run even on a warm binary buffer hit.
  try(var body=buffered
    ? images.open(key,()->origin.open(media.delivery(row,thumbnail),null))
    : origin.open(media.delivery(row,thumbnail),requestedRange)) {
   long total=body.total();
   long start=0,end=total-1;
   String range=request.getHeader("Range");
   if(range!=null) {
    var match=java.util.regex.Pattern.compile("bytes=(\\d*)-(\\d*)").matcher(range);
    if(!match.matches() || (match.group(1).isEmpty() && match.group(2).isEmpty())) {response.setStatus(416);response.setHeader("Content-Range","bytes */"+total);return;}
    try {
     if(match.group(1).isEmpty()) start=Math.max(0,total-Long.parseLong(match.group(2)));
     else start=Long.parseLong(match.group(1));
     if(!match.group(1).isEmpty() && !match.group(2).isEmpty()) end=Math.min(end,Long.parseLong(match.group(2)));
     if(start>end || start>=total) throw new IllegalArgumentException();
    } catch(Exception e) {response.setStatus(416);response.setHeader("Content-Range","bytes */"+total);return;}
    response.setStatus(206);response.setHeader("Content-Range","bytes "+start+"-"+end+"/"+total);
   }
   response.setContentType(thumbnail?"image/jpeg":(String)row.get("mimeType"));
   response.setHeader("Cache-Control","private, no-store, max-age=0");response.setHeader("Pragma","no-cache");
   response.setHeader("X-Content-Type-Options","nosniff");response.setHeader("Accept-Ranges","bytes");response.setContentLengthLong(end-start+1);
   try(var input=body.stream()) {
    if(body.offset()>start) throw new IllegalStateException("Invalid origin offset");
    input.skipNBytes(start-body.offset());
    var output=response.getOutputStream();byte[] buffer=new byte[32768];long remaining=end-start+1;
    while(remaining>0) {int n=input.read(buffer,0,(int)Math.min(buffer.length,remaining));if(n<0)break;output.write(buffer,0,n);remaining-=n;}
   }
  } catch(Exception e) {
   if(!response.isCommitted()) throw new ApiException(503,"POST_MEDIA_UNAVAILABLE","Không tải được media bài viết.");
  }
 }
}
