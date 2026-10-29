package vn.gomate.relationship.service;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import vn.gomate.common.ApiException;
import vn.gomate.event.service.InteractionEventService;
import vn.gomate.relationship.dto.SocialRelationshipDtos;
import vn.gomate.relationship.repository.SocialRelationshipRepository;

@Service
public class SocialRelationshipService {
 private static final int DEFAULT_SIZE=20;
 private static final int MAX_SIZE=50;

 private final SocialRelationshipRepository repo;
 private final InteractionEventService events;
 private final vn.gomate.relationship.block.GlobalBlockPolicy blocks;

 public SocialRelationshipService(SocialRelationshipRepository repo,InteractionEventService events,vn.gomate.relationship.block.GlobalBlockPolicy blocks) {
  this.repo=repo;
  this.events=events;
  this.blocks=blocks;
 }

 @Transactional
 public SocialRelationshipDtos.RelationshipState follow(UUID currentUserId,UUID targetUserId) {
  validateTarget(currentUserId,targetUserId);
  blocks.lockPair(currentUserId,targetUserId);
  blocks.requireAllowed(currentUserId,targetUserId);
  if(!repo.isFollowing(currentUserId,targetUserId)) {
   if(repo.isPrivate(targetUserId)) {
    if(!repo.pending(currentUserId,targetUserId)) repo.requestFollow(currentUserId,targetUserId);
   } else {
    // A fresh explicit follow on a PUBLIC account supersedes its old request.
    repo.cancelPending(currentUserId,targetUserId);
    repo.follow(currentUserId,targetUserId);
    boolean mutual=repo.isFollowing(targetUserId,currentUserId);
    afterCommit(() -> events.recordUserFollowed(currentUserId,targetUserId,mutual));
   }
  }
  var state=getRelationship(currentUserId,targetUserId);
  return state;
 }

 @Transactional
 public SocialRelationshipDtos.RelationshipState unfollow(UUID currentUserId,UUID targetUserId) {
  validateTarget(currentUserId,targetUserId);
  repo.lockTarget(targetUserId);
  repo.cancelPending(currentUserId,targetUserId);
  boolean wasFollowing=repo.isFollowing(currentUserId,targetUserId);
  repo.unfollow(currentUserId,targetUserId);
  var state=getRelationship(currentUserId,targetUserId);
  if(wasFollowing) afterCommit(() -> events.recordUserUnfollowed(currentUserId,targetUserId,state.mutualFriend()));
  return state;
 }

 public boolean isFollowing(UUID userA,UUID userB) {
  return !blocks.either(userA,userB) && repo.isFollowing(userA,userB);
 }

 public boolean isMutualFriend(UUID userA,UUID userB) {
  return !blocks.either(userA,userB) && repo.isFollowing(userA,userB) && repo.isFollowing(userB,userA);
 }

 public void requireInteraction(UUID a,UUID b) {blocks.requireAllowed(a,b);}
 public void lockInteractions(UUID actor,Collection<UUID> targets) {var ids=new ArrayList<UUID>(targets);ids.add(actor);blocks.lockUsers(ids);}
 public List<UUID> visiblePeople(UUID viewer,List<UUID> people) {var hidden=blocks.hidden(viewer,people);return people.stream().filter(id->!hidden.contains(id)).toList();}
 public void lockInteraction(UUID a,UUID b) {blocks.lockPair(a,b);blocks.requireAllowed(a,b);}

 public SocialRelationshipDtos.RelationshipState getRelationship(UUID currentUserId,UUID targetUserId) {
  if(currentUserId.equals(targetUserId)) throw new ApiException(400,"SELF_RELATIONSHIP_NOT_ALLOWED","Không thể kiểm tra quan hệ với chính mình.");
  if(!repo.activeUser(targetUserId)) throw new ApiException(404,"USER_NOT_FOUND","Không tìm thấy người dùng.");
  blocks.requireAllowed(currentUserId,targetUserId);
  boolean followingByMe=repo.isFollowing(currentUserId,targetUserId);
  boolean followsMe=repo.isFollowing(targetUserId,currentUserId);
  return new SocialRelationshipDtos.RelationshipState(targetUserId,followingByMe,followsMe,followingByMe && followsMe,
   repo.isPrivate(targetUserId),repo.pending(currentUserId,targetUserId));
 }

 public SocialRelationshipDtos.Page<SocialRelationshipDtos.UserSummary> listFollowing(UUID currentUserId,int page,int size) {
  var paging=paging(page,size);
  return new SocialRelationshipDtos.Page<>(
   repo.following(currentUserId,paging.size(),paging.offset()),
   paging.page(),
   paging.size(),
   repo.countFollowing(currentUserId)
  );
 }

 public SocialRelationshipDtos.Page<SocialRelationshipDtos.UserSummary> listFollowers(UUID currentUserId,int page,int size) {
  var paging=paging(page,size);
  return new SocialRelationshipDtos.Page<>(
   repo.followers(currentUserId,paging.size(),paging.offset()),
   paging.page(),
   paging.size(),
   repo.countFollowers(currentUserId)
  );
 }

 public SocialRelationshipDtos.Page<SocialRelationshipDtos.UserSummary> listMutualFriends(UUID currentUserId,int page,int size) {
  var paging=paging(page,size);
  return new SocialRelationshipDtos.Page<>(
   repo.mutualFriends(currentUserId,paging.size(),paging.offset()),
   paging.page(),
   paging.size(),
   repo.countMutualFriends(currentUserId)
  );
 }

 public SocialRelationshipDtos.Page<SocialRelationshipDtos.UserSummary> people(UUID viewerId,UUID targetId,boolean friends,int page,int size) {
  blocks.requireAllowed(viewerId,targetId);
  if(!repo.activeUser(targetId)) throw ApiException.notFound();
  var paging=paging(page,size);
  if(!viewerId.equals(targetId) && repo.isPrivate(targetId) && !repo.isFollowing(viewerId,targetId)) {
   throw new ApiException(403,"PRIVATE_PROFILE","Hãy gửi yêu cầu theo dõi để xem danh sách này.");
  }
  return new SocialRelationshipDtos.Page<>(repo.people(viewerId,targetId,friends,paging.size(),paging.offset()),
   paging.page(),paging.size(),repo.countPeople(viewerId,targetId,friends));
 }

 public SocialRelationshipDtos.Page<SocialRelationshipDtos.FollowRequest> requests(UUID ownerId,int page,int size) {
  var p=paging(page,size);
  return new SocialRelationshipDtos.Page<>(repo.requests(ownerId,p.size(),p.offset()),p.page(),p.size(),repo.requestCount(ownerId));
 }

 @Transactional
 public SocialRelationshipDtos.RelationshipState respond(UUID ownerId,UUID requestId,boolean accept) {
  var row=repo.request(requestId);
  if(!ownerId.equals(row.get("targetId"))) throw ApiException.notFound();
  UUID requester=(UUID)row.get("requesterId");
  blocks.lockPair(ownerId,requester);
  blocks.requireAllowed(ownerId,requester);
  row=repo.request(requestId);
  UUID requesterId=(UUID)row.get("requesterId");
  String desired=accept?"ACCEPTED":"REJECTED";
  if(!repo.activeUser(requesterId)) throw ApiException.notFound();
  if(desired.equals(row.get("status"))) return getRelationship(ownerId,requesterId);
  if(!"PENDING".equals(row.get("status"))) {
   throw new ApiException(409,"FOLLOW_REQUEST_RESOLVED","Yêu cầu không còn chờ xác nhận.");
  }
  repo.respond(requestId,desired);
  if(accept && !repo.isFollowing(requesterId,ownerId)) {
   repo.follow(requesterId,ownerId);
   boolean mutual=repo.isFollowing(ownerId,requesterId);
   afterCommit(() -> events.recordUserFollowed(requesterId,ownerId,mutual));
  }
  return getRelationship(ownerId,requesterId);
 }

 private void validateTarget(UUID currentUserId,UUID targetUserId) {
  if(currentUserId.equals(targetUserId)) throw new ApiException(400,"SELF_FOLLOW_NOT_ALLOWED","Bạn không thể tự theo dõi chính mình.");
  if(!repo.activeUser(targetUserId)) throw new ApiException(404,"USER_NOT_FOUND","Không tìm thấy người dùng.");
 }

 private Paging paging(int page,int size) {
  int safePage=Math.max(0,page);
  int safeSize=size<=0?DEFAULT_SIZE:Math.min(size,MAX_SIZE);
  return new Paging(safePage,safeSize,safePage*safeSize);
 }

 private void afterCommit(Runnable action) {
  if(TransactionSynchronizationManager.isSynchronizationActive()) {
   TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
    @Override public void afterCommit() { action.run(); }
   });
  } else {
   action.run();
  }
 }

 private record Paging(int page,int size,int offset) {}
}
