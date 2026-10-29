package vn.gomate.auth;

import com.google.firebase.ErrorCode;
import com.google.firebase.auth.AuthErrorCode;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import vn.gomate.common.ApiException;

/** Firebase xác thực chữ ký, issuer, project, thời hạn và trạng thái tài khoản. */
@Component
public class FirebaseGoogleVerifier {
    @FunctionalInterface
    interface TokenVerifier {
        Map<String, Object> verify(String token) throws FirebaseAuthException;
    }

    private final TokenVerifier verifier;

    @Autowired
    public FirebaseGoogleVerifier(ObjectProvider<FirebaseAuth> provider) {
        FirebaseAuth auth = provider.getIfAvailable();
        // true: kiểm tra token bị thu hồi và tài khoản Firebase bị khóa/xóa.
        this.verifier = auth == null ? null : token -> auth.verifyIdToken(token, true).getClaims();
    }

    FirebaseGoogleVerifier(TokenVerifier verifier) {
        this.verifier = verifier;
    }

    public record Identity(String firebaseUid, String subject, String email, String fullName) {}

    public Identity verify(String token) {
        if (verifier == null) {
            throw new ApiException(503, "FIREBASE_NOT_CONFIGURED",
                    "Máy chủ chưa bật Firebase. Kiểm tra FIREBASE_ENABLED, project ID và service account.");
        }
        if (token == null || token.isBlank() || token.length() > 10000) {
            throw invalidToken();
        }
        try {
            Map<String, Object> claims = verifier.verify(token);
            String uid = text(claims.get("sub"));
            String email = text(claims.get("email"));
            Object firebaseClaim = claims.get("firebase");
            if (uid == null || uid.isBlank() || uid.length() > 128
                    || !Boolean.TRUE.equals(claims.get("email_verified"))
                    || email == null || email.length() > 254
                    || !email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")
                    || !(firebaseClaim instanceof Map<?, ?> firebase)
                    || !"google.com".equals(firebase.get("sign_in_provider"))
                    || firebase.get("tenant") != null
                    || !(firebase.get("identities") instanceof Map<?, ?> identities)
                    || !(identities.get("google.com") instanceof List<?> subjects)
                    || subjects.size() != 1
                    || !(subjects.get(0) instanceof String subject)
                    || subject.isBlank() || subject.length() > 255) {
                throw invalidToken();
            }
            // Giữ Google provider ID trong google_subject để tài khoản Google cũ vẫn dùng được.
            // Không ghi Firebase UID vào cột này vì hai loại ID không giống nhau.
            String name = text(claims.get("name"));
            return new Identity(uid, subject, AuthService.email(email),
                    name == null ? null : name.substring(0, Math.min(120, name.length())));
        } catch (FirebaseAuthException e) {
            AuthErrorCode code = e.getAuthErrorCode();
            if (code == AuthErrorCode.CERTIFICATE_FETCH_FAILED
                    || e.getErrorCode() == ErrorCode.UNAVAILABLE
                    || e.getErrorCode() == ErrorCode.INTERNAL
                    || e.getErrorCode() == ErrorCode.DEADLINE_EXCEEDED
                    || e.getErrorCode() == ErrorCode.PERMISSION_DENIED) {
                throw new ApiException(503, "FIREBASE_UNAVAILABLE",
                        "Chưa xác thực được với Firebase. Kiểm tra kết nối và cấu hình máy chủ rồi thử lại.");
            }
            throw invalidToken();
        } catch (IllegalArgumentException e) {
            throw invalidToken();
        }
    }

    private static String text(Object value) {
        return value instanceof String s ? s : null;
    }

    private static ApiException invalidToken() {
        return new ApiException(401, "INVALID_FIREBASE_TOKEN",
                "Firebase ID token không hợp lệ hoặc hết hạn. Vui lòng đăng nhập Google lại.");
    }
}
