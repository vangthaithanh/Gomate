package vn.gomate.moment.controller;

import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.auth.CurrentUser;
import vn.gomate.message.dto.MessageDtos;
import vn.gomate.moment.dto.MomentDtos;
import vn.gomate.moment.service.MomentService;

@RestController
@RequestMapping("/api/v1")
public class MomentController {
 private final MomentService service;

 public MomentController(MomentService service) {
  this.service=service;
 }

 @PostMapping("/moments/media")
 @ResponseStatus(HttpStatus.CREATED)
 public MomentDtos.UploadedMedia upload(@RequestPart("file") MultipartFile file) {
  return service.uploadImage(CurrentUser.id(),file);
 }

 @PostMapping("/moments")
 @ResponseStatus(HttpStatus.CREATED)
 public MomentDtos.MomentItem create(@Valid @RequestBody MomentDtos.CreateMomentRequest req) {
  return service.create(CurrentUser.id(),req);
 }

 @GetMapping("/moments/home")
 public MomentDtos.HomeResponse home() {
  return service.home(CurrentUser.id());
 }

 @GetMapping("/moments/me")
 public List<MomentDtos.MomentItem> mine() {
  return service.home(CurrentUser.id()).myMoments();
 }

 @GetMapping("/moments/users/{userId}/available")
 public List<MomentDtos.MomentItem> available(@PathVariable UUID userId) {
  return service.availableForUser(CurrentUser.id(),userId);
 }

 @GetMapping("/moments/{momentId}")
 public MomentDtos.MomentItem get(@PathVariable String momentId) {
  return service.get(CurrentUser.id(),momentId);
 }

 @PostMapping("/moments/{momentId}/view")
 public MomentDtos.MomentItem view(@PathVariable String momentId) {
  return service.markViewed(CurrentUser.id(),momentId);
 }

 @PostMapping("/moments/{momentId}/reactions")
 @ResponseStatus(HttpStatus.CREATED)
 public MomentDtos.ReactionItem react(
  @PathVariable String momentId,
  @Valid @RequestBody MomentDtos.ReactRequest req
 ) {
  return service.react(CurrentUser.id(),momentId,req.type());
 }

 @PostMapping("/moments/{momentId}/message")
 @ResponseStatus(HttpStatus.CREATED)
 public MessageDtos.MessageItem message(
  @PathVariable String momentId,
  @Valid @RequestBody MomentDtos.SendMomentMessageRequest req
 ) {
  return service.sendMessageToOwner(CurrentUser.id(),momentId,req.text());
 }

 @DeleteMapping("/moments/{momentId}")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void delete(@PathVariable String momentId) {
  service.delete(CurrentUser.id(),momentId);
 }

 @DeleteMapping("/moments")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void deleteBatch(@RequestBody(required=false) MomentDtos.BatchDeleteRequest req) {
  service.deleteBatch(CurrentUser.id(),req==null?List.of():req.momentIds());
 }

 @PostMapping("/moment-mutes/{userId}")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void mute(@PathVariable UUID userId) {
  service.mute(CurrentUser.id(),userId);
 }

 @DeleteMapping("/moment-mutes/{userId}")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void unmute(@PathVariable UUID userId) {
  service.unmute(CurrentUser.id(),userId);
 }
}
