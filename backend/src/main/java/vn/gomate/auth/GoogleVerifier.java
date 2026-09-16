package vn.gomate.auth;

import java.time.Instant;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;
import vn.gomate.common.ApiException;

/** Chỉ tin ID token đã kiểm tra chữ ký Google và audience của dự án. */
@Component
public class GoogleVerifier {
 private final JwtDecoder decoder;
 private final Set<String> audiences;
 @org.springframework.beans.factory.annotation.Autowired
 public GoogleVerifier(@Value("${app.google-client-ids:}") String ids) {
  this.audiences=new HashSet<>(Arrays.asList(ids.split(",")));
  this.audiences.removeIf(String::isBlank);
  var factory=new SimpleClientHttpRequestFactory();
  factory.setConnectTimeout(5000);factory.setReadTimeout(5000);
  this.decoder=NimbusJwtDecoder.withJwkSetUri("https://www.googleapis.com/oauth2/v3/certs")
   .restOperations(new RestTemplate(factory)).build();
 }
 GoogleVerifier(JwtDecoder decoder,Set<String> audiences) {this.decoder=decoder;this.audiences=audiences;}
 public record Identity(String subject,String email,String fullName) {}
 public Identity verify(String token) {
  if(audiences.isEmpty()) throw new ApiException(503,"GOOGLE_NOT_CONFIGURED","Máy chủ chưa cấu hình Google Client ID.");
  try {
   Jwt jwt=decoder.decode(token);
   String issuer=jwt.getClaimAsString("iss");
   String subject=jwt.getSubject();String email=jwt.getClaimAsString("email");
   if(!Set.of("https://accounts.google.com","accounts.google.com").contains(issuer==null?"":issuer)
    || Collections.disjoint(jwt.getAudience(),audiences)
    || jwt.getExpiresAt()==null || !jwt.getExpiresAt().isAfter(Instant.now())
    || subject==null || subject.isBlank() || subject.length()>255
    || !Boolean.TRUE.equals(jwt.getClaimAsBoolean("email_verified"))
    || email==null || email.length()>254 || !email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+"))
     throw new IllegalArgumentException("Invalid Google claims");
   String name=jwt.getClaimAsString("name");
   return new Identity(subject,AuthService.email(email),name==null?null:name.substring(0,Math.min(120,name.length())));
  } catch(JwtException|IllegalArgumentException e) {
   throw new ApiException(401,"INVALID_GOOGLE_TOKEN","Không xác thực được Google. Vui lòng thử đăng nhập lại.");
  }
 }
}
