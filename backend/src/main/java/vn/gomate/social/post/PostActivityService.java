package vn.gomate.social.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.OffsetDateTime;
import java.util.*;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;

@Service
public class PostActivityService {
    private final PostActivityRepository repo;
    private final PostService posts;
    private final ObjectMapper json;
    public PostActivityService(PostActivityRepository repo, PostService posts, ObjectMapper json) {
        this.repo=repo; this.posts=posts; this.json=json;
    }
    public record Cursor(UUID viewer, String scope, OffsetDateTime time, long id) {}
    public record Page(List<Map<String,Object>> items, String nextCursor) {}

    public Page list(UUID viewer, String scope, int size, String token) {
        if (!Set.of("LIKES","SAVES","COMMENTS").contains(scope) || size<1 || size>50)
            throw ApiException.bad("Kích thước trang từ 1 đến 50.");
        Cursor cursor=null;
        if (token!=null) try {
            cursor=json.readValue(Base64.getUrlDecoder().decode(token),Cursor.class);
            if (!viewer.equals(cursor.viewer()) || !scope.equals(cursor.scope()) || cursor.time()==null || cursor.id()<1)
                throw new IllegalArgumentException();
        } catch (Exception e) { throw ApiException.bad("Con trỏ trang không hợp lệ."); }
        var rows=repo.page(viewer,scope,size+1,cursor);
        var scanned=rows.subList(0,Math.min(size,rows.size()));
        var items=new ArrayList<Map<String,Object>>();
        for (var row:scanned) try {
            long postId=((Number)row.get("postId")).longValue();
            // Same authorization and protected media DTO as the shared Post viewer.
            var post=posts.detail(viewer,postId);
            var item=new LinkedHashMap<String,Object>();
            item.put("post",post);
            var time=PostService.instant(row.get("activityCreatedAt"));
            if ("COMMENTS".equals(scope)) {
                long id=((Number)row.get("id")).longValue();
                if (!repo.commentVisible(viewer,id)) continue;
                item.put("commentId",id); item.put("postId",postId);
                item.put("parentCommentId",row.get("parentCommentId"));
                item.put("body",row.get("content")); item.put("createdAt",time);
                item.put("authorName",row.get("userName")); item.put("avatarUrl",row.get("avatarUrl"));
                item.put("parentBody",row.get("parentBody")); item.put("parentAuthor",row.get("parentAuthor"));
                item.put("parentAvatar",row.get("parentAvatar"));
            } else {
                item.put("LIKES".equals(scope) ? "likedAt" : "savedAt",time);
            }
            items.add(item);
        } catch (ApiException e) { if (e.status!=404) throw e; }
        String next=null;
        // Advance the scanned key even if a concurrent revoke/deletion hides a row.
        if (rows.size()>size) try {
            var last=scanned.get(scanned.size()-1);
            long id=((Number)last.get("COMMENTS".equals(scope)?"id":"postId")).longValue();
            next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(
                new Cursor(viewer,scope,PostService.instant(last.get("activityCreatedAt")),id)));
        } catch (Exception e) { throw new IllegalStateException(e); }
        return new Page(List.copyOf(items),next);
    }
}
