package vn.gomate.auth;
import java.nio.charset.StandardCharsets;
import java.util.*;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import com.nimbusds.jose.jwk.source.ImmutableSecret;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.*;
import vn.gomate.common.Errors;
@Configuration @EnableMethodSecurity
public class SecurityConfig {
 @Bean PasswordEncoder passwords() { return new BCryptPasswordEncoder(12); }
 @Bean SecretKey key(@Value("${app.jwt-secret}") String secret) {
  byte[] bytes=secret.getBytes(StandardCharsets.UTF_8);
  if(bytes.length<32) throw new IllegalStateException("JWT_SECRET phải ngẫu nhiên và ít nhất 32 byte.");
  return new SecretKeySpec(bytes,"HmacSHA256");
 }
 @Bean JwtEncoder encoder(SecretKey key) { return new NimbusJwtEncoder(new ImmutableSecret<>(key)); }
 @Bean JwtDecoder decoder(SecretKey key,@Value("${app.issuer}") String issuer,AuthRepository repo) {
  NimbusJwtDecoder decoder=NimbusJwtDecoder.withSecretKey(key).macAlgorithm(MacAlgorithm.HS256).build();
  OAuth2TokenValidator<Jwt> session=jwt->{
   try {
    if(jwt.getAudience().contains("gomate-app") && repo.activeSession(UUID.fromString(jwt.getClaimAsString("sid")),UUID.fromString(jwt.getSubject())))
     return OAuth2TokenValidatorResult.success();
   } catch(IllegalArgumentException|NullPointerException ignored) { }
   return OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token"));
  };
  decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer(issuer),session));return decoder;
 }
 @Bean SecurityFilterChain security(HttpSecurity http,AuthRepository repo,ObjectMapper mapper,
  @Value("${app.cors-origins}") String origins,@Value("${app.auth-requests-per-minute}") int limit) throws Exception {
  CorsConfiguration cors=new CorsConfiguration();cors.setAllowedOrigins(Arrays.asList(origins.split(",")));
  cors.setAllowedMethods(List.of("GET","POST","PUT","PATCH","DELETE","OPTIONS"));cors.setAllowedHeaders(List.of("Authorization","Content-Type"));
  UrlBasedCorsConfigurationSource source=new UrlBasedCorsConfigurationSource();source.registerCorsConfiguration("/**",cors);
  http.csrf(c->c.disable()).cors(c->c.configurationSource(source)).sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
   .authorizeHttpRequests(a->a.requestMatchers("/swagger-ui/**","/swagger-ui.html","/v3/api-docs/**","/health","/api/v1/health").permitAll()
    .requestMatchers(HttpMethod.POST,"/api/v1/auth/register","/api/v1/auth/login","/api/v1/auth/refresh","/api/v1/auth/google").permitAll()
    .requestMatchers(HttpMethod.POST,"/api/v1/routes/compute","/api/v1/routes/directions").permitAll()
    .requestMatchers("/api/v1/admin/**").hasRole("ADMIN").anyRequest().authenticated())
   .oauth2ResourceServer(o->o.jwt(j->j.jwtAuthenticationConverter(jwt->{
    String role=(String)repo.profile(UUID.fromString(jwt.getSubject())).get("role");
    return new JwtAuthenticationToken(jwt,List.of(new SimpleGrantedAuthority("ROLE_"+role)));
   })).authenticationEntryPoint((req,res,e)->{
    res.setStatus(401);res.setContentType("application/json");mapper.writeValue(res.getOutputStream(),Errors.body(401,"UNAUTHORIZED","Vui lòng đăng nhập lại."));
   }))
   .exceptionHandling(e->e.authenticationEntryPoint((req,res,ex)->{
    res.setStatus(401);res.setContentType("application/json");mapper.writeValue(res.getOutputStream(),Errors.body(401,"UNAUTHORIZED","Vui lòng đăng nhập."));
   }).accessDeniedHandler((req,res,ex)->{
    res.setStatus(403);res.setContentType("application/json");mapper.writeValue(res.getOutputStream(),Errors.body(403,"FORBIDDEN","Bạn không có quyền truy cập."));
   })).addFilterBefore(new AuthRateLimitFilter(limit,mapper),BearerTokenAuthenticationFilter.class);
  return http.build();
 }
}
