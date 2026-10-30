package vn.gomate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentMatchers;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import vn.gomate.recommendation.service.RecommendationService;
import vn.gomate.relationship.block.GlobalBlockService;
import vn.gomate.relationship.service.SocialRelationshipService;
import vn.gomate.social.post.*;
import static vn.gomate.common.Db.args;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties="spring.datasource.url=jdbc:h2:mem:post_recommendation;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1")
@AutoConfigureMockMvc @ActiveProfiles("test")
class PostRecommendationFeedApiTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired AuthService auth;
    @Autowired Db db;
    @Autowired PostService posts;
    @Autowired PostRecommendationFeedService recommendations;
    @Autowired PostRecommendationRepository recommendationRepository;
    @Autowired SocialRelationshipService relationships;
    @Autowired GlobalBlockService blocks;
    @MockitoSpyBean RecommendationService placeRecommendations;

    record User(UUID id, String token) {}

    @BeforeEach
    void isolateFromEarlierFixtureData() {
        db.update("UPDATE posts SET audience='ONLY_ME'", Map.of());
    }

    @Test
    void friendsThenFollowedThenScoredRemainderAndCursorHasNoDuplicates() {
        var viewer = user();
        var friend = user();
        var followed = user();
        var stranger = user();
        relationships.follow(viewer.id, friend.id);
        relationships.follow(friend.id, viewer.id);
        relationships.follow(viewer.id, followed.id);

        long friendOld = post(friend, "EVERYONE", List.of("quiet"), OffsetDateTime.now(ZoneOffset.UTC).minusHours(3));
        long friendNew = post(friend, "EVERYONE", List.of("quiet"), OffsetDateTime.now(ZoneOffset.UTC).minusHours(2));
        long followedPost = post(followed, "EVERYONE", List.of("followed"), OffsetDateTime.now(ZoneOffset.UTC).minusHours(1));
        long scoredRemainder = post(stranger, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(30));

        var seen = new ArrayList<Long>();
        String cursor = null;
        do {
            var page = recommendations.feed(viewer.id, 2, cursor, null, null, null);
            page.items().forEach(item -> seen.add(item.id()));
            cursor = page.nextCursor();
        } while (cursor != null);

        assertEquals(List.of(friendNew, friendOld, followedPost, scoredRemainder), seen);
        assertEquals(seen.size(), new HashSet<>(seen).size());
    }

    @Test
    void relationshipChangesApplyOnRefreshWhileLoadMoreKeepsItsSnapshot() {
        var viewer = user();
        var target = user();
        var followed = user();
        var stranger = user();
        relationships.follow(viewer.id, followed.id);

        OffsetDateTime base = OffsetDateTime.now(ZoneOffset.UTC);
        long targetPost = post(target, "EVERYONE", List.of(), base.minusHours(3));
        long followedPost = post(followed, "EVERYONE", List.of(), base.minusHours(2));
        long strangerPost = post(stranger, "EVERYONE", List.of(), base.minusHours(1));

        var firstPage = recommendations.feed(viewer.id, 1, null, null, null, null);
        assertEquals(List.of(followedPost), ids(firstPage));
        assertEquals(List.of(followedPost, strangerPost, targetPost),
            ids(recommendations.feed(viewer.id, 50, null, null, null, null)));

        relationships.follow(viewer.id, target.id);
        assertEquals(List.of(strangerPost, targetPost),
            ids(recommendations.feed(viewer.id, 50, firstPage.nextCursor(), null, null, null)));
        assertEquals(List.of(followedPost, targetPost, strangerPost),
            ids(recommendations.feed(viewer.id, 50, null, null, null, null)));

        relationships.follow(target.id, viewer.id);
        assertEquals(List.of(targetPost, followedPost, strangerPost),
            ids(recommendations.feed(viewer.id, 50, null, null, null, null)));

        relationships.unfollow(target.id, viewer.id);
        assertEquals(List.of(followedPost, targetPost, strangerPost),
            ids(recommendations.feed(viewer.id, 50, null, null, null, null)));

        relationships.unfollow(viewer.id, target.id);
        assertEquals(List.of(followedPost, strangerPost, targetPost),
            ids(recommendations.feed(viewer.id, 50, null, null, null, null)));
    }

    @Test
    void friendAudienceUsesCurrentMutualRelationshipOnEachRefresh() {
        var viewer = user();
        var owner = user();
        long friendsOnly = post(owner, "FRIENDS", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));

        assertFalse(ids(recommendations.feed(viewer.id, 50, null, null, null, null)).contains(friendsOnly));
        relationships.follow(viewer.id, owner.id);
        assertFalse(ids(recommendations.feed(viewer.id, 50, null, null, null, null)).contains(friendsOnly));
        relationships.follow(owner.id, viewer.id);
        assertTrue(ids(recommendations.feed(viewer.id, 50, null, null, null, null)).contains(friendsOnly));
        relationships.unfollow(owner.id, viewer.id);
        assertFalse(ids(recommendations.feed(viewer.id, 50, null, null, null, null)).contains(friendsOnly));
    }

    @Test
    void ownPostStaysVisibleInTheScoredRemainderBucket() {
        var viewer = user();
        long own = post(viewer, "ONLY_ME", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));

        var row = recommendationRepository.candidates(
            viewer.id,
            OffsetDateTime.now(ZoneOffset.UTC)
        ).stream().filter(candidate -> ((Number) candidate.get("id")).longValue() == own).findFirst().orElseThrow();
        assertEquals(2, ((Number) row.get("bucket")).intValue());
        assertTrue(ids(recommendations.feed(viewer.id, 50, null, null, null, null)).contains(own));
    }

    @Test
    void snapshotRechecksAudienceDeletionAndGlobalBlock() {
        var viewer = user();
        var owner = user();
        long first = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));
        long hiddenAfterSnapshot = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusHours(1));

        var firstPage = recommendations.feed(viewer.id, 1, null, null, null, null);
        assertEquals(first, firstPage.items().get(0).id());
        posts.audience(owner.id, hiddenAfterSnapshot, "ONLY_ME");
        assertTrue(recommendations.feed(viewer.id, 1, firstPage.nextCursor(), null, null, null).items().isEmpty());
        posts.audience(owner.id, first, "ONLY_ME");

        long deletionFirst = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));
        long deletedAfterSnapshot = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusHours(1));
        var beforeDelete = recommendations.feed(viewer.id, 1, null, null, null, null);
        assertEquals(deletionFirst, beforeDelete.items().get(0).id());
        posts.delete(owner.id, deletedAfterSnapshot);
        assertTrue(recommendations.feed(viewer.id, 1, beforeDelete.nextCursor(), null, null, null).items().isEmpty());
        posts.audience(owner.id, deletionFirst, "ONLY_ME");

        var blockedOwner = user();
        relationships.follow(viewer.id, blockedOwner.id);
        long blockedFirst = post(blockedOwner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));
        long blockedSecond = post(blockedOwner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusHours(1));
        var beforeBlock = recommendations.feed(viewer.id, 1, null, null, null, null);
        assertEquals(blockedFirst, beforeBlock.items().get(0).id());
        blocks.set(viewer.id, blockedOwner.id, true);
        assertTrue(recommendations.feed(viewer.id, 1, beforeBlock.nextCursor(), null, null, null).items().isEmpty());
        assertNotEquals(blockedSecond, beforeBlock.items().get(0).id());
    }

    @Test
    void routeRequiresAuthAndPlaceAiFailureFallsBackWithoutInventingScore() throws Exception {
        mvc.perform(get("/api/v1/feed/recommended")).andExpect(status().isUnauthorized());
        var viewer = user();
        var owner = user();
        long place = place();
        long post = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1), place);
        doThrow(new IllegalStateException("AI unavailable")).when(placeRecommendations)
            .mine(ArgumentMatchers.any(), ArgumentMatchers.any(), ArgumentMatchers.any(), ArgumentMatchers.any(), ArgumentMatchers.anyInt());
        try {
            var response = mvc.perform(get("/api/v1/feed/recommended")
                    .header("Authorization", viewer.token))
                .andExpect(status().isOk()).andReturn();
            JsonNode body = json.readTree(response.getResponse().getContentAsByteArray());
            assertEquals(post, body.path("items").get(0).path("id").asLong());
        } finally {
            reset(placeRecommendations);
        }
    }

    @Test
    void viewedRelationshipPostsHideOnlyOnANewSnapshotAndRemainOnProfile() {
        var viewer = user();
        var owner = user();
        var otherViewer = user();
        relationships.follow(viewer.id, owner.id);
        relationships.follow(owner.id, viewer.id);
        relationships.follow(otherViewer.id, owner.id);

        OffsetDateTime base = OffsetDateTime.now(ZoneOffset.UTC).minusHours(1);
        var oldPosts = new ArrayList<Long>();
        for (int index = 0; index < 10; index++) {
            oldPosts.add(post(owner, "EVERYONE", List.of(), base.plusMinutes(index)));
        }
        var currentSnapshot = recommendations.feed(viewer.id, 1, null, null, null, null);
        var viewed = oldPosts.subList(0, 8);
        viewed.forEach(postId -> recommendations.viewed(viewer.id, postId));

        long newOlder = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(2));
        long newNewest = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));

        // The existing cursor keeps its original membership even after view ACKs.
        var sameSnapshotRemainder = ids(recommendations.feed(
            viewer.id, 50, currentSnapshot.nextCursor(), null, null, null));
        assertTrue(sameSnapshotRemainder.containsAll(viewed));

        assertEquals(
            List.of(newNewest, newOlder, oldPosts.get(9), oldPosts.get(8)),
            all(viewer.id, 2)
        );
        assertEquals(12, all(otherViewer.id, 2).size(), "view history must be per viewer");

        recommendations.viewed(viewer.id, oldPosts.get(9));
        assertEquals(List.of(newNewest, newOlder, oldPosts.get(8)), all(viewer.id, 2));

        var profileIds = posts.list(viewer.id, owner.id, 50, null).items().stream()
            .map(PostDtos.Detail::id).toList();
        assertEquals(12, profileIds.size());
        assertTrue(profileIds.containsAll(viewed), "Home view history must not hide profile posts");
    }

    @Test
    void viewFilterUsesCurrentRelationshipAndNeverFiltersScoredRemainder() {
        var viewer = user();
        var owner = user();
        relationships.follow(viewer.id, owner.id);
        relationships.follow(owner.id, viewer.id);
        long relationshipPost = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(3));
        recommendations.viewed(viewer.id, relationshipPost);

        assertFalse(all(viewer.id, 50).contains(relationshipPost));
        relationships.unfollow(owner.id, viewer.id);
        assertFalse(all(viewer.id, 50).contains(relationshipPost), "still-followed posts remain filtered");
        relationships.unfollow(viewer.id, owner.id);
        assertTrue(all(viewer.id, 50).contains(relationshipPost), "unfollowed post may return to the scored bucket");
        relationships.follow(viewer.id, owner.id);
        assertFalse(all(viewer.id, 50).contains(relationshipPost));

        var stranger = user();
        long olderRemainder = post(stranger, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(2));
        long newerRemainder = post(stranger, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));
        recommendations.viewed(viewer.id, newerRemainder);
        var remainder = all(viewer.id, 50);
        assertTrue(remainder.containsAll(List.of(newerRemainder, olderRemainder)));
        assertTrue(remainder.indexOf(newerRemainder) < remainder.indexOf(olderRemainder));

        relationships.follow(viewer.id, stranger.id);
        assertFalse(all(viewer.id, 50).contains(newerRemainder), "an existing view applies after follow");
        assertTrue(all(viewer.id, 50).contains(olderRemainder));
    }

    @Test
    void viewRouteRequiresCurrentAccessAndIsIdempotent() throws Exception {
        var viewer = user();
        var owner = user();
        long visible = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));

        mvc.perform(put("/api/v1/feed/recommended/{postId}/view", visible))
            .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/feed/recommended").header("Authorization", viewer.token))
            .andExpect(status().isOk());
        assertEquals(0, viewRows(viewer.id, visible), "loading a page is not a view");

        for (int attempt = 0; attempt < 2; attempt++) {
            mvc.perform(put("/api/v1/feed/recommended/{postId}/view", visible)
                    .header("Authorization", viewer.token))
                .andExpect(status().isNoContent())
                .andExpect(header().string("Cache-Control", "private, no-store, max-age=0"));
        }
        assertEquals(1, viewRows(viewer.id, visible));

        long revoked = post(owner, "EVERYONE", List.of(), OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(2));
        posts.audience(owner.id, revoked, "ONLY_ME");
        mvc.perform(put("/api/v1/feed/recommended/{postId}/view", revoked)
                .header("Authorization", viewer.token))
            .andExpect(status().isNotFound());
        assertEquals(0, viewRows(viewer.id, revoked));
    }

    private List<Long> ids(PostDtos.Page page) {
        return page.items().stream().map(PostDtos.Detail::id).toList();
    }

    private List<Long> all(UUID viewer, int size) {
        var result = new ArrayList<Long>();
        String cursor = null;
        do {
            var page = recommendations.feed(viewer, size, cursor, null, null, null);
            page.items().forEach(item -> result.add(item.id()));
            cursor = page.nextCursor();
        } while (cursor != null);
        assertEquals(result.size(), new HashSet<>(result).size());
        return result;
    }

    private long viewRows(UUID viewer, long postId) {
        return db.count("SELECT COUNT(*) FROM post_home_views WHERE viewer_user_id=:viewer AND post_id=:post",
            args("viewer", viewer, "post", postId));
    }

    private User user() {
        String key = "postrec" + UUID.randomUUID().toString().replace("-", "").substring(0, 14);
        var result = auth.register(new AuthDtos.Register(key + "@example.com", "TestPass123!", key));
        return new User((UUID) ((Map<?, ?>) result.get("user")).get("id"), "Bearer " + result.get("accessToken"));
    }

    private long post(User owner, String audience, List<String> tags, OffsetDateTime createdAt) {
        return post(owner, audience, tags, createdAt, null);
    }

    private long post(User owner, String audience, List<String> tags, OffsetDateTime createdAt, Long placeId) {
        UUID media = UUID.randomUUID();
        db.update("INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES(:id,:owner,'hash','IMAGE','READY',:pid,:thumb,'png','image/png',4,2,2)",
            args("id", media, "owner", owner.id, "pid", media.toString(), "thumb", media + "_cover"));
        long id = posts.publish(owner.id, new PostDtos.Publish(UUID.randomUUID(), "recommendation fixture", audience,
            new ArrayList<>(List.of(media)), tags, new ArrayList<>(), placeId)).id();
        db.update("UPDATE posts SET created_at=:time WHERE id=:id", args("id", id, "time", createdAt));
        return id;
    }

    private long place() {
        String code = "rec" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        db.update("INSERT INTO place_categories(code,name) VALUES(:code,:code)", args("code", code));
        long category = ((Number) db.one("SELECT id FROM place_categories WHERE code=:code", args("code", code)).get("id")).longValue();
        db.update("INSERT INTO places(category_id,name,province,latitude,longitude) VALUES(:category,:name,'Dalat',11.94,108.44)",
            args("category", category, "name", code));
        return ((Number) db.one("SELECT id FROM places WHERE name=:name", args("name", code)).get("id")).longValue();
    }
}
