package vn.gomate.social.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import vn.gomate.common.Errors;

@Component
public class PostRequestPolicyFilter extends OncePerRequestFilter {
 private final ObjectMapper json;
 public PostRequestPolicyFilter(ObjectMapper json) {this.json=json;}
 @Override protected void doFilterInternal(HttpServletRequest req,HttpServletResponse res,FilterChain chain) throws ServletException,IOException {
  boolean post=req.getRequestURI().startsWith("/api/v1/posts");
  if(req.getRequestURI().startsWith("/api/v1/search")) {res.setHeader("Cache-Control","private, no-store, max-age=0");res.setHeader("Pragma","no-cache");}
  if(post || req.getRequestURI().startsWith("/api/v1/comments") || req.getRequestURI().startsWith("/api/v1/me/reports") || req.getRequestURI().equals("/api/v1/feed")
   || req.getRequestURI().equals("/api/v1/me/liked-posts") || req.getRequestURI().equals("/api/v1/me/saved-posts") || req.getRequestURI().equals("/api/v1/me/comments")) {res.setHeader("Cache-Control","private, no-store, max-age=0");res.setHeader("Pragma","no-cache");}
  // Raising the parser ceiling for Post must not relax legacy module file limits.
  if(!post && req.getContentType()!=null && req.getContentType().startsWith("multipart/")) {
   for(var part:req.getParts()) if(part.getSubmittedFileName()!=null && part.getSize()>1048576) {
    res.setStatus(413);res.setContentType("application/json");json.writeValue(res.getOutputStream(),Errors.body(413,"MEDIA_TOO_LARGE","Tệp vượt giới hạn tải lên hiện tại."));return;
   }
  }
  chain.doFilter(req,res);
 }
}
