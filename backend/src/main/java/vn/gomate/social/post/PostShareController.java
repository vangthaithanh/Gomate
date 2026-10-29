package vn.gomate.social.post;

import jakarta.validation.Valid;
import java.util.*;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;

@RestController
@RequestMapping("/api/v1/posts/{postId}")
public class PostShareController {
    private final PostShareService share;
    public PostShareController(PostShareService share) {this.share=share;}
    @GetMapping("/share-targets") public List<Map<String,Object>> targets(@PathVariable long postId,@RequestParam(defaultValue="") String q) {return share.targets(CurrentUser.id(),postId,q);}
    @PostMapping("/shares") public List<PostShareDtos.Result> share(@PathVariable long postId,@Valid @RequestBody PostShareDtos.Share request) {
        return share.send(CurrentUser.id(),postId,request);
    }
}
