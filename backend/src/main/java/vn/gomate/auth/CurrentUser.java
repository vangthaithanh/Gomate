package vn.gomate.auth;
import java.util.UUID;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
public final class CurrentUser {
 private CurrentUser() {}
 private static Jwt jwt() { return (Jwt)SecurityContextHolder.getContext().getAuthentication().getPrincipal(); }
 public static UUID id() { return UUID.fromString(jwt().getSubject()); }
 public static UUID sessionId() { return UUID.fromString(jwt().getClaimAsString("sid")); }
}
