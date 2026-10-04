package vn.gomate.semantic.controller;

import java.util.List;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.semantic.dto.SemanticDtos;
import vn.gomate.semantic.service.SemanticService;

@RestController
@RequestMapping("/api/v1")
public class SemanticController {
 private final SemanticService service;
 public SemanticController(SemanticService service) { this.service=service; }

 @GetMapping("/semantic/interests")
 public List<SemanticDtos.InterestOption> interests() {
  return service.interests();
 }

 @GetMapping("/semantic/place-tags")
 public List<SemanticDtos.PlaceTag> tags() {
  return service.tags();
 }

 @GetMapping("/semantic/interest-tag-mappings")
 public List<SemanticDtos.InterestTagMapping> interestTagMappings() {
  return service.interestTagMappings();
 }

 @GetMapping("/semantic/places/{placeId}/tags")
 public List<SemanticDtos.PlaceTagLink> placeTags(@PathVariable long placeId) {
  return service.placeTags(placeId);
 }

 @GetMapping("/users/me/interests")
 public List<SemanticDtos.UserInterest> myInterests() {
  return service.userInterests(CurrentUser.id());
 }
}
