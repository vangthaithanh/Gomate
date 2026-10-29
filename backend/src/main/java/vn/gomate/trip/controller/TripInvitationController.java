package vn.gomate.trip.controller;

import java.util.*;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.service.TripService;

@RestController
@RequestMapping("/api/v1/trip-invitations")
public class TripInvitationController {
 private final TripService service;

 public TripInvitationController(TripService service) {
  this.service=service;
 }

 @GetMapping("/incoming")
 public List<TripDtos.TripInvitationItem> incoming(@RequestParam(required=false) String status) {
  return service.incomingInvitations(CurrentUser.id(),status);
 }

 @PostMapping("/{id}/accept")
 public TripDtos.TripDetail accept(@PathVariable UUID id) {
  return service.acceptInvitation(CurrentUser.id(),id);
 }

 @PostMapping("/{id}/decline")
 public TripDtos.TripInvitationItem decline(@PathVariable UUID id) {
  return service.declineInvitation(CurrentUser.id(),id);
 }
}
