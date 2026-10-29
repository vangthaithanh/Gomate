package vn.gomate.auth;
import jakarta.validation.constraints.*;
public final class AuthDtos {
 private AuthDtos() {}
 public record Register(@NotBlank @Email @Size(max=254) String email, @NotBlank @Size(min=8,max=72) String password, @NotBlank @Size(min=3,max=40) String nickname) {}
 public record Login(@NotBlank @Email @Size(max=254) String email, @NotBlank @Size(max=72) String password) {}
 public record Refresh(@NotBlank @Size(max=200) String refreshToken) {}
 public record ChangePassword(@NotBlank @Size(max=72) String currentPassword, @NotBlank @Size(min=8,max=72) String newPassword) {}
 /** idToken = FirebaseAuth.currentUser.getIdToken(), không phải Google OAuth ID token. */
 public record Google(@NotBlank @Size(max=10000) String idToken) {}
 public record Onboarding(@NotNull @Size(max=18) java.util.List<@NotBlank @Size(max=40) String> optionCodes) {}
}
