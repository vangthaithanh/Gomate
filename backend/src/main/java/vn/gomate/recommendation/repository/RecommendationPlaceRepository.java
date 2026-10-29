package vn.gomate.recommendation.repository;

import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class RecommendationPlaceRepository {
    private final Db db;

    public RecommendationPlaceRepository(Db db) {
        this.db = db;
    }

    public List<Map<String, Object>> findActiveByExternalIds(List<String> externalIds) {
        if (externalIds == null || externalIds.isEmpty()) {
            return List.of();
        }
        return db.list("""
            SELECT
                p.id AS place_id,
                p.external_id,
                p.name,
                p.description,
                c.code AS "category",
                c.name AS category_name,
                p.province,
                p.district,
                p.address,
                p.latitude,
                p.longitude,
                p.avg_rating,
                p.review_count,
                p.save_count,
                (SELECT pm.url
                 FROM place_media pm
                 WHERE pm.place_id=p.id AND pm.media_type='IMAGE'
                 ORDER BY pm.sort_order,pm.id LIMIT 1) AS thumbnail_url
            FROM places p
            JOIN place_categories c ON c.id=p.category_id
            WHERE p.status='ACTIVE'
              AND c.active=TRUE
              AND p.external_id IN (:externalIds)
            """, args("externalIds", externalIds));
    }

    public List<Map<String, Object>> findPopularActive(int limit) {
        return findPopularActive(null, limit);
    }

    public List<Map<String, Object>> findPopularActiveByDestination(String destinationKey, int limit) {
        return findPopularActive(destinationKey, limit);
    }

    private List<Map<String, Object>> findPopularActive(String destinationKey, int limit) {
        String destinationFilter = "";
        Map<String, Object> queryArgs = args("limit", Math.max(1, Math.min(limit, 50)));
        if (destinationKey != null && !destinationKey.isBlank()) {
            destinationFilter = " AND p.external_id LIKE :externalPrefix ";
            queryArgs.put("externalPrefix", destinationKey.trim() + ":%");
        }
        return db.list("""
            SELECT
                p.id AS place_id,
                p.external_id,
                p.name,
                p.description,
                c.code AS "category",
                c.name AS category_name,
                p.province,
                p.district,
                p.address,
                p.latitude,
                p.longitude,
                p.avg_rating,
                p.review_count,
                p.save_count,
                (COALESCE(p.save_count,0) * 2
                    + COALESCE(p.review_count,0) * 3
                    + COALESCE(p.avg_rating,0) * 10) AS "score",
                (SELECT pm.url
                 FROM place_media pm
                 WHERE pm.place_id=p.id AND pm.media_type='IMAGE'
                 ORDER BY pm.sort_order,pm.id LIMIT 1) AS thumbnail_url
            FROM places p
            JOIN place_categories c ON c.id=p.category_id
            WHERE p.status='ACTIVE'
              AND c.active=TRUE
              """ + destinationFilter + """
            ORDER BY
                COALESCE(p.save_count,0) DESC,
                COALESCE(p.review_count,0) DESC,
                COALESCE(p.avg_rating,0) DESC,
                p.id DESC
            LIMIT :limit
            """, queryArgs);
    }

    public List<String> findSemanticInterestCodes(java.util.UUID userId) {
        return db.list("""
            SELECT io.code
            FROM user_interests ui
            JOIN interest_options io ON io.id=ui.interest_option_id
            JOIN interest_groups ig ON ig.id=io.group_id
            WHERE ui.user_id=:userId
              AND io.active=TRUE
              AND ig.active=TRUE
              AND ig.code<>'CONTEXT_STRATEGY'
            ORDER BY ig.sort_order,io.sort_order,io.code
            """, args("userId", userId))
            .stream()
            .map(row -> String.valueOf(row.get("code")))
            .toList();
    }

    public List<String> filterContextCodes(List<String> optionCodes) {
        if (optionCodes == null || optionCodes.isEmpty()) {
            return List.of();
        }
        return db.list("""
            SELECT io.code
            FROM interest_options io
            JOIN interest_groups ig ON ig.id=io.group_id
            WHERE io.active=TRUE
              AND ig.active=TRUE
              AND ig.code='CONTEXT_STRATEGY'
              AND io.code IN (:codes)
            ORDER BY io.sort_order,io.code
            """, args("codes", optionCodes))
            .stream()
            .map(row -> String.valueOf(row.get("code")))
            .toList();
    }
}
