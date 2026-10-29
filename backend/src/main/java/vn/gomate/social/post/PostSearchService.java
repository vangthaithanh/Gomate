package vn.gomate.social.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.OffsetDateTime;
import java.util.*;
import org.springframework.stereotype.Service;
import vn.gomate.common.*;

@Service
public class PostSearchService {
    private final PostSearchRepository repo;
    private final PostService posts;
    private final ObjectMapper json;
    public PostSearchService(PostSearchRepository repo,PostService posts,ObjectMapper json) {this.repo=repo;this.posts=posts;this.json=json;}
    public record Cursor(UUID viewer,String query,List<String> tags,int rank,OffsetDateTime time,long id) {}
    public record Preview(long id,String caption,List<String> hashtags,String thumbnailUrl) {}
    public record Page(List<Preview> items,String nextCursor) {}
    public Page search(UUID viewer,String query,List<String> hashtags,int size,String token) {
        String q=SearchText.fold(SearchText.query(query)).replaceFirst("^#","");
        var tags=PostService.normalizeTags(hashtags.stream().filter(t->!t.isBlank()).toList());
        if(tags.size()>5 || size<1 || size>50) throw ApiException.bad("Bộ lọc hoặc kích thước trang không hợp lệ.");
        Cursor cursor=null;
        if(token!=null) try {
            if(token.length()>4096) throw new IllegalArgumentException();
            cursor=json.readValue(Base64.getUrlDecoder().decode(token),Cursor.class);
            if(!viewer.equals(cursor.viewer()) || !q.equals(cursor.query()) || !tags.equals(cursor.tags()) || cursor.time()==null || cursor.id()<1 || cursor.rank()<0 || cursor.rank()>1) throw new IllegalArgumentException();
        } catch(Exception e) {throw ApiException.bad("Con trỏ tìm kiếm không hợp lệ.");}
        var rows=repo.page(viewer,q,tags,size+1,cursor);
        var scanned=rows.subList(0,Math.min(size,rows.size()));
        var items=new ArrayList<Preview>();
        for(var row:scanned) try {
            var detail=posts.detail(viewer,((Number)row.get("id")).longValue());
            items.add(new Preview(detail.id(),detail.caption(),detail.hashtags(),detail.media().isEmpty()?null:detail.media().get(0).thumbnailUrl()));
        } catch(ApiException e) {if(e.status!=404)throw e;}
        String next=null;
        if(rows.size()>size) try {
            var last=scanned.get(scanned.size()-1);
            next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(new Cursor(viewer,q,tags,((Number)last.get("matchRank")).intValue(),PostService.instant(last.get("searchTime")),((Number)last.get("id")).longValue())));
        } catch(Exception e) {throw new IllegalStateException(e);}
        return new Page(items,next);
    }
    public List<Map<String,Object>> hashtags(UUID viewer,String query) {
        return repo.hashtags(viewer,SearchText.query(query));
    }
}
