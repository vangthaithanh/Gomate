package vn.gomate.auth;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.Instant;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Service;
@Service
public class TokenService {
 private final JwtEncoder encoder;private final String issuer;
 public final long accessSeconds;
 private final SecureRandom random=new SecureRandom();
 public TokenService(JwtEncoder encoder,@Value("${app.issuer}") String issuer,@Value("${app.access-token-seconds}") long seconds) {
  this.encoder=encoder;this.issuer=issuer;this.accessSeconds=seconds;
 }
 public String access(UUID uid,UUID sid) {
  Instant now=Instant.now();
  var claims=JwtClaimsSet.builder().issuer(issuer).subject(uid.toString()).audience(List.of("gomate-app"))
   .issuedAt(now).expiresAt(now.plusSeconds(accessSeconds)).claim("sid",sid.toString()).build();
  return encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),claims)).getTokenValue();
 }
 public String refresh() { byte[] b=new byte[32];random.nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b); }
 public static String hash(String token) {
  try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8))); }
  catch(NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
 }
}
