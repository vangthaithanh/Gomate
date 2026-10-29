package vn.gomate.notification.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.notification.service.NotificationDeviceService;

@RestController
@RequestMapping("/api/v1/notification-devices")
public class NotificationDeviceController {
 public record Register(@NotNull UUID installationId,@NotBlank @Size(max=4096) String token,
  @NotBlank @Pattern(regexp="ANDROID|IOS") String platform) {}
 public record Unregister(@NotNull UUID installationId) {}
 private final NotificationDeviceService service;
 public NotificationDeviceController(NotificationDeviceService service) { this.service=service; }

 @PostMapping @ResponseStatus(HttpStatus.NO_CONTENT)
 public void register(@Valid @RequestBody Register request) {
  service.register(CurrentUser.id(),CurrentUser.sessionId(),request.installationId(),request.token(),request.platform());
 }
 @DeleteMapping("/current") @ResponseStatus(HttpStatus.NO_CONTENT)
 public void unregister(@Valid @RequestBody Unregister request) {
  service.unregister(CurrentUser.id(),CurrentUser.sessionId(),request.installationId());
 }
}
