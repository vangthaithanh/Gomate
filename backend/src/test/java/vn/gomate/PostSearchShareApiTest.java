package vn.gomate;

import com.fasterxml.jackson.databind.*;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.social.post.*;
import vn.gomate.message.service.*;
import vn.gomate.message.dto.MessageDtos;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PostSearchShareApiTest {
    @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired AuthService auth; @Autowired Db db;
    @Autowired PostService posts; @Autowired PostSearchService search;
    @Autowired vn.gomate.user.service.RecentSearchService recent;
    @Autowired vn.gomate.relationship.service.SocialRelationshipService relationships;
    @Autowired vn.gomate.user.service.UserService users;
    @Autowired ConversationService conversations;
    @MockitoBean MessageMongoService messages;
    record User(UUID id,String token) {}
    User user() {
        String key="search"+UUID.randomUUID().toString().replace("-","").substring(0,14);
        var value=auth.register(new AuthDtos.Register(key+"@example.com","TestPass123!",key));
        return new User((UUID)((Map<?,?>)value.get("user")).get("id"),"Bearer "+value.get("accessToken"));
    }
    JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,User u,int status) throws Exception {
        var res=mvc.perform(request.header("Authorization",u.token)).andExpect(status().is(status)).andReturn().getResponse();
        return res.getContentAsByteArray().length==0?json.createObjectNode():json.readTree(res.getContentAsByteArray());
    }
    long publish(User u,String caption,String... tags) {
        UUID id=UUID.randomUUID();
        db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,'hash','IMAGE','READY',:pid,:thumb,'png','image/png',4,2,2)",args("id",id,"owner",u.id,"pid",id.toString(),"thumb",id+"_cover"));
        return posts.publish(u.id,new PostDtos.Publish(UUID.randomUUID(),caption,"EVERYONE",new ArrayList<>(List.of(id)),List.of(tags),new ArrayList<>(),null)).id();
    }
    void privacy(User u,boolean value) {users.updateProfile(u.id,new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,null,null,null,null,value));}
    void mutual(User a,User b) {relationships.follow(a.id,b.id);relationships.follow(b.id,a.id);}
    void stub() {
        when(messages.saveText(any(),any(),anyString(),any(),any(),anyString())).thenAnswer(i->new MessageDtos.MessageItem("first",i.getArgument(0),i.getArgument(1),"TEXT",i.getArgument(2),null,Instant.now()));
        when(messages.savePostReference(any(),any(),anyLong(),any(),anyString(),anyString())).thenAnswer(i->new MessageDtos.MessageItem("safe-ref",i.getArgument(0),i.getArgument(1),"POST_SHARE",i.getArgument(5),Map.of("postId",i.getArgument(2)),Instant.now()));
    }
    JsonNode send(User sender,long p,UUID key,List<Map<String,Object>> targets) throws Exception {
        return call(post("/api/v1/posts/"+p+"/shares").contentType("application/json").content(json.writeValueAsBytes(Map.of("clientRequestId",key,"targets",targets))),sender,200);
    }
    @Test void postVietnameseCaptionHashtagAndProtectedThumbnail() throws Exception {
        var a=user(); String tag="t"+UUID.randomUUID().toString().replace("-","");
        long p=publish(a,"Đà Nẵng "+tag,tag,"dulịch");
        var accent=search.search(a.id,"Đà Nẵng "+tag,List.of(),20,null);
        var plain=search.search(a.id,"Da Nang "+tag,List.of(),20,null);
        assertEquals(accent.items(),plain.items()); assertEquals(p,plain.items().get(0).id());
        assertTrue(plain.items().get(0).thumbnailUrl().startsWith("/posts/"));
        assertEquals(1,search.search(a.id,"",List.of(tag,"dulịch"),20,null).items().size());
        assertEquals(0,search.search(a.id,"",List.of(tag,"missing"),20,null).items().size());
        assertEquals(1,search.search(a.id,"#"+tag,List.of(),20,null).items().size());
        assertEquals(plain.items(),search.search(a.id,java.text.Normalizer.normalize("Đà Nẵng "+tag,java.text.Normalizer.Form.NFD),List.of(),20,null).items());
        assertFalse(json.writeValueAsString(plain).contains("cloudinary"));
        call(get("/api/v1/search/posts").param("q",tag),a,200);
        mvc.perform(get("/api/v1/search/posts")).andExpect(status().isUnauthorized());
    }
    @Test void privacyPendingUnfollowAudienceInactiveDeleteAndCountsNeverLeak() {
        var owner=user(); var viewer=user(); String tag="priv"+UUID.randomUUID().toString().replace("-","");
        long p=publish(owner,tag,tag); privacy(owner,true);
        relationships.follow(viewer.id,owner.id);
        assertTrue(search.search(viewer.id,tag,List.of(),20,null).items().isEmpty());
        assertTrue(search.hashtags(viewer.id,tag).isEmpty());
        var request=relationships.requests(owner.id,0,50).items().stream().filter(r->r.requesterId().equals(viewer.id)).findFirst().orElseThrow();
        relationships.respond(owner.id,request.id(),true);
        assertEquals(1,search.hashtags(viewer.id,tag).get(0).get("postCount") instanceof Number n?n.intValue():-1);
        posts.audience(owner.id,p,"FRIENDS"); assertTrue(search.hashtags(viewer.id,tag).isEmpty());
        relationships.follow(owner.id,viewer.id); assertEquals(1,search.search(viewer.id,tag,List.of(),20,null).items().size());
        relationships.unfollow(viewer.id,owner.id); assertTrue(search.hashtags(viewer.id,tag).isEmpty());
        posts.audience(owner.id,p,"ONLY_ME"); assertTrue(search.search(viewer.id,tag,List.of(),20,null).items().isEmpty());
        assertEquals(1,search.search(owner.id,tag,List.of(),20,null).items().size());
        db.update("UPDATE users SET status='LOCKED' WHERE id=:id",args("id",owner.id));
        assertTrue(search.search(owner.id,tag,List.of(),20,null).items().isEmpty());
        db.update("UPDATE users SET status='ACTIVE' WHERE id=:id",args("id",owner.id));
        posts.delete(owner.id,p); assertTrue(search.hashtags(owner.id,tag).isEmpty());
    }
    @Test void keysetScopeAndRecheckEachPage() {
        var owner=user(); var viewer=user(); String q="page"+UUID.randomUUID();
        for(int i=0;i<4;i++) publish(owner,q);
        var first=search.search(viewer.id,q,List.of(),2,null); assertEquals(2,first.items().size());assertNotNull(first.nextCursor());
        publish(owner,q);
        var second=search.search(viewer.id,q,List.of(),2,first.nextCursor()); assertEquals(2,second.items().size());
        assertTrue(Collections.disjoint(first.items(),second.items()));
        assertThrows(ApiException.class,()->search.search(owner.id,q,List.of(),2,first.nextCursor()));
        assertThrows(ApiException.class,()->search.search(viewer.id,"other",List.of(),2,first.nextCursor()));
        privacy(owner,true);
        assertTrue(search.search(viewer.id,q,List.of(),2,first.nextCursor()).items().isEmpty());
    }
    @Test void recentEightDedupAccountIsolationDeleteAndNewServicePersistence() throws Exception {
        var a=user(); var b=user();
        for(int i=0;i<10;i++) recent.submit(a.id,"query "+i);
        assertEquals(8,recent.list(a.id).size());
        recent.submit(a.id,"Đà Nẵng"); recent.submit(a.id," da   nang ");
        assertEquals("da nang",recent.list(a.id).get(0));assertEquals(8,recent.list(a.id).size());
        assertTrue(recent.list(b.id).isEmpty());
        assertEquals(recent.list(a.id),new vn.gomate.user.service.RecentSearchService(new vn.gomate.user.repository.RecentSearchRepository(db)).list(a.id));
        call(delete("/api/v1/search/recent").param("q","Đà Nẵng"),a,200);
        assertFalse(recent.list(a.id).contains("da nang"));
        call(post("/api/v1/search/recent").contentType("application/json").content("{\"query\":\"Hồ\"}"),a,200);
        call(get("/api/v1/search/recent"),a,200);
    }
    @Test void placeAndUserSearchFoldAndNearbyNeedsRealGps() throws Exception {
        var a=user(); var b=user(); users.updateProfile(b.id,new vn.gomate.user.dto.UserDtos.ProfileUpdate(null,"Đà Nẵng Search",null,null,null,null));
        assertTrue(call(get("/api/v1/users/search").param("q","Da Nang Search"),a,200).get("items").toString().contains(b.id.toString()));
        call(get("/api/v1/search/places").param("q","Đà Nẵng"),a,200);
        call(get("/api/v1/search/places").param("filters","nearby"),a,400);
        call(get("/api/v1/search/places").param("filters","nearby").param("latitude","11.94").param("longitude","108.44"),a,200);
        call(get("/api/v1/search/places").param("filters","invented"),a,400);
    }
    @Test void shareMutualOnlyAcceptedFollowingAndNoPendingAutoAccept() throws Exception {
        stub(); var a=user(); var friend=user(); var following=user(); var pending=user(); var outsider=user(); long p=publish(a,"Secret caption");
        mutual(a,friend); relationships.follow(a.id,following.id); relationships.follow(a.id,pending.id);
        var accepted=conversations.sendDirect(a.id,new MessageDtos.DirectSendRequest(following.id,UUID.randomUUID(),"First",null)).conversation(); conversations.accept(accepted.conversationId(),following.id);
        var request=conversations.sendDirect(a.id,new MessageDtos.DirectSendRequest(pending.id,UUID.randomUUID(),"First",null)).conversation();
        var targets=call(get("/api/v1/posts/"+p+"/share-targets"),a,200).toString();
        assertTrue(targets.contains(friend.id.toString()));assertTrue(targets.contains(following.id.toString()));
        assertFalse(targets.contains(pending.id.toString()));assertFalse(targets.contains(outsider.id.toString()));
        var results=send(a,p,UUID.randomUUID(),List.of(Map.of("type","USER","targetId",friend.id),Map.of("type","USER","targetId",pending.id)));
        assertTrue(results.get(0).get("success").asBoolean());assertFalse(results.get(1).get("success").asBoolean());
        assertEquals("PENDING",db.one("SELECT status FROM conversations WHERE id=:id",args("id",request.conversationId())).get("status"));
        relationships.unfollow(a.id,following.id); privacy(following,true);
        assertFalse(users.publicProfile(a.id,following.id).canInitiateMessage());
        assertTrue(call(get("/api/v1/posts/"+p+"/share-targets"),a,200).toString().contains(following.id.toString()));
        assertTrue(send(a,p,UUID.randomUUID(),List.of(Map.of("type","USER","targetId",following.id))).get(0).get("success").asBoolean());
    }
    @Test void failedFirstShareDoesNotCommitEmptyAcceptedConversation() throws Exception {
        stub();var a=user();var b=user();mutual(a,b);long post=publish(a,"Safe failure");
        when(messages.savePostReference(any(),any(),anyLong(),any(),anyString(),anyString())).thenThrow(new ApiException(503,"MESSAGE_STORE_UNAVAILABLE","Injected failure"));
        assertFalse(send(a,post,UUID.randomUUID(),List.of(Map.of("type","USER","targetId",b.id))).get(0).get("success").asBoolean());
        assertEquals(0,db.count("SELECT COUNT(*) FROM conversations WHERE type='DIRECT' AND (user_low_id=:a OR user_high_id=:a)",args("a",a.id)));
    }
    @Test void directShareDeliversReferenceWithoutGrantingRecipientPostAccess() throws Exception {
        stub(); var author=user(); var sender=user(); var recipient=user(); mutual(sender,recipient);
        long p=publish(author,"Private reference");privacy(author,true);
        relationships.follow(sender.id,author.id);
        var request=relationships.requests(author.id,0,50).items().stream().filter(r->r.requesterId().equals(sender.id)).findFirst().orElseThrow();relationships.respond(author.id,request.id(),true);
        assertTrue(call(get("/api/v1/posts/"+p+"/share-targets"),sender,200).toString().contains(recipient.id.toString()));
        assertTrue(send(sender,p,UUID.randomUUID(),List.of(Map.of("type","USER","targetId",recipient.id))).get(0).get("success").asBoolean());
        call(get("/api/v1/posts/"+p),recipient,404);
        String media=posts.detail(author.id,p).media().get(0).id().toString();
        call(get("/api/v1/posts/"+p+"/media/"+media+"/thumbnail"),recipient,404);
        posts.audience(author.id,p,"ONLY_ME");
        call(get("/api/v1/posts/"+p+"/share-targets"),sender,404);
        call(post("/api/v1/posts/"+p+"/shares").contentType("application/json").content(json.writeValueAsBytes(Map.of(
            "clientRequestId",UUID.randomUUID(),"targets",List.of(Map.of("type","USER","targetId",recipient.id))))),sender,404);
    }
    @Test void ownerOnlyMeShareToAcceptedDmKeepsPermissionAndRetryRules() throws Exception {
        stub();var a=user();var b=user();mutual(a,b);long post=publish(a,"Must not leak this caption");
        var chat=conversations.sendDirect(a.id,new MessageDtos.DirectSendRequest(b.id,UUID.randomUUID(),"Hello",null)).conversation();
        posts.audience(a.id,post,"ONLY_ME");
        relationships.unfollow(a.id,b.id);relationships.unfollow(b.id,a.id);privacy(b,true);
        var targets=call(get("/api/v1/posts/"+post+"/share-targets"),a,200);
        assertTrue(targets.toString().contains(b.id.toString()));
        assertEquals(1,java.util.stream.StreamSupport.stream(targets.spliterator(),false).filter(t->t.get("targetId").asText().equals(b.id.toString())).count());
        var key=UUID.randomUUID();
        var first=send(a,post,key,List.of(Map.of("type","USER","targetId",b.id)));
        var retry=send(a,post,key,List.of(Map.of("type","USER","targetId",b.id)));
        assertTrue(first.get(0).get("success").asBoolean());
        assertEquals(first.get(0).get("messageId"),retry.get(0).get("messageId"));
        assertFalse(first.toString().contains("Must not leak"));
        call(get("/api/v1/posts/"+post),b,404);
        String media=posts.detail(a.id,post).media().get(0).id().toString();
        call(get("/api/v1/posts/"+post+"/media/"+media),b,404);
        conversations.setBlocked(chat.conversationId(),b.id,true);
        assertFalse(call(get("/api/v1/posts/"+post+"/share-targets"),a,200).toString().contains(b.id.toString()));
        assertFalse(send(a,post,UUID.randomUUID(),List.of(Map.of("type","USER","targetId",b.id))).get(0).get("success").asBoolean());
    }
    @Test void groupsReceiveReferenceNotPrivatePreviewAndKickedClosedDenied() throws Exception {
        stub(); var a=user();var b=user(); long p=publish(a,"Only owner sees this");posts.audience(a.id,p,"ONLY_ME");
        UUID trip=UUID.randomUUID(),chat=UUID.randomUUID();
        db.update("INSERT INTO trips(id,owner_id,title,trip_type,start_date,end_date,timezone) VALUES(:id,:owner,'Share group','GROUP',CURRENT_DATE,CURRENT_DATE,'Asia/Ho_Chi_Minh')",args("id",trip,"owner",a.id));
        db.update("INSERT INTO trip_members(trip_id,user_id,role) VALUES(:id,:a,'LEADER'),(:id,:b,'MEMBER')",args("id",trip,"a",a.id,"b",b.id));
        db.update("INSERT INTO conversations(id,type,status,created_by,linked_trip_id) VALUES(:id,'GROUP','ACCEPTED',:owner,:trip)",args("id",chat,"owner",a.id,"trip",trip));
        db.update("INSERT INTO conversation_members(conversation_id,user_id,role) VALUES(:id,:a,'LEADER'),(:id,:b,'MEMBER')",args("id",chat,"a",a.id,"b",b.id));
        assertTrue(send(a,p,UUID.randomUUID(),List.of(Map.of("type","GROUP","targetId",chat))).get(0).get("success").asBoolean());
        assertThrows(ApiException.class,()->posts.detail(b.id,p));
        // Global Block never removes group messaging or changes reference permissions.
        call(put("/api/v1/users/"+b.id+"/block"),a,200);
        assertTrue(send(a,p,UUID.randomUUID(),List.of(Map.of("type","GROUP","targetId",chat))).get(0).get("success").asBoolean());
        assertThrows(ApiException.class,()->posts.detail(b.id,p));
        call(delete("/api/v1/users/"+b.id+"/block"),a,200);

        db.update("UPDATE conversations SET status='CLOSED' WHERE id=:id",args("id",chat));
        assertFalse(send(a,p,UUID.randomUUID(),List.of(Map.of("type","GROUP","targetId",chat))).get(0).get("success").asBoolean());
        assertFalse(call(get("/api/v1/posts/"+p+"/share-targets"),a,200).toString().contains(chat.toString()));
        db.update("UPDATE conversations SET status='ACCEPTED' WHERE id=:id",args("id",chat));
        db.update("UPDATE trip_members SET status='KICKED' WHERE trip_id=:id AND user_id=:user",args("id",trip,"user",b.id));
        long other=publish(b,"Removed member");
        assertFalse(send(b,other,UUID.randomUUID(),List.of(Map.of("type","GROUP","targetId",chat))).get(0).get("success").asBoolean());
    }
    @Test void invalidLimitCursorUnknownHashtagAndLiteralWildcardDoNotWidenSearch() throws Exception {
        var a=user();long p=publish(a,"wildcard test");
        assertTrue(search.search(a.id,"%",List.of(),20,null).items().isEmpty());
        call(get("/api/v1/search/posts?size=0"),a,400);
        call(get("/api/v1/search/posts?cursor=broken"),a,400);
        call(get("/api/v1/search/posts").param("q","x".repeat(201)),a,400);
        assertThrows(ApiException.class,()->search.search(a.id,"",List.of("a","b","c","d","e","f"),20,null));
        posts.delete(a.id,p);assertTrue(search.search(a.id,"wildcard test",List.of(),20,null).items().isEmpty());
    }
}
