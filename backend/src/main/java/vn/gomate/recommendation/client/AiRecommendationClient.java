package vn.gomate.recommendation.client;

import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import vn.gomate.common.ApiException;
import vn.gomate.recommendation.dto.RecommendationDtos;

@Component
public class AiRecommendationClient {
    private final RestClient client;

    public AiRecommendationClient(
        @Value("${app.ai.recommendation-url:http://localhost:8000}") String baseUrl,
        @Value("${app.ai.recommendation-timeout-ms:2500}") int timeoutMs
    ) {
        var requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(timeoutMs);
        requestFactory.setReadTimeout(timeoutMs);
        this.client = RestClient.builder()
            .baseUrl(baseUrl)
            .requestFactory(requestFactory)
            .build();
    }

    public RecommendationDtos.AiResponse coldStart(
        String destinationKey,
        List<String> semanticInterestCodes,
        List<String> contextCodes,
        int topK
    ) {
        var request = new RecommendationDtos.AiRequest(
            destinationKey,
            semanticInterestCodes == null ? List.of() : semanticInterestCodes,
            contextCodes == null ? List.of() : contextCodes,
            Math.max(1, Math.min(topK, 100)),
            false
        );
        try {
            var response = client.post()
                .uri("/recommend")
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
