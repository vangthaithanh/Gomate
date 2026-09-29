package vn.gomate.trip.controller;

import jakarta.validation.Valid;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.service.TripService;

@RestController
@RequestMapping("/api/v1/trips")
public class TripController {
 private final TripService service;
 public TripController(TripService service) { this.service=service; }

 @PostMapping
 @ResponseStatus(HttpStatus.CREATED)
 public TripDtos.TripDetail create(@Valid @RequestBody TripDtos.CreateTripRequest req) {
  return service.create(CurrentUser.id(),req);
 }

 @GetMapping
 public List<TripDtos.TripSummary> list() {
  return service.list(CurrentUser.id());
 }

 @GetMapping("/{id}")
 public TripDtos.TripDetail detail(@PathVariable UUID id) {
  return service.detail(CurrentUser.id(),id);
 }

 @PatchMapping("/{id}")
 public TripDtos.TripDetail update(@PathVariable UUID id,@Valid @RequestBody TripDtos.UpdateTripRequest req) {
  return service.update(CurrentUser.id(),id,req);
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

 @PatchMapping("/{id}/stops/reorder")
 public TripDtos.TripDetail reorder(@PathVariable UUID id,@Valid @RequestBody TripDtos.ReorderStopsRequest req) {
  return service.reorderStops(CurrentUser.id(),id,req);
 }
}
