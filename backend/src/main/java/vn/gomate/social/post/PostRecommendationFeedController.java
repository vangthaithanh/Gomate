package vn.gomate.social.post;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import vn.gomate.auth.CurrentUser;

@RestController
@RequestMapping("/api/v1")
public class PostRecommendationFeedController {
    private final PostRecommendationFeedService service;

    public PostRecommendationFeedController(PostRecommendationFeedService service) { this.service = service; }

    @GetMapping("/feed/recommended")
    public PostDtos.Page feed(
        @RequestParam(defaultValue = "20") int size,
        @RequestParam(required = false) String cursor,
        @RequestParam(required = false) String destinationKey,
        @RequestParam(required = false) Double latitude,
        @RequestParam(required = false) Double longitude
    ) {
        return service.feed(CurrentUser.id(), size, cursor, destinationKey, latitude, longitude);
    }

    @PutMapping("/feed/recommended/{postId}/view")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void viewed(@PathVariable long postId) {
        service.viewed(CurrentUser.id(), postId);
    }
}
