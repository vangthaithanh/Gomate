package vn.gomate.social.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.recommendation.service.RecommendationService;

@Service
public class PostRecommendationFeedService {
    private static final int MAX_SIZE = 50;
    private static final int HASHTAG_WINDOW_DAYS = 30;

    private final PostRecommendationRepository recommendationRepo;
    private final PostFeedRepository feedRepo;
    private final PostService posts;
    private final RecommendationService places;
    private final PostRecommendationScorer scorer;
    private final PostRecommendationSnapshotStore snapshots;
    private final ObjectMapper json;
    private final int placeTopK;

    public PostRecommendationFeedService(
        PostRecommendationRepository recommendationRepo,
        PostFeedRepository feedRepo,
        PostService posts,
        RecommendationService places,
        PostRecommendationScorer scorer,
        PostRecommendationSnapshotStore snapshots,
        ObjectMapper json,
        @Value("${app.feed.recommendation.place-top-k:50}") int placeTopK
    ) {
        this.recommendationRepo = recommendationRepo;
        this.feedRepo = feedRepo;
        this.posts = posts;
        this.places = places;
        this.scorer = scorer;
        this.snapshots = snapshots;
        this.json = json;
        this.placeTopK = Math.max(1, Math.min(placeTopK, 100));
    }

    public PostDtos.Page feed(
        UUID viewer,
        int size,
        String token,
        String destinationKey,
        Double latitude,
        Double longitude
    ) {
        if (size < 1 || size > MAX_SIZE) throw ApiException.bad("Kích thước trang từ 1 đến 50.");
        if (token == null || token.isBlank()) {
            OffsetDateTime snapshotAt = OffsetDateTime.now(ZoneOffset.UTC);
            var ranked = buildSnapshot(viewer, snapshotAt, destinationKey, latitude, longitude);
            UUID snapshotId = snapshots.put(viewer, ranked);
            return page(viewer, size, snapshotId, snapshots.require(snapshotId, viewer), 0);
        }
        Cursor cursor = decode(token);
        var snapshot = snapshots.require(cursor.snapshotId(), viewer);
        return page(viewer, size, cursor.snapshotId(), snapshot, cursor.offset());
    }

    public record Cursor(UUID snapshotId, UUID viewer, int offset, String scope) {}

    @Transactional
    public void viewed(UUID viewer, long postId) {
        posts.authorize(viewer, postId);
        recommendationRepo.recordView(viewer, postId);
        // Roll the insert back if access changed while this request was running.
        posts.authorize(viewer, postId);
    }

    private PostDtos.Page page(
        UUID viewer,
        int size,
        UUID snapshotId,
        PostRecommendationSnapshotStore.Snapshot snapshot,
        int offset
    ) {
        if (offset < 0 || offset > snapshot.candidates().size()) throw ApiException.bad("Con trỏ đề xuất không hợp lệ.");
        List<PostRecommendationScorer.RankedCandidate> remaining = snapshot.candidates().subList(offset, snapshot.candidates().size());
        if (remaining.isEmpty()) return new PostDtos.Page(List.of(), null);

        List<Long> remainingIds = remaining.stream().map(item -> item.candidate().postId()).toList();
        Map<Long, Map<String, Object>> visible = feedRepo.visible(viewer, remainingIds).stream()
            .collect(Collectors.toMap(row -> number(row.get("id")).longValue(), row -> row, (left, right) -> left));

        List<PostRecommendationScorer.RankedCandidate> selected = new ArrayList<>();
        int lastSelectedOffset = -1;
        for (int index = 0; index < remaining.size(); index++) {
            var candidate = remaining.get(index);
            if (!visible.containsKey(candidate.candidate().postId())) continue;
            selected.add(candidate);
            lastSelectedOffset = index;
            if (selected.size() >= size) break;
        }
        if (selected.isEmpty()) return new PostDtos.Page(List.of(), null);

        List<Long> ids = selected.stream().map(item -> item.candidate().postId()).toList();
        Map<Long, List<Map<String, Object>>> media = group(feedRepo.media(ids));
        Map<Long, List<Map<String, Object>>> tags = group(feedRepo.tags(ids));
        Map<Long, List<Map<String, Object>>> people = group(feedRepo.people(viewer, ids));
        Map<Long, PostDtos.Engagement> stats = feedRepo.engagements(viewer, ids).stream()
            .collect(Collectors.toMap(row -> number(row.get("postId")).longValue(), PostFeedRepository::engagement));

        List<PostDtos.Detail> items = new ArrayList<>();
        for (var selectedCandidate : selected) {
            long id = selectedCandidate.candidate().postId();
            Map<String, Object> row = visible.get(id);
            if (row == null) continue;
            items.add(posts.project(
                row,
                media.getOrDefault(id, List.of()),
                tags.getOrDefault(id, List.of()).stream().map(item -> (String) item.get("name")).toList(),
                people.getOrDefault(id, List.of()).stream().map(item -> (UUID) item.get("userId")).toList(),
                stats.get(id)
            ));
        }

        int nextOffset = offset + lastSelectedOffset + 1;
        String next = nextOffset < snapshot.candidates().size()
            ? encode(new Cursor(snapshotId, viewer, nextOffset, "RECOMMENDED"))
            : null;
        return new PostDtos.Page(List.copyOf(items), next);
    }

    private List<PostRecommendationScorer.RankedCandidate> buildSnapshot(
        UUID viewer,
        OffsetDateTime snapshotAt,
        String destinationKey,
        Double latitude,
        Double longitude
    ) {
        var rows = recommendationRepo.candidates(viewer, snapshotAt);
        if (rows.isEmpty()) return List.of();
        List<Long> ids = rows.stream().map(row -> number(row.get("id")).longValue()).toList();
        Map<Long, List<String>> tags = group(recommendationRepo.tags(ids)).entrySet().stream().collect(Collectors.toMap(
            Map.Entry::getKey,
            entry -> entry.getValue().stream().map(row -> (String) row.get("name")).distinct().toList()
        ));
        Map<String, Long> popularity = recommendationRepo.hashtagPopularity(
            viewer,
            snapshotAt.minusDays(HASHTAG_WINDOW_DAYS),
            snapshotAt
        ).stream().collect(Collectors.toMap(
            row -> ((String) row.get("name")).toLowerCase(Locale.ROOT),
            row -> number(row.get("postCount")).longValue(),
            Math::max
        ));
        List<PostRecommendationScorer.Candidate> candidates = rows.stream().map(row -> new PostRecommendationScorer.Candidate(
            number(row.get("id")).longValue(),
            (UUID) row.get("authorId"),
            row.get("placeId") == null ? null : number(row.get("placeId")).longValue(),
            PostService.instant(row.get("createdAt")),
            number(row.get("bucket")).intValue(),
            number(row.get("likeCount")).longValue(),
            number(row.get("commentCount")).longValue(),
            tags.getOrDefault(number(row.get("id")).longValue(), List.of())
        )).toList();
        Map<Long, Double> placeScores = placeScores(viewer, candidates, destinationKey, latitude, longitude);
        return scorer.rank(candidates, placeScores, popularity, snapshotAt);
    }

    private Map<Long, Double> placeScores(
        UUID viewer,
        List<PostRecommendationScorer.Candidate> candidates,
        String destinationKey,
        Double latitude,
        Double longitude
    ) {
        if (candidates.stream().noneMatch(candidate -> candidate.placeId() != null)) return Map.of();
        try {
            Object rawItems = places.mine(viewer, destinationKey, latitude, longitude, placeTopK).get("items");
            if (!(rawItems instanceof Collection<?> collection)) return Map.of();
            Map<Long, Double> scores = new HashMap<>();
            for (Object raw : collection) {
                if (!(raw instanceof Map<?, ?> item) || item.get("placeId") == null) continue;
                Object rawScore = item.get("score");
                if (!(rawScore instanceof Number number)) continue;
                double score = number.doubleValue();
                if (Double.isFinite(score)) scores.put(number(item.get("placeId")).longValue(), Math.max(0.0, Math.min(1.0, score)));
            }
            return scores;
        } catch (RuntimeException unavailable) {
            // The recommendation feed remains usable without an AI/Place response.
            return Map.of();
        }
    }

    private Cursor decode(String token) {
        try {
            Cursor cursor = json.readValue(Base64.getUrlDecoder().decode(token), Cursor.class);
            if (cursor.snapshotId() == null || cursor.viewer() == null || cursor.offset() < 0 || !"RECOMMENDED".equals(cursor.scope())) {
                throw new IllegalArgumentException();
            }
            return cursor;
        } catch (Exception invalid) {
            throw ApiException.bad("Con trỏ đề xuất không hợp lệ.");
        }
    }

    private String encode(Cursor cursor) {
        try {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(cursor));
        } catch (Exception error) {
            throw new IllegalStateException(error);
        }
    }

    private Map<Long, List<Map<String, Object>>> group(List<Map<String, Object>> rows) {
        return rows.stream().collect(Collectors.groupingBy(row -> number(row.get("postId")).longValue()));
    }

    private Number number(Object value) {
        if (value instanceof Number number) return number;
        if (value instanceof String text) {
            try { return Double.parseDouble(text); } catch (NumberFormatException ignored) { return 0; }
        }
        return 0;
    }
}
