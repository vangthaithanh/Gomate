package vn.gomate.social.post;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.*;
import static vn.gomate.common.Db.args;

@Repository
public class PostSearchRepository {
    private final Db db;
    public PostSearchRepository(Db db) {this.db=db;}
    private static final String FROM=" FROM posts p JOIN users u ON u.id=p.author_id JOIN user_settings s ON s.user_id=p.author_id ";

    public List<Map<String,Object>> page(UUID viewer,String q,List<String> tags,int size,PostSearchService.Cursor cursor) {
        var params=args("viewer",viewer,"q",SearchText.contains(q),"exact",q,"limit",size);
        String caption=SearchText.sql("p.content"), tag=SearchText.sql("h.name");
        String rank="CASE WHEN "+caption+"=:exact THEN 0 ELSE 1 END";
        String where=" WHERE "+PostFeedRepository.VISIBLE;
        if(!q.isEmpty()) where+=" AND ("+caption+" LIKE :q ESCAPE '!' OR EXISTS(SELECT 1 FROM post_hashtags ph JOIN hashtags h ON h.id=ph.hashtag_id WHERE ph.post_id=p.id AND "+tag+" LIKE :q ESCAPE '!'))";
        for(int i=0;i<tags.size();i++) {
            params.put("tag"+i,tags.get(i));
            where+=" AND EXISTS(SELECT 1 FROM post_hashtags ph JOIN hashtags h ON h.id=ph.hashtag_id WHERE ph.post_id=p.id AND LOWER(h.name)=:tag"+i+")";
        }
        if(cursor!=null) {
            where+=" AND ("+rank+">:rank OR ("+rank+"=:rank AND (p.created_at<:time OR (p.created_at=:time AND p.id<:id))))";
            params.putAll(args("rank",cursor.rank(),"time",cursor.time(),"id",cursor.id()));
        }
        return db.list("SELECT p.id,p.created_at AT TIME ZONE 'UTC' AS search_time,"+rank+" AS match_rank"+FROM+where+" ORDER BY match_rank,p.created_at DESC,p.id DESC LIMIT :limit",params);
    }
    public List<Map<String,Object>> hashtags(UUID viewer,String query) {
        return db.list("SELECT h.name AS tag,COUNT(DISTINCT p.id) AS post_count FROM hashtags h JOIN post_hashtags ph ON ph.hashtag_id=h.id JOIN posts p ON p.id=ph.post_id JOIN users u ON u.id=p.author_id JOIN user_settings s ON s.user_id=p.author_id WHERE "+PostFeedRepository.VISIBLE+" AND "+SearchText.sql("h.name")+" LIKE :q ESCAPE '!' GROUP BY h.id,h.name ORDER BY post_count DESC,h.name LIMIT 30",args("viewer",viewer,"q",SearchText.contains(SearchText.query(query).replaceFirst("^#",""))));
    }
}
