package vn.gomate.common;
import java.util.Map;
import io.swagger.v3.oas.models.*;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.*;
import org.springframework.context.annotation.*;
import org.springframework.web.bind.annotation.*;
@Configuration
public class ApiConfig {
 @Bean OpenAPI openApi() {
  return new OpenAPI().info(new Info().title("GoMate API").version("v1"))
   .components(new Components().addSecuritySchemes("bearerAuth",new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")))
   .addSecurityItem(new SecurityRequirement().addList("bearerAuth"));
 }
 @RestController public static class Health {
  @GetMapping("/api/v1/health") public Map<String,String> health() { return Map.of("status","UP"); }
 }
}
