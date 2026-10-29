package vn.gomate.notification.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.gomate.common.ApiException;
import vn.gomate.notification.realtime.NotificationStreamHub;

@RestController
public class NotificationStreamController {
 private final NotificationStreamHub streams;
 public NotificationStreamController(NotificationStreamHub streams) { this.streams=streams; }

 @GetMapping(value="/api/v1/notifications/stream",produces=MediaType.TEXT_EVENT_STREAM_VALUE)
 public ResponseEntity<SseEmitter> stream(@AuthenticationPrincipal Jwt jwt,HttpServletRequest request) {
  if(request.getQueryString()!=null || !request.getParameterMap().isEmpty()) throw ApiException.bad("Notification stream does not accept subscription parameters.");
  return ResponseEntity.ok().cacheControl(CacheControl.noStore()).header("X-Accel-Buffering","no").body(streams.connect(jwt));
 }
}
