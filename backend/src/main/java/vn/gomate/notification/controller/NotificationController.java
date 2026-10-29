package vn.gomate.notification.controller;

import java.util.UUID;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.notification.dto.NotificationDtos;
import vn.gomate.notification.service.NotificationService;
import vn.gomate.notification.service.NotificationPostTargetService;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {
 private final NotificationService service;
 private final NotificationPostTargetService postTargets;
 public NotificationController(NotificationService service,NotificationPostTargetService postTargets) { this.service=service; this.postTargets=postTargets; }

 @GetMapping("/{id}/post-target")
 public NotificationDtos.PostTarget postTarget(@PathVariable UUID id,jakarta.servlet.http.HttpServletResponse response) {
  response.setHeader("Cache-Control","private, no-store, max-age=0");
  return postTargets.resolve(CurrentUser.id(),id);
 }

 @GetMapping
 public NotificationDtos.Page list(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="30") int size) {
  return service.list(CurrentUser.id(),page,size);
 }

 @GetMapping("/{id}")
 public NotificationDtos.Item detail(@PathVariable UUID id) { return service.detail(CurrentUser.id(),id); }

 @PatchMapping("/{id}/read")
 public NotificationDtos.Item read(@PathVariable UUID id) { return service.markRead(CurrentUser.id(),id); }

 @PostMapping("/read-all")
 public void readAll() { service.markAllRead(CurrentUser.id()); }
}
