package vn.gomate.recommendation.dto;

import java.util.List;

public final class RecommendationDtos {
    private RecommendationDtos() {}

    public record AiRequest(
        List<String> optionCodes,
        String destinationKey,
        Double latitude,
        Double longitude,
        Integer topK
    ) {}

    public record AiRecommendation(
        String externalId,
        String name,
        String destinationKey,
        String category,
        Double latitude,
        Double longitude,
        Double score,
        String reason,
        String modelSource
    ) {}

    public record AiResponse(
        String modelVersion,
        Boolean coldStart,
        List<String> optionCodes,
        List<String> categories,
        String destinationKey,
        String scoringMode,
        List<AiRecommendation> recommendations,
        List<String> warnings
    ) {}
}
