package vn.gomate.social.post;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Pure, deterministic ranking math for the opt-in recommended feed. */
@Component
public final class PostRecommendationScorer {
    public record Candidate(
        long postId,
        UUID authorId,
        Long placeId,
        OffsetDateTime createdAt,
        int bucket,
        long likeCount,
        long commentCount,
        List<String> hashtags
    ) {}

    public record RankedCandidate(
        Candidate candidate,
        double placeScore,
        double hashtagScore,
        double interactionScore,
        double score
    ) {}

    private final double placeWeight;
    private final double hashtagWeight;
    private final double interactionWeight;
    private final int maxHashtags;
    private final double hashtagPopularityFloor;
    private final double interactionSaturation;
    private final double interactionRecencyDays;

    public PostRecommendationScorer(
        @Value("${app.feed.recommendation.place-weight:0.80}") double placeWeight,
        @Value("${app.feed.recommendation.hashtag-weight:0.10}") double hashtagWeight,
        @Value("${app.feed.recommendation.interaction-weight:0.10}") double interactionWeight,
        @Value("${app.feed.recommendation.max-hashtags:5}") int maxHashtags,
        @Value("${app.feed.recommendation.hashtag-popularity-floor:5}") double hashtagPopularityFloor,
        @Value("${app.feed.recommendation.interaction-saturation:100}") double interactionSaturation,
        @Value("${app.feed.recommendation.interaction-recency-days:30}") double interactionRecencyDays
    ) {
        double total = Math.max(0.0, placeWeight) + Math.max(0.0, hashtagWeight) + Math.max(0.0, interactionWeight);
        if (total <= 0.0) {
            this.placeWeight = 0.80;
            this.hashtagWeight = 0.10;
            this.interactionWeight = 0.10;
        } else {
            this.placeWeight = Math.max(0.0, placeWeight) / total;
            this.hashtagWeight = Math.max(0.0, hashtagWeight) / total;
            this.interactionWeight = Math.max(0.0, interactionWeight) / total;
        }
        this.maxHashtags = Math.max(1, maxHashtags);
        this.hashtagPopularityFloor = Math.max(1.0, hashtagPopularityFloor);
        this.interactionSaturation = Math.max(1.0, interactionSaturation);
        this.interactionRecencyDays = Math.max(1.0, interactionRecencyDays);
    }

    public List<RankedCandidate> rank(
        List<Candidate> candidates,
        Map<Long, Double> placeScores,
        Map<String, Long> hashtagPopularity,
        OffsetDateTime snapshotAt
    ) {
        if (candidates == null || candidates.isEmpty()) return List.of();
        Map<Long, Double> safePlaceScores = placeScores == null ? Map.of() : placeScores;
        Map<String, Long> safeHashtagPopularity = hashtagPopularity == null ? Map.of() : hashtagPopularity;
        List<RankedCandidate> ranked = new ArrayList<>();
        for (Candidate candidate : candidates) {
            double placeScore = candidate.placeId() == null
                ? 0.0
                : clamp01(safePlaceScores.getOrDefault(candidate.placeId(), 0.0));
            double hashtagScore = hashtagScore(candidate.hashtags(), safeHashtagPopularity);
            double interactionScore = interactionScore(candidate, snapshotAt);
            double score = clamp01(
                placeWeight * placeScore
                    + hashtagWeight * hashtagScore
                    + interactionWeight * interactionScore
            );
            ranked.add(new RankedCandidate(candidate, placeScore, hashtagScore, interactionScore, score));
        }
        ranked.sort((left, right) -> {
            int bucket = Integer.compare(left.candidate().bucket(), right.candidate().bucket());
            if (bucket != 0) return bucket;
            if (left.candidate().bucket() < 2) {
                int time = right.candidate().createdAt().compareTo(left.candidate().createdAt());
                if (time != 0) return time;
                return Long.compare(right.candidate().postId(), left.candidate().postId());
            }
            int score = Double.compare(right.score(), left.score());
            if (score != 0) return score;
            int time = right.candidate().createdAt().compareTo(left.candidate().createdAt());
            if (time != 0) return time;
            return Long.compare(right.candidate().postId(), left.candidate().postId());
        });
        return List.copyOf(ranked);
    }

    double hashtagScore(Collection<String> hashtags, Map<String, Long> popularity) {
        if (hashtags == null || hashtags.isEmpty() || popularity.isEmpty()) return 0.0;
        long maxPopularity = popularity.values().stream().filter(Objects::nonNull).mapToLong(value -> Math.max(0L, value)).max().orElse(0L);
        double denominator = Math.max(hashtagPopularityFloor, maxPopularity);
        double sum = 0.0;
        Set<String> unique = new HashSet<>();
        for (String raw : hashtags) {
            if (raw == null) continue;
            String tag = raw.trim().toLowerCase(Locale.ROOT);
            if (!tag.isEmpty() && unique.add(tag)) {
                sum += clamp01(Math.max(0L, popularity.getOrDefault(tag, 0L)) / denominator);
            }
        }
        return clamp01(sum / maxHashtags);
    }

    private double interactionScore(Candidate candidate, OffsetDateTime snapshotAt) {
        long likes = Math.max(0L, candidate.likeCount());
        long comments = Math.max(0L, candidate.commentCount());
        double volume = Math.log1p((double) likes + comments) / Math.log1p(interactionSaturation);
        double ageDays = 0.0;
        if (candidate.createdAt() != null && snapshotAt != null) {
            ageDays = Math.max(0.0, Duration.between(candidate.createdAt(), snapshotAt).toSeconds() / 86400.0);
        }
        double recency = 1.0 / (1.0 + ageDays / interactionRecencyDays);
        return clamp01(volume) * recency;
    }

    private double clamp01(double value) {
        if (!Double.isFinite(value)) return 0.0;
        return Math.max(0.0, Math.min(1.0, value));
    }
}
