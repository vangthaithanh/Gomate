package vn.gomate.social.post;

import java.time.OffsetDateTime;
import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class PostRecommendationRepository {
    private final Db db;

    public PostRecommendationRepository(Db db) { this.db = db; }

    public List<Map<String, Object>> candidates(UUID viewer, OffsetDateTime snapshotAt) {
        return db.list("""
            SELECT p.id,p.created_at,p.author_id,p.place_id,
             CASE
              WHEN EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=:viewer AND f.followed_user_id=p.author_id)
               AND EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=p.author_id AND f.followed_user_id=:viewer) THEN 0
              WHEN EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=:viewer AND f.followed_user_id=p.author_id) THEN 1
              ELSE 2
             END AS bucket,
             (SELECT COUNT(*) FROM post_likes l JOIN users lu ON lu.id=l.user_id AND lu.status='ACTIVE'
              WHERE l.post_id=p.id AND %s ) AS like_count,
             (SELECT COUNT(*) FROM comments c JOIN users cu ON cu.id=c.user_id AND cu.status='ACTIVE'
              WHERE c.post_id=p.id AND %s) AS comment_count
            FROM posts p
            JOIN users u ON u.id=p.author_id
            JOIN user_settings s ON s.user_id=p.author_id
            WHERE %s AND p.created_at<=:snapshot
             AND NOT (
              EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=:viewer AND f.followed_user_id=p.author_id)
              AND EXISTS (SELECT 1 FROM post_home_views v WHERE v.viewer_user_id=:viewer AND v.post_id=p.id)
             )
            ORDER BY p.created_at DESC,p.id DESC
            """.formatted(
                vn.gomate.relationship.block.GlobalBlockPolicy.allowed(":viewer", "l.user_id"),
                vn.gomate.social.comment.CommentRepository.visibleTo(":viewer"),
                PostFeedRepository.VISIBLE), args("viewer", viewer, "snapshot", snapshotAt));
    }

    public boolean recordView(UUID viewer, long postId) {
        return db.update("""
            INSERT INTO post_home_views(viewer_user_id,post_id)
            VALUES(:viewer,:post)
            ON CONFLICT DO NOTHING
            """, args("viewer", viewer, "post", postId)) > 0;
    }

    public List<Map<String, Object>> tags(List<Long> ids) {
        if (ids == null || ids.isEmpty()) return List.of();
        return db.list("""
            SELECT ph.post_id,h.name
            FROM post_hashtags ph JOIN hashtags h ON h.id=ph.hashtag_id
            WHERE ph.post_id IN (:ids)
            ORDER BY ph.post_id,h.name
            """, args("ids", ids));
    }

    public List<Map<String, Object>> hashtagPopularity(UUID viewer, OffsetDateTime from, OffsetDateTime snapshotAt) {
        return db.list("""
            SELECT h.name,COUNT(DISTINCT p.id) AS post_count
            FROM hashtags h
            JOIN post_hashtags ph ON ph.hashtag_id=h.id
            JOIN posts p ON p.id=ph.post_id
            JOIN users u ON u.id=p.author_id
            JOIN user_settings s ON s.user_id=p.author_id
            WHERE p.created_at>=:from AND p.created_at<=:snapshot AND %s
            GROUP BY h.id,h.name
            """.formatted(PostFeedRepository.VISIBLE), args("viewer", viewer, "from", from, "snapshot", snapshotAt));
    }
}
