package vn.gomate.media.config;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "app.cloudinary.enabled", havingValue = "true")
public class CloudinaryConfig {

    @Bean
    Cloudinary cloudinary(@Value("${app.cloudinary.url}") String cloudinaryUrl) {
        if (cloudinaryUrl == null || cloudinaryUrl.isBlank()) {
            throw new IllegalStateException("Bật Cloudinary cần CLOUDINARY_URL.");
        }
        URI uri = URI.create(cloudinaryUrl);
        if (!"cloudinary".equalsIgnoreCase(uri.getScheme())) {
            throw new IllegalStateException("CLOUDINARY_URL phải dùng scheme cloudinary://.");
        }
        String cloudName = uri.getHost();
        String userInfo = uri.getUserInfo();
        if (cloudName == null || cloudName.isBlank() || userInfo == null || !userInfo.contains(":")) {
            throw new IllegalStateException("CLOUDINARY_URL thiếu cloud name, api key hoặc api secret.");
        }
        String[] credentials = userInfo.split(":", 2);
        String apiKey = URLDecoder.decode(credentials[0], StandardCharsets.UTF_8);
        String apiSecret = URLDecoder.decode(credentials[1], StandardCharsets.UTF_8);
        return new Cloudinary(ObjectUtils.asMap(
            "cloud_name", cloudName,
            "api_key", apiKey,
            "api_secret", apiSecret,
            "secure", true
        ));
    }
}
