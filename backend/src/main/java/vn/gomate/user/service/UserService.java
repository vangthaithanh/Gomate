package vn.gomate.user.service;

import java.text.Normalizer;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.user.dto.UserDtos;
import vn.gomate.user.repository.UserRepository;

@Service
public class UserService {
 public boolean canInitiateMessage(UUID viewer,UUID target) {
  return repo.canInitiateMessage(viewer,target);
 }
 private static final int DEFAULT_SIZE=20;
 private static final int MAX_SIZE=50;

 private final UserRepository repo;

 public UserService(UserRepository repo) {
  this.repo=repo;
 }

 public UserDtos.UserProfile me(UUID currentUserId) {
  return repo.profile(currentUserId,currentUserId,true);
 }

 public UserDtos.UserProfile publicProfile(UUID currentUserId,UUID targetUserId) {
  if(currentUserId.equals(targetUserId)) return repo.profile(currentUserId,targetUserId,true);
  return repo.profile(currentUserId,targetUserId,false);
 }

 @Transactional
 public UserDtos.UserProfile updateProfile(UUID currentUserId,UserDtos.ProfileUpdate req) {
  String nickname=null;
  String nicknameKey=null;
  if(req.nickname()!=null) {
   nickname=Normalizer.normalize(req.nickname().trim(),Normalizer.Form.NFC);
   if(nickname.length()<3) throw ApiException.bad("Biệt danh cần ít nhất 3 ký tự.");
   nicknameKey=repo.nicknameKey(nickname);
   if(repo.nicknameTakenByOther(nicknameKey,currentUserId)) {
    throw new ApiException(409,"NICKNAME_TAKEN","Biệt danh đã có người sử dụng.");
   }
  }
  repo.updateProfile(currentUserId,nickname,nicknameKey,req.fullName(),req.city(),req.bio(),req.avatarUrl());
  if(req.isPrivate()!=null) repo.updatePrivacy(currentUserId,req.isPrivate());
  return me(currentUserId);
 }

 public UserDtos.Page<UserDtos.UserSearchItem> search(UUID currentUserId,String query,int page,int size) {
  String q=query==null?"":query.trim();
  int safePage=Math.max(0,page);
  int safeSize=safeSize(size);
  if(q.length()<2) {
   return new UserDtos.Page<>(
    repo.suggestContacts(currentUserId,safeSize,safePage*safeSize),
    safePage,
    safeSize,
    repo.suggestContactsCount(currentUserId)
   );
  }
  return new UserDtos.Page<>(
   repo.search(currentUserId,q,safeSize,safePage*safeSize),
   safePage,
   safeSize,
   repo.searchCount(currentUserId,q)
  );
 }

 private int safeSize(int size) {
  return size<=0?DEFAULT_SIZE:Math.min(size,MAX_SIZE);
 }
}
