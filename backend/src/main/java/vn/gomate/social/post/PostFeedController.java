package vn.gomate.social.post;

import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;

@RestController
@RequestMapping("/api/v1")
public class PostFeedController {
    private final PostFeedService service;
    public PostFeedController(PostFeedService service) {this.service=service;}
    @GetMapping("/feed") public PostDtos.Page feed(@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
        return service.feed(CurrentUser.id(),size,cursor);
    }
    @PutMapping("/posts/{id}/like") public PostDtos.Engagement like(@PathVariable long id) {return service.set(CurrentUser.id(),id,true,true);}
    @GetMapping("/posts/{id}/likes") public PostDtos.LikersPage likers(@PathVariable long id,@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
        return service.likers(CurrentUser.id(),id,size,cursor);
    }
    @DeleteMapping("/posts/{id}/like") public PostDtos.Engagement unlike(@PathVariable long id) {return service.set(CurrentUser.id(),id,true,false);}
    @PutMapping("/posts/{id}/save") public PostDtos.Engagement save(@PathVariable long id) {return service.set(CurrentUser.id(),id,false,true);}
    @DeleteMapping("/posts/{id}/save") public PostDtos.Engagement unsave(@PathVariable long id) {return service.set(CurrentUser.id(),id,false,false);}
}
