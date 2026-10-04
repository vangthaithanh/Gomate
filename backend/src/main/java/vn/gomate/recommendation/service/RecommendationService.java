package vn.gomate.recommendation.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import vn.gomate.auth.AuthRepository;
import vn.gomate.common.ApiException;
import vn.gomate.recommendation.client.AiRecommendationClient;
import vn.gomate.recommendation.dto.RecommendationDtos;
import vn.gomate.recommendation.repository.RecommendationPlaceRepository;

@Service
public class RecommendationService {
    private final AuthRepository auth;
    private final AiRecommendationClient ai;
    private final RecommendationPlaceRepository places;
    private final ContextualRecommendationReranker reranker;
    private final ObjectMapper mapper;
    private final int candidateK;
    private final int homeLimit;

    public RecommendationService(
        AuthRepository auth,
        AiRecommendationClient ai,
        RecommendationPlaceRepository places,
        ContextualRecommendationReranker reranker,
        ObjectMapper mapper,
        @Value("${app.ai.recommendation-candidate-k:50}") int candidateK,
        @Value("${app.ai.recommendation-home-limit:10}") int homeLimit
    ) {
        this.auth = auth;
        this.ai = ai;
        this.places = places;
        this.reranker = reranker;
        this.mapper = mapper;
        this.candidateK = Math.max(1, Math.min(candidateK, 100));
        this.homeLimit = Math.max(1, Math.min(homeLimit, 50));
    }

    public Map<String, Object> mine(
        UUID userId,
        String destinationKey,
        Double latitude,
        Double longitude,
        Integer topK
    ) {
        int limit = topK == null || topK <= 0 ? homeLimit : Math.max(1, Math.min(topK, 50));
        String effectiveDestination = normalizeDestination(destinationKey);
        Map<String, Object> profile = auth.profile(userId);
        List<String> allOptionCodes = readOptionCodes(profile.get("interestCodes"));
        List<String> semanticInterestCodes = places.findSemanticInterestCodes(userId);
        if (semanticInterestCodes.isEmpty()) {
            List<String> contextCodes = places.filterContextCodes(allOptionCodes);
            semanticInterestCodes = allOptionCodes.stream()
                .filter(code -> !contextCodes.contains(code))
                .distinct()
                .toList();
        }
        List<String> contextCodes = places.filterContextCodes(allOptionCodes);

        if (semanticInterestCodes.isEmpty()) {
            return fallbackOnly(
                effectiveDestination,
                semanticInterestCodes,
                contextCodes,
                limit,
                latitude,
                longitude,
                "Người dùng chưa có lựa chọn semantic từ khảo sát; dùng fallback PostgreSQL."
            );
        }

        RecommendationDtos.AiResponse response;
        try {
            response = ai.coldStart(
                effectiveDestination,
                semanticInterestCodes,
                contextCodes,
                Math.max(candidateK, limit)
            );
        } catch (ApiException error) {
            return fallbackOnly(
                effectiveDestination,
                semanticInterestCodes,
                contextCodes,
                limit,
                latitude,
                longitude,
                error.getMessage()
            );
        }

        List<RecommendationDtos.AiRecommendation> aiItems = response.items() == null
            ? List.of()
            : response.items();
        List<String> externalIds = aiItems.stream()
            .map(RecommendationDtos.AiRecommendation::externalId)
            .filter(Objects::nonNull)
            .distinct()
            .toList();

        Map<String, Map<String, Object>> dbByExternalId = new HashMap<>();
        for (Map<String, Object> row : places.findActiveByExternalIds(externalIds)) {
            Object externalId = row.get("externalId");
            if (externalId != null) {
                dbByExternalId.put(externalId.toString(), row);
            }
        }

        List<Map<String, Object>> items = new ArrayList<>();
        List<String> missing = new ArrayList<>();
        for (RecommendationDtos.AiRecommendation recommendation : aiItems) {
            String externalId = recommendation.externalId();
            if (externalId == null || externalId.isBlank()) {
                missing.add("(AI item thiếu externalId)");
                continue;
            }
            Map<String, Object> row = dbByExternalId.get(externalId);
            if (row == null) {
                missing.add(externalId);
                continue;
            }
            items.add(toItem(row, recommendation));
            if (items.size() >= limit) {
                break;
            }
        }

        List<String> warnings = new ArrayList<>();
        if (response.contextNote() != null && !response.contextNote().isBlank()) {
            warnings.add(response.contextNote());
        }
        addContextWarnings(contextCodes, latitude, longitude, warnings);
        if (!missing.isEmpty()) {
            warnings.add("Một số externalId của AI chưa có trong PostgreSQL: " + missing);
        }
        fillWithPopularPlaces(items, warnings, effectiveDestination, Math.max(candidateK, limit));
        items = new ArrayList<>(reranker.rerank(items, contextCodes, latitude, longitude));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("modelVersion", response.modelVersion());
        result.put("coldStart", true);
        result.put("destinationKey", effectiveDestination);
        result.put("optionCodes", semanticInterestCodes);
        result.put("contextCodes", contextCodes);
        result.put("scoringMode", response.selectedStrategy());
        result.put("totalCandidates", response.totalCandidates());
        result.put("items", items.stream().limit(limit).toList());
        result.put("warnings", warnings);
        return result;
    }

    private Map<String, Object> fallbackOnly(
        String destinationKey,
        List<String> semanticInterestCodes,
        List<String> contextCodes,
        int limit,
        Double latitude,
        Double longitude,
        String warning
    ) {
        List<Map<String, Object>> items = new ArrayList<>();
        List<String> warnings = new ArrayList<>();
        warnings.add(warning);
        addContextWarnings(contextCodes, latitude, longitude, warnings);
        fillWithPopularPlaces(items, warnings, destinationKey, Math.max(candidateK, limit));
        items = new ArrayList<>(reranker.rerank(items, contextCodes, latitude, longitude));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("modelVersion", "postgres-popular-fallback");
        result.put("coldStart", true);
        result.put("destinationKey", destinationKey);
        result.put("optionCodes", semanticInterestCodes);
        result.put("contextCodes", contextCodes);
        result.put("scoringMode", "fallback");
        result.put("totalCandidates", items.size());
        result.put("items", items.stream().limit(limit).toList());
        result.put("warnings", warnings);
        return result;
    }

    private void addContextWarnings(
        List<String> contextCodes,
        Double latitude,
        Double longitude,
        List<String> warnings
    ) {
        if (contextCodes == null || !contextCodes.contains("GAN_TOI")) {
            return;
        }
        if (!validCoordinate(latitude, longitude)) {
            warnings.add("Người dùng chọn GAN_TOI nhưng Home không có GPS hợp lệ; giữ ranking semantic, không boost khoảng cách.");
        }
    }

    private boolean validCoordinate(Double latitude, Double longitude) {
        return latitude != null
            && longitude != null
            && Double.isFinite(latitude)
            && Double.isFinite(longitude)
            && latitude >= -90.0
            && latitude <= 90.0
            && longitude >= -180.0
            && longitude <= 180.0;
    }

    private void fillWithPopularPlaces(
        List<Map<String, Object>> items,
        List<String> warnings,
        String destinationKey,
        int limit
    ) {
        if (items.size() >= limit) return;

        Set<Object> usedPlaceIds = new HashSet<>();
        for (Map<String, Object> item : items) {
            Object placeId = item.get("placeId");
            if (placeId != null) usedPlaceIds.add(placeId);
        }

        int before = items.size();
        List<Map<String, Object>> fallbackRows = places.findPopularActiveByDestination(
            destinationKey,
            Math.max(limit * 2, limit + 5)
        );
        if (fallbackRows.isEmpty()) {
            fallbackRows = places.findPopularActive(Math.max(limit * 2, limit + 5));
        }
        for (Map<String, Object> row : fallbackRows) {
            Object placeId = row.get("placeId");
            if (placeId != null && usedPlaceIds.contains(placeId)) {
                continue;
            }
            items.add(toItem(row, null));
            if (placeId != null) usedPlaceIds.add(placeId);
            if (items.size() >= limit) {
                break;
            }
        }

        if (before == 0 && items.size() > before) {
            warnings.add("Đã bù thêm địa điểm hot/nhiều tương tác từ PostgreSQL để không trả danh sách rỗng.");
        }
    }

    private Map<String, Object> toItem(
        Map<String, Object> row,
        RecommendationDtos.AiRecommendation recommendation
    ) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("placeId", row.get("placeId"));
        item.put("externalId", row.get("externalId"));
        item.put("name", row.get("name"));
        item.put("description", row.get("description"));
        item.put("category", row.get("category"));
        item.put("categoryName", row.get("categoryName"));
        item.put("province", row.get("province"));
        item.put("district", row.get("district"));
        item.put("address", row.get("address"));
        item.put("latitude", row.get("latitude"));
        item.put("longitude", row.get("longitude"));
        item.put("avgRating", row.get("avgRating"));
        item.put("reviewCount", row.get("reviewCount"));
        item.put("saveCount", row.get("saveCount"));
        item.put("thumbnailUrl", row.get("thumbnailUrl"));
        item.put(
            "destinationKey",
            recommendation == null ? null : recommendation.destinationKey()
        );
        item.put(
            "score",
            recommendation == null ? row.get("score") : recommendation.semanticScore()
        );
        item.put(
            "reason",
            recommendation == null
                ? "Địa điểm đang hot, nhiều lượt lưu/đánh giá nên được dùng làm gợi ý fallback."
                : aiReason(recommendation)
        );
        item.put(
            "modelSource",
            recommendation == null
                ? "postgres_popular_fallback"
                : "ai_semantic_v1"
        );
        return item;
    }

    private String aiReason(
        RecommendationDtos.AiRecommendation recommendation
    ) {
        if (recommendation.semanticStatus() == null || recommendation.semanticStatus().isBlank()) {
            return "Phù hợp với nhóm sở thích bạn đã chọn trong khảo sát.";
        }
        return "Phù hợp semantic-v1 (" + recommendation.semanticStatus() + "), điểm "
            + String.format(Locale.ROOT, "%.2f", recommendation.semanticScore() == null ? 0.0 : recommendation.semanticScore())
            + ".";
    }

    private List<String> readOptionCodes(Object value) {
        if (value == null) return List.of();
        if (value instanceof Collection<?> collection) {
            return collection.stream().map(Object::toString).toList();
        }
        if (!(value instanceof String text) || text.isBlank()) return List.of();
        try {
            return mapper.readValue(text, new TypeReference<List<String>>() {});
        } catch (Exception error) {
            throw new ApiException(500, "INVALID_INTEREST_CODES", "Dữ liệu khảo sát của người dùng không hợp lệ.", error);
        }
    }

    private String normalizeDestination(String destinationKey) {
        if (destinationKey == null || destinationKey.isBlank()) {
            return null;
        }
        return destinationKey.trim();
    }
}
