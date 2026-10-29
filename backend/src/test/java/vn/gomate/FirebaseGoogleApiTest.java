package vn.gomate;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.auth.FirebaseGoogleVerifier;
import vn.gomate.common.ApiException;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class FirebaseGoogleApiTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @MockitoBean FirebaseGoogleVerifier verifier;

    @Test void firebaseLoginIssuesGoMateSessionAndUsesExistingRefreshAndLogout() throws Exception {
        String subject = UUID.randomUUID().toString();
        when(verifier.verify("firebase-id-token")).thenReturn(new FirebaseGoogleVerifier.Identity(
                "firebase-uid", subject, subject + "@example.com", "Google User"));
        var response = mvc.perform(post("/api/v1/auth/google").contentType("application/json")
                .content(json.writeValueAsBytes(Map.of("idToken", "firebase-id-token"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.user.googleLinked").value(true))
                .andExpect(jsonPath("$.user.passwordHash").doesNotExist())
                .andReturn().getResponse().getContentAsString();
        var session = json.readTree(response);
        String access = session.get("accessToken").asText();
        String refresh = session.get("refreshToken").asText();
        verify(verifier).verify("firebase-id-token");
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer firebase-id-token"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/refresh").contentType("application/json")
                .content(json.writeValueAsBytes(Map.of("refreshToken", refresh))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.accessToken").isString());
        mvc.perform(post("/api/v1/auth/logout").header("Authorization", "Bearer " + access))
                .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + access))
                .andExpect(status().isUnauthorized());
    }

    @Test void rejectsInvalidFirebaseTokenThroughHttp() throws Exception {
        when(verifier.verify("bad-token")).thenThrow(new ApiException(401, "INVALID_FIREBASE_TOKEN", "Invalid token"));
        mvc.perform(post("/api/v1/auth/google").contentType("application/json").content("{\"idToken\":\"bad-token\"}"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("INVALID_FIREBASE_TOKEN"));
    }

    @Test void cannotLinkGoogleWithoutGoMateSession() throws Exception {
        mvc.perform(post("/api/v1/auth/google/link").contentType("application/json").content("{\"idToken\":\"token\"}"))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(verifier);
    }
}
