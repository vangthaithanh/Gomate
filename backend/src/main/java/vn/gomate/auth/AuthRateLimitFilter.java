package vn.gomate.auth;
import java.io.IOException;
import java.util.*;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.web.filter.OncePerRequestFilter;
import vn.gomate.common.Errors;
/** Giới hạn IP trực tiếp, một JVM. Không tin X-Forwarded-For từ client. */
public class AuthRateLimitFilter extends OncePerRequestFilter {
 private record Window(long minute,int count) {}
 private final Map<String,Window> windows=new LinkedHashMap<>();
 private final int limit;private final ObjectMapper mapper;
 public AuthRateLimitFilter(int limit,ObjectMapper mapper) { this.limit=limit;this.mapper=mapper; }
 private synchronized boolean allow(String ip) {
  long minute=System.currentTimeMillis()/60000;
  windows.entrySet().removeIf(e->e.getValue().minute()!=minute);
  Window old=windows.getOrDefault(ip,new Window(minute,0));
  if(old.count()>=limit || (!windows.containsKey(ip) && windows.size()>=10000)) return false;
  windows.put(ip,new Window(minute,old.count()+1));return true;
 }
 @Override protected void doFilterInternal(HttpServletRequest req,HttpServletResponse res,FilterChain chain) throws ServletException,IOException {
  if(req.getMethod().equals("POST") && req.getServletPath().startsWith("/api/v1/auth/") && !allow(req.getRemoteAddr())) {
   res.setStatus(429);res.setHeader("Retry-After","60");res.setContentType("application/json");
   mapper.writeValue(res.getOutputStream(),Errors.body(429,"RATE_LIMITED","Thao tác quá nhiều. Vui lòng thử lại sau."));return;
  }
  chain.doFilter(req,res);
 }
}
