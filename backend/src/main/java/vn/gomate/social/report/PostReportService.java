package vn.gomate.social.report;

import java.util.*;
import java.time.OffsetDateTime;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.*;
import vn.gomate.social.post.PostService;
import vn.gomate.social.comment.*;

@Service
public class PostReportService {
 public static final Set<String> REASONS=Set.of("NEGATIVE_OR_VIOLENCE","NUDITY_OR_INAPPROPRIATE","SCAM_OR_SPAM","PROHIBITED_GOODS","FALSE_INFORMATION","INTELLECTUAL_PROPERTY");
 private final PostReportRepository repo;private final CommentService gate;private final PostService posts;private final ObjectMapper json;
 public PostReportService(PostReportRepository repo,CommentService gate,PostService posts,ObjectMapper json) {this.repo=repo;this.gate=gate;this.posts=posts;this.json=json;}
 public record Create(UUID clientRequestId,String reasonCode,String description) {}
 public record Page(List<Map<String,Object>> items,String nextCursor) {}
 public record Cursor(UUID viewer,OffsetDateTime created,UUID id) {}
 private Map<String,Object> project(Map<String,Object> row) {
  var out=new LinkedHashMap<String,Object>();for(String key:List.of("id","postId","reasonCode","details","status")) out.put(key,row.get(key));out.put("createdAt",PostService.instant(row.get("createdAt")));return out;
 }
 @Transactional public Map<String,Object> create(UUID actor,long post,Create req) {
  String description=req.description()==null?"":req.description();CommentService.length(description,1000);
  if(req.clientRequestId()==null || req.reasonCode()==null || !REASONS.contains(req.reasonCode())) throw ApiException.bad("Lý do báo cáo không hợp lệ.");
  gate.lock(actor,post);if(actor.equals(posts.authorize(actor,post).get("authorId"))) throw new ApiException(403,"OWN_POST_REPORT","Không báo cáo bài viết của chính mình.");
  String hash=PostService.digest((post+"\n"+req.reasonCode()+"\n"+description).getBytes(java.nio.charset.StandardCharsets.UTF_8));
  var row=repo.insert(actor,post,req,hash,description);
  if(!hash.equals(row.get("requestHash"))) throw new ApiException(409,"REPORT_KEY_REUSED","Mã gửi báo cáo đã dùng cho nội dung khác.");return project(row);
 }
 public Map<String,Object> detail(UUID actor,UUID id) {return project(repo.detail(actor,id));}
 public Page list(UUID actor,int size,String token) {
  if(size<1 || size>50) throw ApiException.bad("Kích thước trang từ 1 đến 50.");
  Cursor cursor=null;
  if(token!=null) try {cursor=json.readValue(Base64.getUrlDecoder().decode(token),Cursor.class);if(!actor.equals(cursor.viewer()) || cursor.created()==null || cursor.id()==null) throw new IllegalArgumentException();}catch(Exception e) {throw ApiException.bad("Con trỏ không hợp lệ.");}
  var rows=repo.page(actor,size+1,cursor);var page=rows.subList(0,Math.min(size,rows.size()));String next=null;
  if(rows.size()>size) try {var last=page.get(page.size()-1);next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(new Cursor(actor,PostService.instant(last.get("createdAt")),(UUID)last.get("id"))));}catch(Exception e) {throw new IllegalStateException(e);}
  return new Page(page.stream().map(this::project).toList(),next);
 }
}
