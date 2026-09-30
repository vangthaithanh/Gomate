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
                p.id AS "placeId",
                p.external_id AS "externalId",
                p.name,
                p.description,
                c.code AS "category",
                c.name AS "categoryName",
                p.province,
                p.district,
                p.address,
                p.latitude,
                p.longitude,
                p.avg_rating AS "avgRating",
                p.review_count AS "reviewCount",
                p.save_count AS "saveCount",
                (SELECT pm.url
                 FROM place_media pm
                 WHERE pm.place_id=p.id AND pm.media_type='IMAGE'
                 ORDER BY pm.sort_order,pm.id LIMIT 1) AS "thumbnailUrl"
            FROM places p
            JOIN place_categories c ON c.id=p.category_id
            WHERE p.status='ACTIVE'
              AND c.active=TRUE
              AND p.external_id IN (:externalIds)
            """, args("externalIds", externalIds));
    }

    public List<Map<String, Object>> findPopularActive(int limit) {
        return db.list("""
            SELECT
                p.id AS "placeId",
                p.external_id AS "externalId",
                p.name,
                p.description,
                c.code AS "category",
                c.name AS "categoryName",
                p.province,
                p.district,
                p.address,
                p.latitude,
                p.longitude,
                p.avg_rating AS "avgRating",
                p.review_count AS "reviewCount",
                p.save_count AS "saveCount",
                (COALESCE(p.save_count,0) * 2
                    + COALESCE(p.review_count,0) * 3
                    + COALESCE(p.avg_rating,0) * 10) AS "score",
                (SELECT pm.url
                 FROM place_media pm
                 WHERE pm.place_id=p.id AND pm.media_type='IMAGE'
                 ORDER BY pm.sort_order,pm.id LIMIT 1) AS "thumbnailUrl"
            FROM places p
            JOIN place_categories c ON c.id=p.category_id
            WHERE p.status='ACTIVE'
              AND c.active=TRUE
            ORDER BY
                COALESCE(p.save_count,0) DESC,
                COALESCE(p.review_count,0) DESC,
                COALESCE(p.avg_rating,0) DESC,
                p.id DESC
            LIMIT :limit
            """, args("limit", Math.max(1, Math.min(limit, 50))));
    }
}
