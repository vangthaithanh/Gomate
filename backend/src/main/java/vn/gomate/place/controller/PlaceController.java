package vn.gomate.place.controller;

import java.util.List;
import org.springframework.web.bind.annotation.*;
import vn.gomate.place.dto.PlaceDtos;
import vn.gomate.place.service.PlaceService;

@RestController @RequestMapping("/api/v1/places")
public class PlaceController {
 private final PlaceService service;
 public PlaceController(PlaceService service) { this.service=service; }

 @GetMapping
 public List<PlaceDtos.Summary> list() { return service.list(); }

 @GetMapping("/search")
 public List<PlaceDtos.Summary> search(@RequestParam(name="q",required=false) String q) { return service.search(q); }

 @GetMapping("/{id}")
 public PlaceDtos.Detail detail(@PathVariable long id) { return service.detail(id); }
}
