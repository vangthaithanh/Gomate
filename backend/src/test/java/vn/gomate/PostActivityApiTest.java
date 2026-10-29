package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.social.post.*;
import vn.gomate.social.comment.*;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PostActivityApiTest {
    @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired AuthService auth; @Autowired Db db;
    @Autowired PostService posts; @Autowired PostFeedService feed; @Autowired CommentService comments;
    @Autowired PostActivityService activity;
    @Autowired vn.gomate.relationship.service.SocialRelationshipService relationships;
    @Autowired vn.gomate.user.service.UserService users;
    @MockitoSpyBean PostActivityRepository repo;
    record User(UUID id, String token) {}
    User user() {
        String key="activity"+UUID.randomUUID().toString().replace("-","").substring(0,14);
        var value=auth.register(new AuthDtos.Register(key+"@example.com","TestPass123!",key));
        return new User((UUID)((Map<?,?>)value.get("user")).get("id"),"Bearer "+value.get("accessToken"));
    }
    JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request, User user, int expected) throws Exception {
        var response=mvc.perform(request.header("Authorization",user.token)).andExpect(status().is(expected)).andReturn().getResponse();
        return response.getContentAsByteArray().length==0 ? json.createObjectNode() : json.readTree(response.getContentAsByteArray());
    }
    long publish(User user) {
        UUID id=UUID.randomUUID();
        db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,'hash','IMAGE','READY',:pid,:thumb,'png','image/png',4,2,2)",
            args("id",id,"owner",user.id,"pid",id.toString(),"thumb",id+"_cover"));
        return posts.publish(user.id,new PostDtos.Publish(UUID.randomUUID(),"Activity caption","EVERYONE",new ArrayList<>(List.of(id)),List.of(),new ArrayList<>(),null)).id();
    }
    long comment(User user, long post, String body, Long parent) {
        return ((Number)comments.create(user.id,post,new CommentDtos.Create(UUID.randomUUID(),body,parent,new ArrayList<>())).get("id")).longValue();
    }
    void privacy(User user, boolean value) {
        users.updateProfile(user.id,new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,null,null,null,null,value));
    }
    JsonNode list(User user, String path) throws Exception { return call(get("/api/v1/me/"+path),user,200).get("items"); }

    @Test void currentJwtOwnActivityProtectedPreviewAndNoDemoSource() throws Exception {
        var author=user(); var a=user(); var b=user(); long p=publish(author);
        feed.set(a.id,p,true,true); feed.set(a.id,p,false,true);
        long foreign=comment(b,p,"Reference only",null), own=comment(a,p,"My reply",foreign);
        for (String path:List.of("liked-posts","saved-posts","comments")) {
            var items=list(a,path); assertEquals(1,items.size());
            var post=items.get(0).get("post"); assertEquals(p,post.get("id").asLong());
            assertTrue(post.get("media").get(0).get("thumbnailUrl").asText().startsWith("/posts/"+p+"/media/"));
            assertFalse(items.toString().contains("cloudinary"));
            mvc.perform(get("/api/v1/me/"+path)).andExpect(status().isUnauthorized());
            mvc.perform(get("/api/v1/me/"+path).header("Authorization",a.token)).andExpect(header().string("Cache-Control","private, no-store, max-age=0"));
        }
        assertEquals(0,list(b,"liked-posts").size()); assertEquals(0,list(b,"saved-posts").size());
        var ownItem=list(a,"comments").get(0); assertEquals(own,ownItem.get("commentId").asLong());
        assertEquals(foreign,ownItem.get("parentCommentId").asLong()); assertEquals("Reference only",ownItem.get("parentBody").asText());
        assertEquals("My reply",ownItem.get("body").asText());
        assertEquals(own,call(get("/api/v1/me/comments?userId="+b.id),a,200).get("items").get(0).get("commentId").asLong());
    }
    @Test void interactionOrderKeysetAndCursorsBoundToActorAndScope() throws Exception {
        var owner=user(); var a=user(); var b=user(); var expected=new ArrayList<Long>();
        var time=OffsetDateTime.now(ZoneOffset.UTC).minusDays(1);
        for(int i=0;i<5;i++) {
            long p=publish(owner); expected.add(p); feed.set(a.id,p,true,true); feed.set(a.id,p,false,true);
            db.update("UPDATE post_likes SET created_at=:time WHERE post_id=:id",args("time",time,"id",p));
            db.update("UPDATE post_saves SET created_at=:time WHERE post_id=:id",args("time",time,"id",p));
        }
        Collections.reverse(expected);
        for(String path:List.of("liked-posts","saved-posts")) {
            var first=call(get("/api/v1/me/"+path+"?size=2"),a,200); String cursor=first.get("nextCursor").asText();
            assertEquals(expected.get(0).longValue(),first.get("items").get(0).get("post").get("id").asLong());
            long newer=publish(owner); feed.set(a.id,newer,"liked-posts".equals(path),true);
            var second=call(get("/api/v1/me/"+path+"?size=2&cursor="+cursor),a,200);
            assertEquals(expected.get(2).longValue(),second.get("items").get(0).get("post").get("id").asLong());
            call(get("/api/v1/me/"+path+"?cursor="+cursor),b,400);
            call(get("/api/v1/me/comments?cursor="+cursor),a,400);
            call(get("/api/v1/me/"+path+"?size=0"),a,400); call(get("/api/v1/me/"+path+"?size=51"),a,400);
            call(get("/api/v1/me/"+path+"?cursor=bad"),a,400);
        }
    }
    @Test void ownCommentsOrderIncludesRepliesButNotOthersOrDeletedThreads() throws Exception {
        var owner=user(); var a=user(); var b=user(); long p=publish(owner);
        long foreign=comment(b,p,"foreign",null), root=comment(a,p,"own root",null), reply=comment(a,p,"own reply",foreign);
        comment(b,p,"their reply",root);
        var first=call(get("/api/v1/me/comments?size=1"),a,200);
        assertEquals(reply,first.get("items").get(0).get("commentId").asLong());
        var second=call(get("/api/v1/me/comments?size=1&cursor="+first.get("nextCursor").asText()),a,200);
        assertEquals(root,second.get("items").get(0).get("commentId").asLong());
        call(delete("/api/v1/comments/"+foreign),a,404);
        call(delete("/api/v1/comments/"+root),a,204);
        assertEquals(2,posts.detail(a.id,p).commentCount()); assertEquals(1,list(a,"comments").size());
        assertEquals("foreign",list(b,"comments").get(0).get("body").asText());
        comments.delete(b.id,foreign); assertEquals(0,list(a,"comments").size());
        assertNotNull(posts.detail(owner.id,p));
    }
    @Test void privacyPendingFriendsOnlyMeUnfollowAndDeletedNeverLeakPreview() throws Exception {
        var owner=user(); var a=user(); long p=publish(owner);
        feed.set(a.id,p,true,true); feed.set(a.id,p,false,true); comment(a,p,"mine",null);
        privacy(owner,true); relationships.follow(a.id,owner.id);
        for(String path:List.of("liked-posts","saved-posts","comments")) assertEquals(0,list(a,path).size());
        var pending=relationships.requests(owner.id,0,50).items().stream().filter(r->r.requesterId().equals(a.id)).findFirst().orElseThrow();
        relationships.respond(owner.id,pending.id(),true);
        for(String path:List.of("liked-posts","saved-posts","comments")) assertEquals(1,list(a,path).size());
        posts.audience(owner.id,p,"FRIENDS"); assertEquals(0,list(a,"liked-posts").size());
        relationships.follow(owner.id,a.id); assertEquals(1,list(a,"liked-posts").size());
        relationships.unfollow(a.id,owner.id); assertEquals(0,list(a,"comments").size());
        posts.audience(owner.id,p,"ONLY_ME"); assertEquals(0,list(a,"saved-posts").size());
        posts.delete(owner.id,p);
        for(String path:List.of("liked-posts","saved-posts","comments")) assertEquals(0,list(a,path).size());
        assertEquals(1,db.count("SELECT COUNT(*) FROM post_likes WHERE post_id=:id",args("id",p)));
    }
    @Test void unlikeAndUnsaveAcknowledgeWithoutDeletingOriginalPost() throws Exception {
        var owner=user(); var a=user(); long p=publish(owner);
        feed.set(a.id,p,true,true); feed.set(a.id,p,false,true);
        var response=call(delete("/api/v1/posts/"+p+"/like"),a,200);
        assertFalse(response.get("likedByMe").asBoolean()); assertEquals(0,response.get("likeCount").asInt());
        call(delete("/api/v1/posts/"+p+"/save"),a,200);
        assertEquals(0,list(a,"liked-posts").size()); assertEquals(0,list(a,"saved-posts").size());
        assertNotNull(posts.detail(a.id,p)); assertNotNull(posts.detail(owner.id,p));
    }
    @Test void revokeBetweenScanAndProjectionStillHidesPayloadAndAdvancesCursor() {
        var owner=user(); var a=user(); long first=publish(owner), second=publish(owner);
        feed.set(a.id,first,true,true); feed.set(a.id,second,true,true);
        doAnswer(invocation -> {
            var rows=invocation.callRealMethod();
            privacy(owner,true);
            return rows;
        }).when(repo).page(eq(a.id),eq("LIKES"),anyInt(),isNull());
        var result=activity.list(a.id,"LIKES",1,null);
        assertTrue(result.items().isEmpty()); assertNotNull(result.nextCursor());
    }
}
