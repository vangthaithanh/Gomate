package vn.gomate.recommendation.service;

import java.math.BigDecimal;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ContextualRecommendationRerankerTest {
    private final ContextualRecommendationReranker reranker =
        new ContextualRecommendationReranker(0.75, 0.25, 20);

    @Test
    void ganToiBoostsCloserPlaceWithoutFilteringFarPlace() {
        var farButSemantic = item(1, "semantic-far", 0.80, 21.0285, 105.8542);
        var closeAndSemantic = item(2, "semantic-close", 0.76, 10.3460, 107.0843);

        var ranked = reranker.rerank(
            List.of(farButSemantic, closeAndSemantic),
            List.of("GAN_TOI"),
            10.3450,
            107.0840
        );

        assertEquals(2, ranked.size());
        assertEquals(2, ranked.get(0).get("placeId"));
        assertEquals(1, ranked.get(1).get("placeId"));
        assertNotNull(ranked.get(1).get("recommendation"));
    }

    @Test
    void ganToiWithoutGpsKeepsSemanticOrder() {
        var bestSemantic = item(1, "semantic-best", 0.80, 21.0285, 105.8542);
        var lowerSemantic = item(2, "semantic-lower", 0.76, 10.3460, 107.0843);

        var ranked = reranker.rerank(
            List.of(bestSemantic, lowerSemantic),
            List.of("GAN_TOI"),
            null,
            null
        );

        assertEquals(1, ranked.get(0).get("placeId"));
        assertEquals(2, ranked.get(1).get("placeId"));
    }

    @Test
    void multipleContextCodesUseSharedContextWeight() {
        var item = item(1, "popular-reviewed", 0.60, 10.3460, 107.0843);
        item.put("avgRating", BigDecimal.valueOf(4.8));
        item.put("reviewCount", 25);
        item.put("saveCount", 40);

        var ranked = reranker.rerank(
            List.of(item),
            List.of("GAN_TOI", "CO_REVIEW", "DANG_HOT"),
            10.3450,
            107.0840
        );

        @SuppressWarnings("unchecked")
        Map<String, Object> meta = (Map<String, Object>) ranked.get(0).get("recommendation");
        assertEquals(0.75, (Double) meta.get("semanticWeight"), 0.0001);
        assertEquals(0.25, (Double) meta.get("contextWeight"), 0.0001);
        assertTrue((Double) meta.get("contextScore") > 0.0);
    }

    private Map<String, Object> item(
        int placeId,
        String name,
        double semanticScore,
        double latitude,
        double longitude
    ) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("placeId", placeId);
        item.put("name", name);
        item.put("score", semanticScore);
        item.put("latitude", BigDecimal.valueOf(latitude));
        item.put("longitude", BigDecimal.valueOf(longitude));
        item.put("avgRating", BigDecimal.ZERO);
        item.put("reviewCount", 0);
        item.put("saveCount", 0);
        return item;
    }
}
