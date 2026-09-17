package vn.gomate.auth;
import java.util.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1")
public class AuthController {
 private final FirebaseGoogleVerifier google;private final AuthService service;private final AuthRepository repo;
 public AuthController(AuthService service,AuthRepository repo,FirebaseGoogleVerifier google) { this.google=google;this.service=service;this.repo=repo; }
 @PostMapping("/auth/register") @ResponseStatus(HttpStatus.CREATED)
 public Map<String,Object> register(@Valid @RequestBody AuthDtos.Register req) { return service.register(req); }
 @PostMapping("/auth/login") public Map<String,Object> login(@Valid @RequestBody AuthDtos.Login req) { return service.login(req); }
 @PostMapping("/auth/refresh") public Map<String,Object> refresh(@Valid @RequestBody AuthDtos.Refresh req) { return service.refresh(req.refreshToken()); }
 @PostMapping("/auth/logout") @ResponseStatus(HttpStatus.NO_CONTENT)
 public void logout() { service.logout(CurrentUser.id(),CurrentUser.sessionId()); }
 @PostMapping("/auth/change-password") @ResponseStatus(HttpStatus.NO_CONTENT)
 public void password(@Valid @RequestBody AuthDtos.ChangePassword req) { service.changePassword(CurrentUser.id(),req); }
 @GetMapping("/users/me") public Map<String,Object> me() { return repo.profile(CurrentUser.id()); }
 @PostMapping("/auth/google") public Map<String,Object> google(@Valid @RequestBody AuthDtos.Google req) { return service.google(google.verify(req.idToken())); }
 @PostMapping("/auth/google/link") public Map<String,Object> link(@Valid @RequestBody AuthDtos.Google req) { return service.linkGoogle(CurrentUser.id(),google.verify(req.idToken())); }
 @PutMapping("/users/me/onboarding") public Map<String,Object> onboarding(@Valid @RequestBody AuthDtos.Onboarding req) { return service.onboarding(CurrentUser.id(),req.optionCodes()); }
}
