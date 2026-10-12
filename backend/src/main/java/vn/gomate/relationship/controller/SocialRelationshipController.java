package vn.gomate.relationship.controller;

import java.util.UUID;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.relationship.dto.SocialRelationshipDtos;
import vn.gomate.relationship.service.SocialRelationshipService;

@RestController
@RequestMapping("/api/v1/users")
public class SocialRelationshipController {
 private final SocialRelationshipService service;

 public SocialRelationshipController(SocialRelationshipService service) {
  this.service=service;
 }

 @PutMapping("/{userId}/follow")
 public SocialRelationshipDtos.RelationshipState follow(@PathVariable UUID userId) {
  return service.follow(CurrentUser.id(),userId);
 }

 @DeleteMapping("/{userId}/follow")
 public SocialRelationshipDtos.RelationshipState unfollow(@PathVariable UUID userId) {
  return service.unfollow(CurrentUser.id(),userId);
 }

 @GetMapping("/{userId}/relationship")
 public SocialRelationshipDtos.RelationshipState relationship(@PathVariable UUID userId) {
  return service.getRelationship(CurrentUser.id(),userId);
 }

 @GetMapping("/me/following")
 public SocialRelationshipDtos.Page<SocialRelationshipDtos.UserSummary> following(
  @RequestParam(defaultValue="0") int page,
  @RequestParam(defaultValue="20") int size
 ) {
  return service.listFollowing(CurrentUser.id(),page,size);
 }

 @GetMapping("/me/followers")
 public SocialRelationshipDtos.Page<SocialRelationshipDtos.UserSummary> followers(
  @RequestParam(defaultValue="0") int page,
  @RequestParam(defaultValue="20") int size
 ) {
  return service.listFollowers(CurrentUser.id(),page,size);
 }

 @GetMapping("/me/mutual-friends")
 public SocialRelationshipDtos.Page<SocialRelationshipDtos.UserSummary> mutualFriends(
  @RequestParam(defaultValue="0") int page,
  @RequestParam(defaultValue="20") int size
 ) {
  return service.listMutualFriends(CurrentUser.id(),page,size);
 }
}
