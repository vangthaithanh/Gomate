package vn.gomate.social.report;
import java.util.*;
import org.springframework.web.bind.annotation.*;
import vn.gomate.auth.CurrentUser;
@RestController @RequestMapping("/api/v1")
public class PostReportController {
 private final PostReportService service;
 public PostReportController(PostReportService service) {this.service=service;}
 @PostMapping("/posts/{postId}/reports") @ResponseStatus(org.springframework.http.HttpStatus.CREATED) public Map<String,Object> create(@PathVariable long postId,@RequestBody PostReportService.Create body) {return service.create(CurrentUser.id(),postId,body);}
 @GetMapping("/me/reports") public PostReportService.Page list(@RequestParam(defaultValue="20") int size,@RequestParam(required=false) String cursor) {return service.list(CurrentUser.id(),size,cursor);}
 @GetMapping("/me/reports/{id}") public Map<String,Object> detail(@PathVariable UUID id) {return service.detail(CurrentUser.id(),id);}
}
