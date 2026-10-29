package vn.gomate.location.controller;

import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.gomate.common.ApiException;
import vn.gomate.location.realtime.TripLocationStreamHub;

@RestController
public class TripLocationStreamController {
 private final TripLocationStreamHub streams;
 public TripLocationStreamController(TripLocationStreamHub streams) { this.streams=streams; }
 @GetMapping(value="/api/v1/trips/{id}/locations/stream",produces=MediaType.TEXT_EVENT_STREAM_VALUE)
 public ResponseEntity<SseEmitter> stream(@PathVariable UUID id,@AuthenticationPrincipal Jwt jwt,HttpServletRequest request) {
  if(request.getQueryString()!=null) throw ApiException.bad("Không nhận thông tin đăng nhập hoặc userId qua query.");
  return ResponseEntity.ok().cacheControl(CacheControl.noStore()).header("X-Accel-Buffering","no").body(streams.connect(id,jwt));
 }
}
