package vn.gomate.recommendation.controller;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vn.gomate.auth.CurrentUser;
import vn.gomate.recommendation.service.RecommendationService;

@RestController
@RequestMapping("/api/v1/recommendations")
public class RecommendationController {
    private final RecommendationService service;

    public RecommendationController(RecommendationService service) {
        this.service = service;
    }

    @GetMapping("/me")
    public Map<String, Object> mine(
        @RequestParam(required = false) String destinationKey,
        @RequestParam(required = false) Double latitude,
        @RequestParam(required = false) Double longitude,
        @RequestParam(required = false) Integer topK
    ) {
        return service.mine(CurrentUser.id(), destinationKey, latitude, longitude, topK);
    }

    @GetMapping("/home")
    public Map<String, Object> home(
        @RequestParam(required = false) String destinationKey,
        @RequestParam(required = false) Double latitude,
        @RequestParam(required = false) Double longitude,
        @RequestParam(required = false) Integer topK
    ) {
        return service.mine(CurrentUser.id(), destinationKey, latitude, longitude, topK);
    }
}
