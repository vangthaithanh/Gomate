package vn.gomate.moment.service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.common.ApiException;
import vn.gomate.media.model.MediaResourceType;
import vn.gomate.media.service.MediaService;
import vn.gomate.message.dto.MessageDtos;
import vn.gomate.message.service.ConversationService;
import vn.gomate.moment.dto.MomentDtos;
import vn.gomate.moment.model.MomentDocument;
import vn.gomate.moment.model.MomentReactionDocument;
import vn.gomate.moment.repository.MomentMongoRepository;
import vn.gomate.relationship.dto.SocialRelationshipDtos;
import vn.gomate.relationship.service.SocialRelationshipService;
import vn.gomate.user.dto.UserDtos;
import vn.gomate.user.repository.UserRepository;

@Service
public class MomentService {
 private static final Duration MOMENT_TTL=Duration.ofHours(24);
 private static final String VISIBILITY_MUTUAL_FRIENDS="MUTUAL_FRIENDS";
 private static final String MEDIA_FOLDER="gomate/dev/moments";
 private static final Set<String> REACTION_TYPES=Set.of("HEART","HAHA","WOW","FIRE","CLAP","LOVE","SAD","ANGRY");

 private final MomentMongoRepository repo;
 private final SocialRelationshipService relationships;
 private final UserRepository users;
 private final ConversationService conversations;
 private final ObjectProvider<MediaService> mediaService;

 public MomentService(
  MomentMongoRepository repo,
  SocialRelationshipService relationships,
  UserRepository users,
  ConversationService conversations,
  ObjectProvider<MediaService> mediaService
 ) {
  this.repo=repo;
  this.relationships=relationships;
  this.users=users;
  this.conversations=conversations;
  this.mediaService=mediaService;
 }

 public MomentDtos.UploadedMedia uploadImage(UUID currentUserId,MultipartFile file) {
  if(file==null || file.isEmpty()) throw ApiException.bad("Thiếu ảnh khoảnh khắc.");
  String type=file.getContentType()==null?"":file.getContentType().toLowerCase(java.util.Locale.ROOT);
  if(!type.startsWith("image/")) throw new ApiException(415,"UNSUPPORTED_MEDIA_TYPE","Moment V1 chỉ hỗ trợ ảnh.");
  MediaService media=mediaService.getIfAvailable();
  if(media==null) throw new ApiException(503,"MEDIA_PROVIDER_UNAVAILABLE","Chưa cấu hình Cloudinary để tải ảnh.");
  var uploaded=media.uploadImage(file,MEDIA_FOLDER+"/"+currentUserId);
  return new MomentDtos.UploadedMedia(
   uploaded.secureUrl(),
   uploaded.publicId(),
   uploaded.resourceType().name(),
   uploaded.width(),
   uploaded.height(),
   uploaded.bytes()
  );
 }

 public MomentDtos.MomentItem create(UUID currentUserId,MomentDtos.CreateMomentRequest req) {
  var now=Instant.now();
  var doc=new MomentDocument();
  doc.setMomentId(UUID.randomUUID().toString());
  doc.setOwnerUserId(currentUserId);
  doc.setMediaUrl(trim(req.mediaUrl()));
  doc.setMediaPublicId(trim(req.publicId()));
  doc.setMediaType("IMAGE");
  doc.setCaption(emptyToNull(req.caption()));
  doc.setLocationText(emptyToNull(req.locationText()));
  doc.setPlaceId(req.placeId());
  doc.setLatitude(req.latitude());
  doc.setLongitude(req.longitude());
  doc.setVisibility(VISIBILITY_MUTUAL_FRIENDS);
  doc.setCreatedAt(now);
  doc.setExpiresAt(now.plus(MOMENT_TTL));
  return item(repo.save(doc),currentUserId,profileMap(currentUserId,List.of(currentUserId)),Set.of());
 }

 public MomentDtos.HomeResponse home(UUID currentUserId) {
  var now=Instant.now();
  var self=users.profile(currentUserId,currentUserId,true);
  var friends=mutualFriends(currentUserId);
  var friendIds=friends.stream().map(SocialRelationshipDtos.UserSummary::userId).toList();
  var muted=repo.mutedOwnerIds(currentUserId);
  var activeFriendMoments=repo.activeByOwners(friendIds,now,500);
  var allMomentIds=activeFriendMoments.stream().map(MomentDocument::getMomentId).toList();
  var viewed=repo.viewedMomentIds(currentUserId,allMomentIds);
  var available=activeFriendMoments.stream()
   .filter(moment -> !muted.contains(moment.getOwnerUserId()))
   .filter(moment -> !viewed.contains(moment.getMomentId()))
   .toList();
  var owners=new ArrayList<UUID>();
  owners.add(currentUserId);
  owners.addAll(friendIds);
  var profiles=profileMap(currentUserId,owners);
  var availableByOwner=available.stream().collect(Collectors.groupingBy(MomentDocument::getOwnerUserId));
  var previews=new ArrayList<MomentDtos.FriendPreview>();
  var ownActive=repo.activeOwn(currentUserId,now);
  previews.add(new MomentDtos.FriendPreview(
   currentUserId,
   displayName(self),
   self.nickname(),
   self.avatarUrl(),
   true,
   true,
   false,
   !ownActive.isEmpty(),
   ownActive.size(),
   ownActive.stream().map(MomentDocument::getCreatedAt).max(Comparator.naturalOrder()).orElse(null)
  ));
  for(var friend:friends) {
   var friendMoments=availableByOwner.getOrDefault(friend.userId(),List.of());
   if(friendMoments.isEmpty()) continue;
   previews.add(new MomentDtos.FriendPreview(
    friend.userId(),
    displayName(friend),
    friend.nickname(),
    friend.avatarUrl(),
    false,
    true,
    muted.contains(friend.userId()),
    !friendMoments.isEmpty(),
    friendMoments.size(),
    friendMoments.stream().map(MomentDocument::getCreatedAt).max(Comparator.naturalOrder()).orElse(null)
   ));
  }
  previews.sort((a,b) -> {
   if(a.self()) return -1;
   if(b.self()) return 1;
   if(a.hasAvailableMoment()!=b.hasAvailableMoment()) return a.hasAvailableMoment()?-1:1;
   if(a.latestMomentAt()!=null && b.latestMomentAt()!=null) return b.latestMomentAt().compareTo(a.latestMomentAt());
   return a.name().compareToIgnoreCase(b.name());
  });
  return new MomentDtos.HomeResponse(
   previews,
   available.stream().map(moment -> item(moment,currentUserId,profiles,viewed)).toList(),
   repo.ownerHistory(currentUserId,200).stream().map(moment -> item(moment,currentUserId,profiles,Set.of())).toList()
  );
 }

 public List<MomentDtos.MomentItem> availableForUser(UUID currentUserId,UUID ownerUserId) {
  if(currentUserId.equals(ownerUserId)) return repo.ownerHistory(currentUserId,200).stream()
   .map(moment -> item(moment,currentUserId,profileMap(currentUserId,List.of(currentUserId)),Set.of()))
   .toList();
  ensureMutual(currentUserId,ownerUserId);
  if(repo.muted(currentUserId,ownerUserId)) return List.of();
  var now=Instant.now();
  var moments=repo.activeByOwners(List.of(ownerUserId),now,100);
  var viewed=repo.viewedMomentIds(currentUserId,moments.stream().map(MomentDocument::getMomentId).toList());
  var profiles=profileMap(currentUserId,List.of(ownerUserId));
  return moments.stream()
   .filter(moment -> !viewed.contains(moment.getMomentId()))
   .map(moment -> item(moment,currentUserId,profiles,viewed))
   .toList();
 }

 public MomentDtos.MomentItem get(UUID currentUserId,String momentId) {
  var owned=repo.findOwnedHistory(momentId,currentUserId);
  if(owned.isPresent()) return item(owned.get(),currentUserId,profileMap(currentUserId,List.of(currentUserId)),Set.of());
  var moment=repo.findActive(momentId,Instant.now()).orElseThrow(ApiException::notFound);
  ensureVisible(currentUserId,moment);
  var viewed=repo.viewed(currentUserId,momentId)?Set.of(momentId):Set.<String>of();
  return item(moment,currentUserId,profileMap(currentUserId,List.of(moment.getOwnerUserId())),viewed);
 }

 public MomentDtos.MomentItem markViewed(UUID currentUserId,String momentId) {
  var moment=repo.findActive(momentId,Instant.now()).orElseThrow(ApiException::notFound);
  if(moment.getOwnerUserId().equals(currentUserId)) return get(currentUserId,momentId);
  ensureVisible(currentUserId,moment);
  repo.markViewed(momentId,moment.getOwnerUserId(),currentUserId,Instant.now());
  return item(moment,currentUserId,profileMap(currentUserId,List.of(moment.getOwnerUserId())),Set.of(momentId));
 }

 public MomentDtos.ReactionItem react(UUID currentUserId,String momentId,String rawType) {
  var type=normalizeReaction(rawType);
  var moment=repo.findActive(momentId,Instant.now()).orElseThrow(ApiException::notFound);
  if(moment.getOwnerUserId().equals(currentUserId)) throw ApiException.bad("Không thể tự thả cảm xúc khoảnh khắc của mình.");
  ensureVisible(currentUserId,moment);
  var existing=repo.reaction(momentId,currentUserId);
  if(existing.isPresent()) {
   if(type.equals(existing.get().getType())) return reactionItem(existing.get(),profileMap(currentUserId,List.of(currentUserId)));
   throw new ApiException(409,"MOMENT_REACTION_EXISTS","Bạn đã thả cảm xúc cho khoảnh khắc này.");
  }
  var doc=new MomentReactionDocument();
  doc.setReactionId(UUID.randomUUID().toString());
  doc.setMomentId(momentId);
  doc.setOwnerUserId(moment.getOwnerUserId());
  doc.setReactorUserId(currentUserId);
  doc.setType(type);
  doc.setReactedAt(Instant.now());
  return reactionItem(repo.saveReaction(doc),profileMap(currentUserId,List.of(currentUserId)));
 }

 public void mute(UUID currentUserId,UUID targetUserId) {
  if(currentUserId.equals(targetUserId)) throw ApiException.bad("Không thể tắt khoảnh khắc của chính mình.");
  ensureMutual(currentUserId,targetUserId);
  repo.mute(currentUserId,targetUserId,Instant.now());
 }

 public void unmute(UUID currentUserId,UUID targetUserId) {
  if(currentUserId.equals(targetUserId)) throw ApiException.bad("Không thể bật/tắt khoảnh khắc của chính mình.");
  repo.unmute(currentUserId,targetUserId);
 }

 public void delete(UUID currentUserId,String momentId) {
  var doc=repo.findOwnedHistory(momentId,currentUserId).orElseThrow(ApiException::notFound);
  if(repo.hardDeleteOwned(momentId,currentUserId,Instant.now())) deleteCloudinaryQuietly(doc);
 }

 public void deleteBatch(UUID currentUserId,List<String> momentIds) {
  if(momentIds==null || momentIds.isEmpty()) return;
  momentIds.stream().filter(Objects::nonNull).distinct().limit(100).forEach(id -> delete(currentUserId,id));
 }

 public MessageDtos.MessageItem sendMessageToOwner(UUID currentUserId,String momentId,String text) {
  var moment=repo.findActive(momentId,Instant.now()).orElseThrow(ApiException::notFound);
  if(moment.getOwnerUserId().equals(currentUserId)) throw ApiException.bad("Không thể gửi tin nhắn cho chính mình.");
  ensureVisible(currentUserId,moment);
  return conversations.sendDirect(currentUserId,
   new MessageDtos.DirectSendRequest(moment.getOwnerUserId(),UUID.randomUUID(),text,Map.of(
    "type","MOMENT",
    "momentId",momentId,
    "mediaUrl",moment.getMediaUrl(),
    "ownerUserId",moment.getOwnerUserId().toString()
   ))
  ).message();
 }

 private void ensureVisible(UUID currentUserId,MomentDocument moment) {
  ensureMutual(currentUserId,moment.getOwnerUserId());
  if(repo.muted(currentUserId,moment.getOwnerUserId())) throw ApiException.notFound();
 }

 private void ensureMutual(UUID currentUserId,UUID targetUserId) {
  if(!users.activeUserRow(targetUserId).isPresent()) throw ApiException.notFound();
  if(!relationships.isMutualFriend(currentUserId,targetUserId)) throw ApiException.notFound();
 }

 private List<SocialRelationshipDtos.UserSummary> mutualFriends(UUID currentUserId) {
  var result=new ArrayList<SocialRelationshipDtos.UserSummary>();
  for(int page=0;page<4;page++) {
   var data=relationships.listMutualFriends(currentUserId,page,50);
   result.addAll(data.items());
   if(result.size()>=data.total() || data.items().isEmpty()) break;
  }
  return result;
 }

 private MomentDtos.MomentItem item(MomentDocument doc,UUID currentUserId,Map<UUID,UserView> profiles,Set<String> viewed) {
  var reactions=repo.reactions(doc.getMomentId());
  var mergedProfiles=new LinkedHashMap<>(profiles);
  var missingReactionUsers=reactions.stream()
   .map(MomentReactionDocument::getReactorUserId)
   .filter(userId -> !mergedProfiles.containsKey(userId))
   .distinct()
   .toList();
  mergedProfiles.putAll(profileMap(currentUserId,missingReactionUsers));
  var owner=mergedProfiles.get(doc.getOwnerUserId());
  if(owner==null) owner=new UserView(doc.getOwnerUserId(),"Người dùng","",null);
  return new MomentDtos.MomentItem(
   doc.getMomentId(),
   doc.getOwnerUserId(),
   owner.displayName(),
   owner.nickname(),
   owner.avatarUrl(),
   doc.getMediaUrl(),
   doc.getMediaPublicId(),
   doc.getMediaType(),
   doc.getCaption(),
   doc.getLocationText(),
   doc.getPlaceId(),
   doc.getLatitude(),
   doc.getLongitude(),
   doc.getCreatedAt(),
   doc.getExpiresAt(),
   doc.getOwnerUserId().equals(currentUserId),
   doc.getOwnerUserId().equals(currentUserId) || viewed.contains(doc.getMomentId()),
   reactions.stream().map(reaction -> reactionItem(reaction,mergedProfiles)).toList()
  );
 }

 private MomentDtos.ReactionItem reactionItem(MomentReactionDocument doc,Map<UUID,UserView> profiles) {
  var user=profiles.get(doc.getReactorUserId());
  if(user==null) user=new UserView(doc.getReactorUserId(),"Người dùng","",null);
  return new MomentDtos.ReactionItem(
   doc.getReactionId(),
   doc.getReactorUserId(),
   user.displayName(),
   user.nickname(),
   user.avatarUrl(),
   doc.getType(),
   doc.getReactedAt()
  );
 }

 private Map<UUID,UserView> profileMap(UUID viewerId,List<UUID> userIds) {
  var result=new LinkedHashMap<UUID,UserView>();
  for(UUID userId:userIds.stream().distinct().toList()) {
   try {
    var profile=users.profile(viewerId,userId,userId.equals(viewerId));
    result.put(userId,new UserView(userId,displayName(profile),profile.nickname(),profile.avatarUrl()));
   } catch(ApiException ignored) {
    // Deleted/locked users are hidden from new API surfaces; historical docs can still map to fallback.
   }
  }
  return result;
 }

 private String displayName(UserDtos.UserProfile profile) {
  return profile.displayName()==null || profile.displayName().isBlank()?profile.nickname():profile.displayName();
 }

 private String displayName(SocialRelationshipDtos.UserSummary item) {
  return item.fullName()==null || item.fullName().isBlank()?item.nickname():item.fullName();
 }

 private String normalizeReaction(String value) {
  if(value==null) throw ApiException.bad("Thiếu loại cảm xúc.");
  var type=value.trim().toUpperCase(java.util.Locale.ROOT);
  if(!REACTION_TYPES.contains(type)) throw ApiException.bad("Loại cảm xúc không được hỗ trợ.");
  return type;
 }

 private String trim(String value) {
  if(value==null || value.trim().isEmpty()) throw ApiException.bad("Thiếu media khoảnh khắc.");
  return value.trim();
 }

 private String emptyToNull(String value) {
  if(value==null) return null;
  var trimmed=value.trim();
  return trimmed.isEmpty()?null:trimmed;
 }

 private void deleteCloudinaryQuietly(MomentDocument doc) {
  if(doc.getMediaPublicId()==null || doc.getMediaPublicId().isBlank()) return;
  MediaService media=mediaService.getIfAvailable();
  if(media==null) return;
  try {
   media.delete(doc.getMediaPublicId(),MediaResourceType.IMAGE);
  } catch(ApiException e) {
   LoggerFactory.getLogger(MomentService.class).warn("Could not delete Cloudinary moment asset {}",doc.getMediaPublicId(),e);
  }
 }

 private record UserView(UUID userId,String displayName,String nickname,String avatarUrl) {}
}
