package vn.gomate.social.post;

import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;

@RestController
@RequestMapping("/api/v1/me")
public class PostActivityController {
    private final PostActivityService service;
    public PostActivityController(PostActivityService service) { this.service=service; }
    @GetMapping("/liked-posts")
    public PostActivityService.Page likes(@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
        return service.list(CurrentUser.id(),"LIKES",size,cursor);
    }
    @GetMapping("/saved-posts")
    public PostActivityService.Page saves(@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
        return service.list(CurrentUser.id(),"SAVES",size,cursor);
    }
    @GetMapping("/comments")
    public PostActivityService.Page comments(@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
        return service.list(CurrentUser.id(),"COMMENTS",size,cursor);
    }
}
