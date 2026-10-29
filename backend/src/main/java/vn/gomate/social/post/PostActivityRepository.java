package vn.gomate.social.post;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import vn.gomate.social.comment.CommentRepository;
import static vn.gomate.common.Db.args;

@Repository
public class PostActivityRepository {
    private final Db db;
    public PostActivityRepository(Db db) { this.db = db; }

    public List<Map<String,Object>> page(UUID viewer, String scope, int limit, PostActivityService.Cursor cursor) {
        boolean comments = "COMMENTS".equals(scope);
        String alias = comments ? "c" : "a";
        String key = comments ? "c.id" : "a.post_id";
        String table = comments ? "comments c" : ("LIKES".equals(scope) ? "post_likes a" : "post_saves a");
        var params = args("viewer", viewer, "limit", limit);
        String after = "";
        if (cursor != null) {
            after = " AND ("+alias+".created_at<:time OR ("+alias+".created_at=:time AND "+key+"<:id))";
            params.putAll(args("time", cursor.time(), "id", cursor.id()));
        }
        String fields = comments ? "c.*,COALESCE(up.full_name,up.nickname) AS user_name,up.avatar_url,r.content AS parent_body,COALESCE(parent_up.full_name,parent_up.nickname) AS parent_author,parent_up.avatar_url AS parent_avatar"
            : "a.post_id,a.created_at";
        String extras = comments ? " JOIN user_profiles up ON up.user_id=c.user_id LEFT JOIN comments r ON r.id=c.parent_comment_id LEFT JOIN user_profiles parent_up ON parent_up.user_id=r.user_id" : "";
        // Db maps JDBC Timestamp through JVM local time; project an explicit UTC
        // wall clock for this cursor, independently of the machine timezone.
        return db.list("SELECT "+fields+","+alias+".created_at AT TIME ZONE 'UTC' AS activity_created_at FROM "+table+" JOIN posts p ON p.id="+alias+".post_id JOIN users u ON u.id=p.author_id JOIN user_settings s ON s.user_id=p.author_id"+extras
            +" WHERE "+alias+".user_id=:viewer AND "+PostFeedRepository.VISIBLE
            +(comments ? " AND "+CommentRepository.visibleTo(":viewer") : "")+after
            +" ORDER BY "+alias+".created_at DESC,"+key+" DESC LIMIT :limit", params);
    }
    public boolean commentVisible(UUID viewer, long id) {
        return db.count("SELECT COUNT(*) FROM comments c WHERE c.id=:id AND c.user_id=:viewer AND "+CommentRepository.visibleTo(":viewer"),args("viewer",viewer,"id",id)) == 1;
    }
}
