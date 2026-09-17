package vn.gomate.auth;

import com.google.firebase.auth.AuthErrorCode;
import com.google.firebase.auth.FirebaseAuthException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import vn.gomate.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class FirebaseGoogleVerifierTest {
    static Map<String, Object> claims() {
        var claims = new HashMap<String, Object>();
        claims.put("sub", "firebase-uid-not-google-subject");
        claims.put("email", "Person@Example.com");
        claims.put("email_verified", true);
        claims.put("name", "Google Test");
        claims.put("firebase", Map.of("sign_in_provider", "google.com",
                "identities", Map.of("google.com", List.of("google-subject"))));
        return claims;
    }

    private FirebaseGoogleVerifier verifier(Map<String, Object> claims) {
        return new FirebaseGoogleVerifier(token -> claims);
    }

    private void rejects(Map<String, Object> claims) {
        var error = assertThrows(ApiException.class, () -> verifier(claims).verify("firebase-token"));
        assertEquals(401, error.status);
        assertEquals("INVALID_FIREBASE_TOKEN", error.code);
    }

    @Test void extractsGoogleProviderIdInsteadOfFirebaseUid() {
        var identity = verifier(claims()).verify("firebase-token");
        assertEquals("google-subject", identity.subject());
        assertEquals("firebase-uid-not-google-subject", identity.firebaseUid());
        assertEquals("person@example.com", identity.email());
    }

    @Test void rejectsPasswordLoginEvenWhenAccountHasLinkedGoogle() {
        var claims = claims();
        claims.put("firebase", Map.of("sign_in_provider", "password",
                "identities", Map.of("google.com", List.of("google-subject"))));
        rejects(claims);
    }

    @Test void rejectsUnverifiedOrMalformedEmail() {
        var claims = claims();
        claims.put("email_verified", false);
        rejects(claims);
        claims.put("email_verified", true);
        claims.put("email", "bad-email");
        rejects(claims);
    }

    @Test void rejectsMissingOrMalformedGoogleIdentity() {
        for (Object firebase : List.of("not-a-map", Map.of(),
                Map.of("sign_in_provider", "google.com", "identities", Map.of()),
                Map.of("sign_in_provider", "google.com", "identities", Map.of("google.com", "wrong-type")),
                Map.of("sign_in_provider", "google.com", "identities", Map.of("google.com", List.of(""))),
                Map.of("sign_in_provider", "google.com", "identities", Map.of("google.com", List.of("a", "b"))))) {
            var claims = claims();
            claims.put("firebase", firebase);
            rejects(claims);
        }
    }

    @Test void rejectsUnsupportedTenant() {
        var claims = claims();
        claims.put("firebase", Map.of("sign_in_provider", "google.com", "tenant", "another-tenant",
                "identities", Map.of("google.com", List.of("google-subject"))));
        rejects(claims);
    }

    @Test void rejectsMissingUidAndUidTooLong() {
        var claims = claims();
        claims.remove("sub");
        rejects(claims);
        claims.put("sub", "x".repeat(129));
        rejects(claims);
    }

    @Test void doesNotCallSdkForBlankOrOversizedInput() {
        var verifier = new FirebaseGoogleVerifier(token -> { fail("SDK should not run"); return Map.of(); });
        assertThrows(ApiException.class, () -> verifier.verify(""));
        assertThrows(ApiException.class, () -> verifier.verify("x".repeat(10001)));
    }

    @Test void rejectsSdkFailureWithoutExposingToken() {
        var failure = mock(FirebaseAuthException.class);
        when(failure.getAuthErrorCode()).thenReturn(AuthErrorCode.REVOKED_ID_TOKEN);
        var verifier = new FirebaseGoogleVerifier(token -> { throw failure; });
        var error = assertThrows(ApiException.class, () -> verifier.verify("secret-token"));
        assertEquals(401, error.status);
        assertFalse(error.getMessage().contains("secret-token"));
    }

    @Test void certificateOutageReturnsRetryableError() {
        var failure = mock(FirebaseAuthException.class);
        when(failure.getAuthErrorCode()).thenReturn(AuthErrorCode.CERTIFICATE_FETCH_FAILED);
        var verifier = new FirebaseGoogleVerifier(token -> { throw failure; });
        var error = assertThrows(ApiException.class, () -> verifier.verify("firebase-token"));
        assertEquals(503, error.status);
    }
}
