package vn.gomate.relationship.service;

import java.util.Map;
import java.util.UUID;
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

 public SocialRelationshipService(SocialRelationshipRepository repo,InteractionEventService events) {
  this.repo=repo;
  this.events=events;
 }

 @Transactional
 public SocialRelationshipDtos.RelationshipState follow(UUID currentUserId,UUID targetUserId) {
  validateTarget(currentUserId,targetUserId);
  repo.follow(currentUserId,targetUserId);
  var state=getRelationship(currentUserId,targetUserId);
  afterCommit(() -> events.recordUserFollowed(currentUserId,targetUserId,state.mutualFriend()));
  return state;
 }

 @Transactional
 public SocialRelationshipDtos.RelationshipState unfollow(UUID currentUserId,UUID targetUserId) {
  validateTarget(currentUserId,targetUserId);
  repo.unfollow(currentUserId,targetUserId);
  var state=getRelationship(currentUserId,targetUserId);
  afterCommit(() -> events.recordUserUnfollowed(currentUserId,targetUserId,state.mutualFriend()));
  return state;
 }

 public boolean isFollowing(UUID userA,UUID userB) {
  return repo.isFollowing(userA,userB);
 }

 public boolean isMutualFriend(UUID userA,UUID userB) {
  return repo.isFollowing(userA,userB) && repo.isFollowing(userB,userA);
 }

 public SocialRelationshipDtos.RelationshipState getRelationship(UUID currentUserId,UUID targetUserId) {
  if(currentUserId.equals(targetUserId)) throw new ApiException(400,"SELF_RELATIONSHIP_NOT_ALLOWED","Không thể kiểm tra quan hệ với chính mình.");
  if(!repo.activeUser(targetUserId)) throw new ApiException(404,"USER_NOT_FOUND","Không tìm thấy người dùng.");
  boolean followingByMe=repo.isFollowing(currentUserId,targetUserId);
  boolean followsMe=repo.isFollowing(targetUserId,currentUserId);
  return new SocialRelationshipDtos.RelationshipState(targetUserId,followingByMe,followsMe,followingByMe && followsMe);
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
