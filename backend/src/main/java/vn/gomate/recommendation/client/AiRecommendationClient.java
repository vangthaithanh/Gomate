package vn.gomate.recommendation.client;

import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import vn.gomate.common.ApiException;
import vn.gomate.recommendation.dto.RecommendationDtos;

@Component
public class AiRecommendationClient {
    private final RestClient client;

    public AiRecommendationClient(
        @Value("${app.ai.recommendation-url:http://localhost:8000}") String baseUrl
    ) {
        this.client = RestClient.builder().baseUrl(baseUrl).build();
    }

    public RecommendationDtos.AiResponse coldStart(
        List<String> optionCodes,
        Double latitude,
        Double longitude,
        int topK
    ) {
        var request = new RecommendationDtos.AiRequest(
            optionCodes == null ? List.of() : optionCodes,
            null,
            latitude,
            longitude,
            Math.max(1, Math.min(topK, 50))
        );
        try {
            var response = client.post()
                .uri("/recommendations/cold-start")
                .contentType(MediaType.APPLICATION_JSON)
                .body(request)
                .retrieve()
                .body(RecommendationDtos.AiResponse.class);
            if (response == null) {
                throw new ApiException(503, "AI_INVALID_RESPONSE", "AI Service không trả dữ liệu.");
            }
            return response;
        } catch (RestClientException error) {
            throw new ApiException(
                503,
                "AI_UNAVAILABLE",
                "Không kết nối được AI Recommendation Service.",
                error
            );
        }
    }
}
