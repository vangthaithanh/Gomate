package vn.gomate.place.review;

import java.util.Map;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;

@RestController @RequestMapping("/api/v1")
public class PlaceReviewController {
 private final PlaceReviewService service;
 public PlaceReviewController(PlaceReviewService service) {this.service=service;}
 @PostMapping("/places/{placeId}/reviews")
 public Map<String,Object> submit(@PathVariable long placeId,@RequestBody PlaceReviewService.Write body) {return service.submit(CurrentUser.id(),placeId,body);}
 @PatchMapping("/reviews/{id}")
 public Map<String,Object> edit(@PathVariable long id,@RequestBody PlaceReviewService.Write body) {return service.edit(CurrentUser.id(),id,body);}
 @DeleteMapping("/reviews/{id}")
 public Map<String,Object> delete(@PathVariable long id) {return service.delete(CurrentUser.id(),id);}
 @GetMapping("/places/{placeId}/reviews/me")
 public Map<String,Object> mine(@PathVariable long placeId) {return service.mine(CurrentUser.id(),placeId);}
 @GetMapping("/places/{placeId}/reviews")
 public Map<String,Object> page(@PathVariable long placeId,@RequestParam(defaultValue="20") int size,@RequestParam(defaultValue="9223372036854775807") long beforeId,@RequestParam(defaultValue="newest") String sort) {return service.page(CurrentUser.id(),placeId,size,beforeId,sort);}
}
