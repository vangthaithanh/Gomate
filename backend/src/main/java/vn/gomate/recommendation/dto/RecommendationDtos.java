package vn.gomate.recommendation.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public final class RecommendationDtos {
    private RecommendationDtos() {}

    public record AiRequest(
        @JsonProperty("destination_key") String destinationKey,
        @JsonProperty("selected_interest_codes") List<String> selectedInterestCodes,
        @JsonProperty("context_codes") List<String> contextCodes,
        @JsonProperty("top_k") Integer topK,
        @JsonProperty("include_runtime_ineligible") Boolean includeRuntimeIneligible
    ) {}

    public record AiRecommendation(
        Integer rank,
        @JsonProperty("external_id") String externalId,
        String name,
        @JsonProperty("destination_key") String destinationKey,
        String category,
        @JsonProperty("semantic_status") String semanticStatus,
        @JsonProperty("semantic_score") Double semanticScore,
        @JsonProperty("semantic_score_upper") Double semanticScoreUpper,
        @JsonProperty("semantic_coverage") Double semanticCoverage,
        @JsonProperty("semantic_signal_available") Boolean semanticSignalAvailable
    ) {}

    public record AiResponse(
        @JsonProperty("model_version") String modelVersion,
        @JsonProperty("selected_strategy") String selectedStrategy,
        @JsonProperty("destination_key") String destinationKey,
        @JsonProperty("selected_interest_codes") List<String> selectedInterestCodes,
        @JsonProperty("context_codes_received") List<String> contextCodesReceived,
        @JsonProperty("context_note") String contextNote,
        @JsonProperty("total_candidates") Integer totalCandidates,
        List<AiRecommendation> items
    ) {}
}
