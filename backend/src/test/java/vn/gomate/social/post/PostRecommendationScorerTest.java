package vn.gomate.social.post;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PostRecommendationScorerTest {
    private static final OffsetDateTime NOW = OffsetDateTime.of(2026, 10, 30, 12, 0, 0, 0, ZoneOffset.UTC);
    private final PostRecommendationScorer scorer = new PostRecommendationScorer(0.80, 0.10, 0.10, 5, 5, 100, 30);

    @Test
    void friendThenFollowedThenScoredRemainderWithStableTies() {
        var ranked = scorer.rank(List.of(
            candidate(1, 0, NOW.minusDays(10), null, 0, 0, List.of()),
            candidate(2, 0, NOW.minusDays(5), null, 0, 0, List.of()),
            candidate(3, 1, NOW.minusDays(1), null, 0, 0, List.of()),
            candidate(4, 2, NOW.minusDays(2), 1L, 0, 0, List.of()),
            candidate(5, 2, NOW.minusDays(3), 2L, 0, 0, List.of())
        ), Map.of(1L, 1.0, 2L, 0.1), Map.of(), NOW);

        assertEquals(List.of(2L, 1L, 3L, 4L, 5L), ranked.stream().map(item -> item.candidate().postId()).toList());
    }

    @Test
    void hashtagScoreDeduplicatesAndNeverExceedsTenPercentComponent() {
        var ranked = scorer.rank(List.of(candidate(
            1, 2, NOW, null, 0, 0, List.of("hot", "hot", "other")
        )), Map.of(), Map.of("hot", 5L, "other", 5L), NOW);

        assertEquals(0.4, ranked.get(0).hashtagScore(), 0.0001);
        assertEquals(0.04, ranked.get(0).score(), 0.0001);
    }

    @Test
    void interactionUsesRealCountsLogSaturationAndRecency() {
        var ranked = scorer.rank(List.of(
            candidate(1, 2, NOW, null, 100, 0, List.of()),
            candidate(2, 2, NOW.minusDays(60), null, 100, 0, List.of())
        ), Map.of(), Map.of(), NOW);

        assertTrue(ranked.get(0).interactionScore() > ranked.get(1).interactionScore());
        assertTrue(ranked.get(0).interactionScore() <= 1.0);
        assertTrue(ranked.get(1).score() < 0.10);
    }

    @Test
    void missingPlaceAiScoreAndMissingHashtagsAreZeroNotInvented() {
        var ranked = scorer.rank(List.of(candidate(1, 2, NOW, null, 0, 0, List.of())), Map.of(), Map.of(), NOW);

        assertEquals(0.0, ranked.get(0).placeScore());
        assertEquals(0.0, ranked.get(0).hashtagScore());
        assertEquals(0.0, ranked.get(0).score());
    }

    private PostRecommendationScorer.Candidate candidate(
        long id,
        int bucket,
        OffsetDateTime createdAt,
        Long placeId,
        long likes,
        long comments,
        List<String> hashtags
    ) {
        return new PostRecommendationScorer.Candidate(
            id, UUID.randomUUID(), placeId, createdAt, bucket, likes, comments, hashtags
        );
    }
}
