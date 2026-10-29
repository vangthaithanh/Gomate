package vn.gomate.social.post;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.user.service.RecentSearchService;

@RestController
@RequestMapping("/api/v1/search")
public class PostSearchController {
    private final PostSearchService posts;
    private final RecentSearchService recent;
    public PostSearchController(PostSearchService posts,RecentSearchService recent) {this.posts=posts;this.recent=recent;}
    @GetMapping("/posts") public PostSearchService.Page posts(@RequestParam(defaultValue="") String q,@RequestParam(defaultValue="") List<String> hashtags,@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
        return posts.search(CurrentUser.id(),q,hashtags,size,cursor);
    }
    @GetMapping("/hashtags") public List<Map<String,Object>> tags(@RequestParam(defaultValue="") String q) {return posts.hashtags(CurrentUser.id(),q);}
    public record Query(@NotBlank @Size(max=200) String query) {}
    @GetMapping("/recent") public List<String> recent() {return recent.list(CurrentUser.id());}
    @PostMapping("/recent") public List<String> submit(@Valid @RequestBody Query query) {return recent.submit(CurrentUser.id(),query.query());}
    @DeleteMapping("/recent") public void remove(@RequestParam String q) {recent.remove(CurrentUser.id(),q);}
}
