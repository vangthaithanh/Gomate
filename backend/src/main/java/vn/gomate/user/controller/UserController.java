package vn.gomate.user.controller;

import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.user.dto.UserDtos;
import vn.gomate.user.service.UserService;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {
 private final UserService service;

 public UserController(UserService service) {
  this.service=service;
 }

 @GetMapping("/me/profile")
 public UserDtos.UserProfile me() {
  return service.me(CurrentUser.id());
 }

 @PatchMapping({"/me","/me/profile"})
 public UserDtos.UserProfile updateMe(@Valid @RequestBody UserDtos.ProfileUpdate req) {
  return service.updateProfile(CurrentUser.id(),req);
 }

 @GetMapping("/{userId}")
 public UserDtos.UserProfile publicProfile(@PathVariable UUID userId) {
  return service.publicProfile(CurrentUser.id(),userId);
 }

 @GetMapping("/search")
 public UserDtos.Page<UserDtos.UserSearchItem> search(
  @RequestParam(defaultValue="") String q,
  @RequestParam(defaultValue="0") int page,
  @RequestParam(defaultValue="20") int size
 ) {
  return service.search(CurrentUser.id(),q,page,size);
 }
}
