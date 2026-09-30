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
        @RequestParam(required = false) Double latitude,
        @RequestParam(required = false) Double longitude,
        @RequestParam(defaultValue = "10") int topK
    ) {
        return service.mine(CurrentUser.id(), latitude, longitude, topK);
    }
}
