package vn.gomate.social.post;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import vn.gomate.common.ApiException;

/** Request-scoped ranking snapshots; no post content or media is cached here. */
@Component
public final class PostRecommendationSnapshotStore {
    public record Snapshot(UUID viewer, List<PostRecommendationScorer.RankedCandidate> candidates, Instant expiresAt) {}

    private final Map<UUID, Snapshot> values = new ConcurrentHashMap<>();
    private final int maxEntries;
    private final Duration ttl;

    public PostRecommendationSnapshotStore(
        @Value("${app.feed.recommendation.snapshot-max-entries:64}") int maxEntries,
        @Value("${app.feed.recommendation.snapshot-ttl-seconds:300}") long ttlSeconds
    ) {
        this.maxEntries = Math.max(1, maxEntries);
        this.ttl = Duration.ofSeconds(Math.max(1, ttlSeconds));
    }

    public synchronized UUID put(UUID viewer, List<PostRecommendationScorer.RankedCandidate> candidates) {
        cleanup();
        while (values.size() >= maxEntries) {
            values.keySet().stream().findFirst().ifPresent(values::remove);
        }
        UUID id = UUID.randomUUID();
        values.put(id, new Snapshot(viewer, List.copyOf(candidates), Instant.now().plus(ttl)));
        return id;
    }

    public Snapshot require(UUID id, UUID viewer) {
        if (id == null) throw ApiException.bad("Con trỏ đề xuất không hợp lệ.");
        Snapshot snapshot = values.get(id);
        if (snapshot == null || snapshot.expiresAt().isBefore(Instant.now()) || !viewer.equals(snapshot.viewer())) {
            values.remove(id);
            throw ApiException.bad("Con trỏ đề xuất đã hết hạn; hãy tải lại Feed.");
        }
        return snapshot;
    }

    private void cleanup() {
        Instant now = Instant.now();
        values.entrySet().removeIf(entry -> entry.getValue().expiresAt().isBefore(now));
    }
}
