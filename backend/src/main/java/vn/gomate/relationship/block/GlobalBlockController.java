package vn.gomate.relationship.block;

import java.util.*;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;

@RestController @RequestMapping("/api/v1/users")
public class GlobalBlockController {
 private final GlobalBlockService service;
 public GlobalBlockController(GlobalBlockService service) {this.service=service;}
 @PutMapping("/{id}/block") public Map<String,Object> block(@PathVariable UUID id) {return service.set(CurrentUser.id(),id,true);}
 @DeleteMapping("/{id}/block") public Map<String,Object> unblock(@PathVariable UUID id) {return service.set(CurrentUser.id(),id,false);}
 @GetMapping("/me/blocked") public Map<String,Object> list(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {return service.list(CurrentUser.id(),page,size);}
}
