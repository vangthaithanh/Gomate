package vn.gomate.auth;
import java.time.Instant;
import java.util.*;
import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jwt.*;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import vn.gomate.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;
class GoogleVerifierTest {
 final RSAKey key=new RSAKeyGenerator(2048).generate();
 final GoogleVerifier verifier=new GoogleVerifier(NimbusJwtDecoder.withPublicKey(key.toRSAPublicKey()).build(),Set.of("web-client"));
 GoogleVerifierTest() throws Exception {}
 String token(String audience,String issuer,boolean verified,Instant expiry,RSAKey signer) throws Exception {
  var claims=new JWTClaimsSet.Builder().subject("google-subject").issuer(issuer).audience(audience)
   .issueTime(Date.from(Instant.now().minusSeconds(10))).expirationTime(Date.from(expiry))
   .claim("email","person@example.com").claim("email_verified",verified).build();
  var jwt=new SignedJWT(new JWSHeader(JWSAlgorithm.RS256),claims);jwt.sign(new RSASSASigner(signer));return jwt.serialize();
 }
 @Test void verifiesValidSignatureAndClaims() throws Exception {
  assertEquals("google-subject",verifier.verify(token("web-client","https://accounts.google.com",true,Instant.now().plusSeconds(300),key)).subject());
 }
 @Test void rejectsWrongAudience() {assertThrows(ApiException.class,()->verifier.verify(token("attacker","https://accounts.google.com",true,Instant.now().plusSeconds(300),key)));}
 @Test void rejectsWrongIssuer() {assertThrows(ApiException.class,()->verifier.verify(token("web-client","https://evil.example",true,Instant.now().plusSeconds(300),key)));}
 @Test void rejectsUnverifiedEmail() {assertThrows(ApiException.class,()->verifier.verify(token("web-client","https://accounts.google.com",false,Instant.now().plusSeconds(300),key)));}
 @Test void rejectsExpired() {assertThrows(ApiException.class,()->verifier.verify(token("web-client","https://accounts.google.com",true,Instant.now().minusSeconds(90),key)));}
 @Test void rejectsWrongSignature() {assertThrows(ApiException.class,()->verifier.verify(token("web-client","https://accounts.google.com",true,Instant.now().plusSeconds(300),new RSAKeyGenerator(2048).generate())));}
}
