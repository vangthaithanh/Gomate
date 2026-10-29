package vn.gomate.social.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;

@Service
public class PostFeedService {
    private final PostFeedRepository repo;
    private final PostService posts;
    private final PostRepository postRepo;
    private final ObjectMapper json;
    private final vn.gomate.notification.service.NotificationService notifications;
    public PostFeedService(PostFeedRepository repo,PostService posts,PostRepository postRepo,ObjectMapper json,vn.gomate.notification.service.NotificationService notifications) {
        this.repo=repo;this.posts=posts;this.postRepo=postRepo;this.json=json;this.notifications=notifications;
    }
    public record Cursor(OffsetDateTime time,long id,UUID viewer,String scope) {}
    public record LikersCursor(OffsetDateTime time,UUID userId,UUID viewer,long postId) {}
    public PostDtos.LikersPage likers(UUID viewer,long post,int size,String token) {
        if(size<1 || size>50) throw ApiException.bad("Kích thước trang từ 1 đến 50.");
        posts.authorize(viewer,post);
        LikersCursor cursor=null;
        if(token!=null) try {
            cursor=json.readValue(Base64.getUrlDecoder().decode(token),LikersCursor.class);
            if(cursor.time()==null || cursor.userId()==null || !viewer.equals(cursor.viewer()) || cursor.postId()!=post) throw new IllegalArgumentException();
        } catch(Exception invalid) {throw ApiException.bad("Con trỏ không hợp lệ.");}
        var rows=repo.likers(viewer,post,size+1,cursor);
        var page=rows.subList(0,Math.min(size,rows.size()));
        var items=page.stream().map(r->new PostDtos.Liker((UUID)r.get("userId"),(String)r.get("displayName"),(String)r.get("nickname"),(String)r.get("avatarUrl"))).toList();
        posts.authorize(viewer,post);
        String next=null;
        if(rows.size()>size) try {
            var last=page.get(page.size()-1);
            next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(
                new LikersCursor(PostService.instant(last.get("createdAt")),(UUID)last.get("userId"),viewer,post)));
        } catch(Exception failure) {throw new IllegalStateException(failure);}
        return new PostDtos.LikersPage(items,next);
    }
    public PostDtos.Page feed(UUID viewer,int size,String token) {
        if(size<1 || size>50) throw ApiException.bad("Kích thước trang từ 1 đến 50.");
        Cursor cursor=null;
        if(token!=null) try {
            cursor=json.readValue(Base64.getUrlDecoder().decode(token),Cursor.class);
            if(cursor.time()==null || cursor.id()<1 || !viewer.equals(cursor.viewer()) || !"HOME".equals(cursor.scope())) throw new IllegalArgumentException();
        } catch(Exception e) { throw ApiException.bad("Con trỏ trang không hợp lệ."); }
        var rows=repo.page(viewer,size+1,cursor);
        var scanned=rows.subList(0,Math.min(size,rows.size()));
        var ids=scanned.stream().map(r->((Number)r.get("id")).longValue()).toList();
        var items=new ArrayList<PostDtos.Detail>();
        if(!ids.isEmpty()) {
            var media=group(repo.media(ids));var tags=group(repo.tags(ids));var people=group(repo.people(viewer,ids));
            var stats=repo.engagements(viewer,ids).stream().collect(Collectors.toMap(r->((Number)r.get("postId")).longValue(),PostFeedRepository::engagement));
            // Fresh eligibility/profile read after batching. Never serialize revoked rows.
            for(var row:repo.visible(viewer,ids)) {
                long id=((Number)row.get("id")).longValue();
                items.add(posts.project(row,media.getOrDefault(id,List.of()),
                    tags.getOrDefault(id,List.of()).stream().map(r->(String)r.get("name")).toList(),
                    people.getOrDefault(id,List.of()).stream().map(r->(UUID)r.get("userId")).toList(),stats.get(id)));
            }
        }
        String next=null;
        // Advance by scanned key even if a concurrent privacy change removes that row.
        if(rows.size()>size) try {
            var last=scanned.get(scanned.size()-1);
            next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(
                new Cursor(PostService.instant(last.get("createdAt")),((Number)last.get("id")).longValue(),viewer,"HOME")));
        } catch(Exception e) { throw new IllegalStateException(e); }
        return new PostDtos.Page(List.copyOf(items),next);
    }
    private Map<Long,List<Map<String,Object>>> group(List<Map<String,Object>> rows) {
        return rows.stream().collect(Collectors.groupingBy(r->((Number)r.get("postId")).longValue()));
    }
    @Transactional
    public PostDtos.Engagement set(UUID viewer,long id,boolean like,boolean value) {
        var post=posts.authorize(viewer,id);
        // Same Settings -> Post lock order as existing owner/privacy mutations.
        posts.lockInteraction(viewer,id);
        repo.lock(id);
        posts.authorize(viewer,id);
        boolean changed=repo.set(viewer,id,like,value);
        if(changed && like && value) notifications.recordPostInteraction((UUID)post.get("authorId"),viewer,id,null,false);
        return repo.engagement(viewer,id);
    }
}
