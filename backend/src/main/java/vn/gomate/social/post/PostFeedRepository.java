package vn.gomate.social.post;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class PostFeedRepository {
    private final Db db;
    public PostFeedRepository(Db db) { this.db = db; }
    static final String VISIBLE = """
        u.status='ACTIVE' AND p.deleted_at IS NULL AND
        NOT EXISTS(SELECT 1 FROM user_blocks gb WHERE (gb.blocker_user_id=:viewer AND gb.blocked_user_id=p.author_id) OR (gb.blocker_user_id=p.author_id AND gb.blocked_user_id=:viewer)) AND (
         p.author_id=:viewer OR (
          p.audience='ACCOUNT' AND (s.account_visibility='PUBLIC' OR EXISTS (
           SELECT 1 FROM user_follows f WHERE f.follower_user_id=:viewer AND f.followed_user_id=p.author_id))
          OR p.audience='FRIENDS' AND EXISTS (
           SELECT 1 FROM user_follows f WHERE f.follower_user_id=:viewer AND f.followed_user_id=p.author_id)
           AND EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_user_id=p.author_id AND f.followed_user_id=:viewer)
         ))
        """;
    private static final String JOINS = """
        FROM posts p JOIN users u ON u.id=p.author_id
        JOIN user_settings s ON s.user_id=p.author_id
        JOIN user_profiles up ON up.user_id=p.author_id
        LEFT JOIN places pl ON pl.id=p.place_id AND pl.status='ACTIVE'
        """;
    public List<Map<String,Object>> page(UUID viewer, int size, PostFeedService.Cursor cursor) {
        var params = args("viewer", viewer, "limit", size);
        String after = "";
        if (cursor != null) {
            after = " AND (p.created_at<:time OR (p.created_at=:time AND p.id<:id))";
            params.putAll(args("time", cursor.time(), "id", cursor.id()));
        }
        return db.list("SELECT p.id,p.created_at " + JOINS + " WHERE " + VISIBLE + after
            + " ORDER BY p.created_at DESC,p.id DESC LIMIT :limit", params);
    }
    public List<Map<String,Object>> visible(UUID viewer, List<Long> ids) {
        if (ids.isEmpty()) return List.of();
        return db.list("""
            SELECT p.*,pl.id AS place_id,s.account_visibility,u.status AS author_status,
             up.nickname,up.full_name,up.avatar_url,pl.name AS place_name
            """ + JOINS + " WHERE p.id IN (:ids) AND " + VISIBLE
            + " ORDER BY p.created_at DESC,p.id DESC", args("viewer",viewer,"ids",ids));
    }
    public List<Map<String,Object>> media(List<Long> ids) {
        return db.list("SELECT * FROM post_media WHERE post_id IN (:ids) AND state='ATTACHED' ORDER BY post_id,sort_order", args("ids",ids));
    }
    public List<Map<String,Object>> tags(List<Long> ids) {
        return db.list("SELECT ph.post_id,h.name FROM post_hashtags ph JOIN hashtags h ON h.id=ph.hashtag_id WHERE ph.post_id IN (:ids) ORDER BY h.name", args("ids",ids));
    }
    public List<Map<String,Object>> people(UUID viewer,List<Long> ids) {
        return db.list("SELECT t.post_id,t.user_id FROM post_user_tags t JOIN users u ON u.id=t.user_id WHERE t.post_id IN (:ids) AND u.status='ACTIVE' AND "+vn.gomate.relationship.block.GlobalBlockPolicy.allowed(":viewer","t.user_id")+" ORDER BY t.user_id",args("ids",ids,"viewer",viewer));
    }
    public List<Map<String,Object>> engagements(UUID viewer,List<Long> ids) {
        return db.list("""
            SELECT p.id AS post_id,
             (SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.id) AS like_count,
             EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=:viewer) AS liked_by_me,
             EXISTS(SELECT 1 FROM post_saves b WHERE b.post_id=p.id AND b.user_id=:viewer) AS saved_by_me,
             (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND %s) AS comment_count
            FROM posts p WHERE p.id IN (:ids)
            """.formatted(vn.gomate.social.comment.CommentRepository.visibleTo(":viewer")),args("viewer",viewer,"ids",ids));
    }
    public PostDtos.Engagement engagement(UUID viewer,long id) {
        var r = engagements(viewer,List.of(id)).get(0);
        return engagement(r);
    }
    public static PostDtos.Engagement engagement(Map<String,Object> r) {
        return new PostDtos.Engagement(((Number)r.get("postId")).longValue(),
            ((Number)r.get("likeCount")).longValue(),Boolean.TRUE.equals(r.get("likedByMe")),Boolean.TRUE.equals(r.get("savedByMe")),((Number)r.get("commentCount")).longValue());
    }
    public void lock(long id) { db.one("SELECT id FROM posts WHERE id=:id FOR UPDATE",args("id",id)); }
    public List<Map<String,Object>> likers(UUID viewer,long post,int limit,PostFeedService.LikersCursor cursor) {
        var params=args("post",post,"limit",limit,"viewer",viewer);
        String after="";
        if(cursor!=null) {
            after=" AND (l.created_at<:time OR (l.created_at=:time AND l.user_id<:user))";
            params.putAll(args("time",cursor.time(),"user",cursor.userId()));
        }
        return db.list("""
            SELECT l.user_id,l.created_at,COALESCE(NULLIF(p.full_name,''),p.nickname) AS display_name,p.nickname,p.avatar_url
            FROM post_likes l JOIN users u ON u.id=l.user_id AND u.status='ACTIVE'
            JOIN user_profiles p ON p.user_id=l.user_id WHERE l.post_id=:post
            """+" AND "+vn.gomate.relationship.block.GlobalBlockPolicy.allowed(":viewer","l.user_id")+after+" ORDER BY l.created_at DESC,l.user_id DESC LIMIT :limit",params);
    }
    public boolean set(UUID viewer,long id,boolean like,boolean value) {
        String table = like ? "post_likes" : "post_saves";
        return db.update(value ? "INSERT INTO " + table + "(post_id,user_id) VALUES(:id,:viewer) ON CONFLICT DO NOTHING"
            : "DELETE FROM " + table + " WHERE post_id=:id AND user_id=:viewer", args("id",id,"viewer",viewer))>0;
    }
}
