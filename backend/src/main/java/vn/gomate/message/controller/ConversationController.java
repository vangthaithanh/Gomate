package vn.gomate.message.controller;

import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.message.dto.MessageDtos;
import vn.gomate.message.service.ConversationService;

@RestController
@RequestMapping("/api/v1")
public class ConversationController {
 private final ConversationService service;

 public ConversationController(ConversationService service) {
  this.service=service;
 }

 @GetMapping("/conversations")
 public List<MessageDtos.ConversationSummary> conversations(
  @RequestParam(defaultValue="0") int page,
  @RequestParam(defaultValue="20") int size
 ) {
  return service.listAccepted(CurrentUser.id(),page,size);
 }

 @PostMapping("/conversations/direct")
 @ResponseStatus(HttpStatus.CREATED)
 public MessageDtos.ConversationSummary openDirect(@RequestBody MessageDtos.DirectOpenRequest req) {
  return service.openDirect(CurrentUser.id(),req.targetUserId());
 }

 @GetMapping("/conversations/{conversationId}")
 public MessageDtos.ConversationDetail conversation(
  @PathVariable UUID conversationId,
  @RequestParam(defaultValue="30") Integer limit,
  @RequestParam(required=false) String before
 ) {
  return service.detail(conversationId,CurrentUser.id(),limit,before);
 }

 @GetMapping("/conversations/{conversationId}/messages")
 public List<MessageDtos.MessageItem> messages(
  @PathVariable UUID conversationId,
  @RequestParam(defaultValue="30") Integer limit,
  @RequestParam(required=false) String before
 ) {
  return service.listMessages(conversationId,CurrentUser.id(),limit,before);
 }

 @PostMapping("/conversations/{conversationId}/messages")
 @ResponseStatus(HttpStatus.CREATED)
 public MessageDtos.MessageItem send(
  @PathVariable UUID conversationId,
  @Valid @RequestBody MessageDtos.SendTextRequest req
 ) {
  return service.sendText(conversationId,CurrentUser.id(),req);
 }

 @PostMapping("/conversations/{conversationId}/read")
 public MessageDtos.ConversationSummary read(@PathVariable UUID conversationId) {
  return service.markRead(conversationId,CurrentUser.id());
 }

 @PatchMapping("/conversations/{conversationId}/name")
 public MessageDtos.ConversationSummary rename(
  @PathVariable UUID conversationId,
  @Valid @RequestBody MessageDtos.RenameConversationRequest req
 ) {
  return service.renameGroup(conversationId,CurrentUser.id(),req);
 }

 @PostMapping("/conversations/{conversationId}/mute")
 public MessageDtos.ConversationSummary mute(@PathVariable UUID conversationId) {
  return service.setMuted(conversationId,CurrentUser.id(),true);
 }

 @DeleteMapping("/conversations/{conversationId}/mute")
 public MessageDtos.ConversationSummary unmute(@PathVariable UUID conversationId) {
  return service.setMuted(conversationId,CurrentUser.id(),false);
 }

 @PostMapping("/conversations/{conversationId}/block")
 public MessageDtos.ConversationSummary block(@PathVariable UUID conversationId) {
  return service.setBlocked(conversationId,CurrentUser.id(),true);
 }

 @DeleteMapping("/conversations/{conversationId}/block")
 public MessageDtos.ConversationSummary unblock(@PathVariable UUID conversationId) {
  return service.setBlocked(conversationId,CurrentUser.id(),false);
 }

 @GetMapping("/message-requests")
 public List<MessageDtos.ConversationSummary> pending(
  @RequestParam(defaultValue="0") int page,
  @RequestParam(defaultValue="20") int size
 ) {
  return service.listPending(CurrentUser.id(),page,size);
 }

 @PostMapping("/message-requests/{conversationId}/accept")
 public MessageDtos.ConversationSummary accept(@PathVariable UUID conversationId) {
  return service.accept(conversationId,CurrentUser.id());
 }

 @DeleteMapping("/message-requests/{conversationId}")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void deletePending(@PathVariable UUID conversationId) {
  service.deletePending(conversationId,CurrentUser.id());
 }
}
