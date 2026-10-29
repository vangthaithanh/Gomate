package vn.gomate.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.client.http.LowLevelHttpRequest;
import com.google.api.client.testing.http.MockHttpTransport;
import com.google.api.client.testing.http.MockLowLevelHttpRequest;
import com.google.api.client.testing.http.MockLowLevelHttpResponse;
import com.google.auth.oauth2.AccessToken;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.support.DefaultListableBeanFactory;
import vn.gomate.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;

/** Chạy Firebase Admin SDK thật với khóa test và HTTP giả lập; không gọi Google. */
class FirebaseSdkVerificationTest {
    private static final String PROJECT = "gomate-sdk-test";
    private final ObjectMapper json = new ObjectMapper();
    private FirebaseApp app;
    private FirebaseGoogleVerifier verifier;
    private PrivateKey key;
    private boolean disabled;
    private boolean deleted;
    private long validSince;
    private int lookupCount;

    private String resource(String name) throws IOException {
        try (var stream = getClass().getResourceAsStream("/firebase/" + name)) {
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    @BeforeEach void setup() throws Exception {
        String pem = resource("test-only-private-key.pem")
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "").replaceAll("\\s", "");
        key = KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)));
        String cert = resource("test-only-certificate.pem");
        var transport = new MockHttpTransport() {
            @Override public LowLevelHttpRequest buildRequest(String method, String url) throws IOException {
                Object payload;
                if (url.equals("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")) {
                    payload = Map.of("test-key", cert);
                } else if (url.endsWith("/accounts:lookup")) {
                    lookupCount++;
                    payload = Map.of("users", deleted ? List.of() : List.of(Map.of(
                            "localId", "firebase-user", "disabled", disabled, "validSince", Long.toString(validSince))));
                } else {
                    throw new AssertionError("Unexpected HTTP request: " + method + " " + url);
                }
                return new MockLowLevelHttpRequest(url).setResponse(new MockLowLevelHttpResponse()
                        .setContentType("application/json")
                        .addHeader("Cache-Control", "max-age=3600")
                        .setContent(json.writeValueAsString(payload)));
            }
        };
        app = FirebaseApp.initializeApp(FirebaseOptions.builder()
                .setProjectId(PROJECT)
                .setCredentials(GoogleCredentials.create(new AccessToken("test-only-oauth-token", Date.from(Instant.now().plusSeconds(3600)))))
                .setHttpTransport(transport).build(), "test-" + UUID.randomUUID());
        var factory = new DefaultListableBeanFactory();
        factory.registerSingleton("firebaseAuth", FirebaseAuth.getInstance(app));
        verifier = new FirebaseGoogleVerifier(factory.getBeanProvider(FirebaseAuth.class));
    }

    @AfterEach void cleanup() { if (app != null) app.delete(); }

    private String token(String audience, String issuer, Instant expiry, PrivateKey signer) throws Exception {
        var claims = new JWTClaimsSet.Builder()
                .subject("firebase-user").audience(audience).issuer(issuer)
                .issueTime(Date.from(Instant.now().minusSeconds(20))).expirationTime(Date.from(expiry))
                .claim("auth_time", Instant.now().minusSeconds(30).getEpochSecond())
                .claim("email", "person@example.com").claim("email_verified", true)
                .claim("firebase", Map.of("sign_in_provider", "google.com",
                        "identities", Map.of("google.com", List.of("original-google-subject")))).build();
        var jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("test-key").build(), claims);
        jwt.sign(new RSASSASigner(signer));
        return jwt.serialize();
    }

    private String validToken() throws Exception {
        return token(PROJECT, "https://securetoken.google.com/" + PROJECT, Instant.now().plusSeconds(3600), key);
    }

    private void unauthorized(String token) {
        var error = assertThrows(ApiException.class, () -> verifier.verify(token));
        assertEquals(401, error.status);
    }

    @Test void sdkChecksSignatureAndLooksUpRevocationState() throws Exception {
        assertEquals("original-google-subject", verifier.verify(validToken()).subject());
        assertEquals(1, lookupCount, "verifyIdToken must check revoked/disabled users");
    }

    @Test void rejectsAnotherFirebaseProject() throws Exception {
        unauthorized(token("other-project", "https://securetoken.google.com/" + PROJECT, Instant.now().plusSeconds(3600), key));
        assertEquals(0, lookupCount);
    }

    @Test void rejectsWrongIssuerAndRawGoogleIdToken() throws Exception {
        unauthorized(token(PROJECT, "https://accounts.google.com", Instant.now().plusSeconds(3600), key));
        unauthorized(token("web-client.apps.googleusercontent.com", "https://accounts.google.com", Instant.now().plusSeconds(3600), key));
    }

    @Test void rejectsExpiredToken() throws Exception {
        unauthorized(token(PROJECT, "https://securetoken.google.com/" + PROJECT, Instant.now().minusSeconds(600), key));
    }

    @Test void rejectsForgedSignature() throws Exception {
        var generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        unauthorized(token(PROJECT, "https://securetoken.google.com/" + PROJECT, Instant.now().plusSeconds(3600), generator.generateKeyPair().getPrivate()));
    }

    @Test void rejectsRevokedFirebaseToken() throws Exception {
        validSince = Instant.now().getEpochSecond();
        unauthorized(validToken());
        assertEquals(1, lookupCount);
    }

    @Test void rejectsDisabledFirebaseUser() throws Exception {
        disabled = true;
        unauthorized(validToken());
    }

    @Test void rejectsDeletedFirebaseUser() throws Exception {
        deleted = true;
        unauthorized(validToken());
    }
}
