package vn.gomate.user.repository;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class RecentSearchRepository {
    private final Db db;
    public RecentSearchRepository(Db db) {this.db=db;}
    public List<String> list(UUID viewer) {
        return db.list("SELECT display_query FROM recent_searches WHERE user_id=:id ORDER BY used_at DESC,query_key LIMIT 8",args("id",viewer))
            .stream().map(r->(String)r.get("displayQuery")).toList();
    }
    public void lock(UUID viewer) {db.one("SELECT user_id FROM user_settings WHERE user_id=:id FOR UPDATE",args("id",viewer));}
    public void insert(UUID viewer,String key,String clean) {
        db.update("INSERT INTO recent_searches(user_id,query_key,display_query) VALUES(:id,:key,:query)",args("id",viewer,"key",key,"query",clean));
        var excess=db.list("SELECT query_key FROM recent_searches WHERE user_id=:id ORDER BY used_at DESC,query_key LIMIT 100 OFFSET 8",args("id",viewer));
        if(!excess.isEmpty()) db.update("DELETE FROM recent_searches WHERE user_id=:id AND query_key IN (:keys)",args("id",viewer,"keys",excess.stream().map(r->r.get("queryKey")).toList()));
    }
    public void remove(UUID viewer,String key) {db.update("DELETE FROM recent_searches WHERE user_id=:id AND query_key=:key",args("id",viewer,"key",key));}
}
