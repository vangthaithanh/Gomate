package vn.gomate.recommendation.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
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
    private final ObjectMapper mapper;

    public RecommendationService(
        AuthRepository auth,
        AiRecommendationClient ai,
        RecommendationPlaceRepository places,
        ObjectMapper mapper
    ) {
        this.auth = auth;
        this.ai = ai;
        this.places = places;
        this.mapper = mapper;
    }

    public Map<String, Object> mine(UUID userId, Double latitude, Double longitude, int topK) {
        int limit = Math.max(1, Math.min(topK, 50));
        Map<String, Object> profile = auth.profile(userId);
        List<String> optionCodes = readOptionCodes(profile.get("interestCodes"));

        RecommendationDtos.AiResponse response = ai.coldStart(
            optionCodes,
            latitude,
            longitude,
            limit
        );

        List<RecommendationDtos.AiRecommendation> aiItems = response.recommendations() == null
            ? List.of()
            : response.recommendations();
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
                items.add(toAiOnlyItem(recommendation));
                continue;
            }
            items.add(toItem(row, recommendation));
        }

        List<String> warnings = new ArrayList<>();
        if (response.warnings() != null) warnings.addAll(response.warnings());
        if (!missing.isEmpty()) {
            warnings.add("Một số externalId của AI chưa có trong PostgreSQL: " + missing);
        }
        fillWithPopularPlaces(items, warnings, limit);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("modelVersion", response.modelVersion());
        result.put("coldStart", response.coldStart());
        result.put("optionCodes", optionCodes);
        result.put("scoringMode", response.scoringMode());
        result.put("items", items);
        result.put("warnings", warnings);
        return result;
    }

    private void fillWithPopularPlaces(
        List<Map<String, Object>> items,
        List<String> warnings,
        int limit
    ) {
        if (items.size() >= limit) return;

        Set<Object> usedPlaceIds = new HashSet<>();
        for (Map<String, Object> item : items) {
            Object placeId = item.get("placeId");
            if (placeId != null) usedPlaceIds.add(placeId);
        }

        int before = items.size();
        for (Map<String, Object> row : places.findPopularActive(Math.max(limit * 2, limit + 5))) {
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

        if (items.size() > before) {
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
            recommendation == null ? row.get("score") : recommendation.score()
        );
        item.put(
            "reason",
            recommendation == null
                ? "Địa điểm đang hot, nhiều lượt lưu/đánh giá nên được dùng làm gợi ý fallback."
                : recommendation.reason()
        );
        item.put(
            "modelSource",
            recommendation == null
                ? "postgres_popular_fallback"
                : recommendation.modelSource()
        );
        return item;
    }

    private Map<String, Object> toAiOnlyItem(
        RecommendationDtos.AiRecommendation recommendation
    ) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("placeId", 0);
        item.put("externalId", recommendation.externalId());
        item.put(
            "name",
            recommendation.name() == null || recommendation.name().isBlank()
                ? "Địa điểm gợi ý"
                : recommendation.name()
        );
        item.put("description", null);
        item.put("category", recommendation.category());
        item.put("categoryName", recommendation.category());
        item.put("province", null);
        item.put("district", null);
        item.put("address", null);
        item.put("latitude", recommendation.latitude());
        item.put("longitude", recommendation.longitude());
        item.put("avgRating", 0);
        item.put("reviewCount", 0);
        item.put("saveCount", 0);
        item.put("thumbnailUrl", null);
        item.put("destinationKey", recommendation.destinationKey());
        item.put("score", recommendation.score());
        item.put(
            "reason",
            recommendation.reason() == null || recommendation.reason().isBlank()
                ? "Được đề xuất trực tiếp từ model KPDL v11."
                : recommendation.reason()
        );
        item.put(
            "modelSource",
            recommendation.modelSource() == null || recommendation.modelSource().isBlank()
                ? "ai_catalog_unmapped"
                : recommendation.modelSource()
        );
        return item;
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
}
