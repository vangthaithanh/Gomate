package vn.gomate.place.controller;

import java.util.*;
import org.springframework.web.bind.annotation.*;
import vn.gomate.place.service.PlaceSearchService;

@RestController
@RequestMapping("/api/v1/search/places")
public class PlaceSearchController {
    private final PlaceSearchService search;
    public PlaceSearchController(PlaceSearchService search) {this.search=search;}
    @GetMapping public PlaceSearchService.Page search(@RequestParam(defaultValue="") String q,@RequestParam(defaultValue="") List<String> filters,@RequestParam(required=false) Double latitude,@RequestParam(required=false) Double longitude,@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {
        return search.search(q,filters,latitude,longitude,size,cursor);
    }
}
