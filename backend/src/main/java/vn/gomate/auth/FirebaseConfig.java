package vn.gomate.auth;

import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
public class FirebaseConfig {
    @Bean(destroyMethod = "delete")
    FirebaseApp firebaseApp(
            @Value("${app.firebase.project-id}") String projectId,
            @Value("${app.firebase.credentials-path}") String credentialsPath) throws IOException {
        if (projectId.isBlank() || credentialsPath.isBlank()) {
            throw new IllegalStateException(
                    "Bật Firebase cần FIREBASE_PROJECT_ID và GOOGLE_APPLICATION_CREDENTIALS.");
        }
        // Auth Emulator bỏ kiểm tra chữ ký; bản backend này chỉ nhận token Firebase thật.
        String emulator = System.getenv("FIREBASE_AUTH_EMULATOR_HOST");
        if (emulator != null && !emulator.isBlank()) {
            throw new IllegalStateException("Hãy bỏ FIREBASE_AUTH_EMULATOR_HOST khi chạy backend này.");
        }
        try (var stream = Files.newInputStream(Path.of(credentialsPath))) {
            var credentials = ServiceAccountCredentials.fromStream(stream);
            if (!projectId.trim().equals(credentials.getProjectId())) {
                throw new IllegalStateException("Service account và FIREBASE_PROJECT_ID phải cùng dự án.");
            }
            var options = FirebaseOptions.builder()
                    .setCredentials(credentials)
                    .setProjectId(projectId.trim())
                    .setConnectTimeout(5000)
                    .setReadTimeout(10000)
                    .build();
            return FirebaseApp.initializeApp(options, "gomate-auth");
        }
    }

    @Bean
    FirebaseAuth firebaseAuth(FirebaseApp app) {
        return FirebaseAuth.getInstance(app);
    }
}
