package vn.gomate.trip.controller;

import jakarta.validation.Valid;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.location.service.TripLocationService;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.service.TripService;

@RestController
@RequestMapping("/api/v1/trips")
public class TripController {
 private final TripService service;
 private final TripLocationService locations;
 public TripController(TripService service,TripLocationService locations) {
  this.service=service;
  this.locations=locations;
 }

 @PostMapping
 @ResponseStatus(HttpStatus.CREATED)
 public TripDtos.TripDetail create(@Valid @RequestBody TripDtos.CreateTripRequest req) {
  return service.create(CurrentUser.id(),req);
 }

 @GetMapping
 public List<TripDtos.TripSummary> list() {
  return service.list(CurrentUser.id());
 }

 @GetMapping("/pinned")
 public TripDtos.PinnedTripResponse pinned() {
  return new TripDtos.PinnedTripResponse(service.pinned(CurrentUser.id()).orElse(null));
 }

 @GetMapping("/{id}")
 public TripDtos.TripDetail detail(@PathVariable UUID id) {
  return service.detail(CurrentUser.id(),id);
 }

 @PostMapping("/{id}/pin")
 public TripDtos.TripDetail pin(@PathVariable UUID id) {
  return service.pin(CurrentUser.id(),id);
 }

 @DeleteMapping("/{id}/pin")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void unpin(@PathVariable UUID id) {
  service.unpin(CurrentUser.id(),id);
 }

 @PatchMapping("/{id}")
 public TripDtos.TripDetail update(@PathVariable UUID id,@Valid @RequestBody TripDtos.UpdateTripRequest req) {
  return service.update(CurrentUser.id(),id,req);
 }

 @PostMapping("/{id}/members")
 public TripDtos.TripDetail addMembers(@PathVariable UUID id,@Valid @RequestBody TripDtos.AddMembersRequest req) {
  return service.addMembers(CurrentUser.id(),id,req);
 }

 @DeleteMapping("/{id}")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void delete(@PathVariable UUID id) {
  service.delete(CurrentUser.id(),id);
 }

 @PostMapping("/{id}/stops")
 @ResponseStatus(HttpStatus.CREATED)
 public TripDtos.TripDetail addStop(@PathVariable UUID id,@Valid @RequestBody TripDtos.AddStopRequest req) {
  return service.addStop(CurrentUser.id(),id,req);
 }

 @DeleteMapping("/{id}/stops/{stopId}")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void deleteStop(@PathVariable UUID id,@PathVariable UUID stopId) {
  service.deleteStop(CurrentUser.id(),id,stopId);
 }

 @PatchMapping("/{id}/stops/{stopId}")
 public TripDtos.TripDetail updateStop(@PathVariable UUID id,@PathVariable UUID stopId,@Valid @RequestBody TripDtos.UpdateStopRequest req) {
  return service.updateStop(CurrentUser.id(),id,stopId,req);
 }

 @PatchMapping("/{id}/stops/reorder")
 public TripDtos.TripDetail reorder(@PathVariable UUID id,@Valid @RequestBody TripDtos.ReorderStopsRequest req) {
  return service.reorderStops(CurrentUser.id(),id,req);
 }

 @PostMapping("/{id}/stops/optimize")
 public TripDtos.TripDetail optimize(@PathVariable UUID id,@RequestBody(required=false) TripDtos.OptimizeStopsRequest req) {
  return service.optimizeStops(CurrentUser.id(),id,req);
 }

 @PutMapping("/{id}/location")
 public TripDtos.TripLocationItem publishLocation(@PathVariable UUID id,@Valid @RequestBody TripDtos.PublishLocationRequest req) {
  return locations.publish(CurrentUser.id(),id,req);
 }

 @GetMapping("/{id}/locations")
 public List<TripDtos.TripLocationItem> locations(@PathVariable UUID id) {
  return locations.list(CurrentUser.id(),id);
 }
}
