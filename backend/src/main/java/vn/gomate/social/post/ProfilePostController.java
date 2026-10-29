package vn.gomate.social.post;

import java.util.UUID;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;

@RestController
@RequestMapping("/api/v1/users/{authorId}/posts")
public class ProfilePostController {
 private final PostService posts;
 public ProfilePostController(PostService posts) {this.posts=posts;}
 @GetMapping public PostDtos.Page list(@PathVariable UUID authorId,@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
  return posts.list(CurrentUser.id(),authorId,size,cursor);
 }
}
