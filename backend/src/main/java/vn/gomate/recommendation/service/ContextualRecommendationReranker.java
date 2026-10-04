package vn.gomate.recommendation.service;

import java.math.BigDecimal;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class ContextualRecommendationReranker {
    private static final double EARTH_RADIUS_KM = 6371.0088;

    private final double semanticWeight;
    private final double contextWeight;
    private final double distanceScaleKm;

    public ContextualRecommendationReranker(
        @Value("${app.recommendation.semantic-weight:0.75}") double semanticWeight,
        @Value("${app.recommendation.context-weight:0.25}") double contextWeight,
        @Value("${app.recommendation.distance-scale-km:20}") double distanceScaleKm
    ) {
        double safeSemantic = Math.max(0.0, semanticWeight);
        double safeContext = Math.max(0.0, contextWeight);
        double total = safeSemantic + safeContext;
        if (total <= 0.0) {
            this.semanticWeight = 0.75;
            this.contextWeight = 0.25;
        } else {
            this.semanticWeight = safeSemantic / total;
            this.contextWeight = safeContext / total;
        }
        this.distanceScaleKm = Math.max(1.0, distanceScaleKm);
    }

    public List<Map<String, Object>> rerank(
        List<Map<String, Object>> items,
        List<String> contextCodes,
        Double currentLatitude,
        Double currentLongitude
    ) {
        if (items == null || items.isEmpty()) {
            return List.of();
        }
        Set<String> contexts = new HashSet<>(contextCodes == null ? List.of() : contextCodes);
        boolean useDistance = contexts.contains("GAN_TOI") && validCoordinate(currentLatitude, currentLongitude);
        boolean useReview = contexts.contains("CO_REVIEW");
        boolean usePopularity = contexts.contains("DANG_HOT");
        boolean useDayTrip = contexts.contains("DI_TRONG_NGAY") && validCoordinate(currentLatitude, currentLongitude);

        List<Map<String, Object>> ranked = new ArrayList<>();
        for (int index = 0; index < items.size(); index++) {
            Map<String, Object> item = new LinkedHashMap<>(items.get(index));
            double semanticScore = normalizeScore(number(item.get("score")));

            List<Double> contextComponents = new ArrayList<>();
            Double distanceKm = null;
            Double distanceScore = null;
            if ((useDistance || useDayTrip) && validCoordinate(item.get("latitude"), item.get("longitude"))) {
                distanceKm = haversineKm(
                    currentLatitude,
                    currentLongitude,
                    number(item.get("latitude")),
                    number(item.get("longitude"))
                );
                distanceScore = 1.0 / (1.0 + distanceKm / distanceScaleKm);
                if (useDistance) {
                    contextComponents.add(distanceScore);
                }
                if (useDayTrip) {
                    contextComponents.add(distanceScore);
                }
            }

            Double reviewScore = null;
            if (useReview) {
                reviewScore = reviewScore(item);
                contextComponents.add(reviewScore);
            }

            Double popularityScore = null;
            if (usePopularity) {
                popularityScore = popularityScore(item);
                contextComponents.add(popularityScore);
            }

            Double contextScore = contextComponents.isEmpty()
                ? null
                : contextComponents.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
            double finalScore = contextScore == null
                ? semanticScore
                : semanticWeight * semanticScore + contextWeight * contextScore;

            item.put("score", finalScore);
            item.put("recommendation", recommendationMeta(
                semanticScore,
                distanceKm,
                distanceScore,
                reviewScore,
                popularityScore,
                contextScore,
                finalScore,
                contexts
            ));
            item.put("_originalRank", index);
            ranked.add(item);
        }

        ranked.sort((left, right) -> {
            int scoreCompare = Double.compare(number(right.get("score")), number(left.get("score")));
            if (scoreCompare != 0) return scoreCompare;
            return Integer.compare(((Number) left.get("_originalRank")).intValue(), ((Number) right.get("_originalRank")).intValue());
        });
        for (Map<String, Object> item : ranked) {
            item.remove("_originalRank");
        }
        return ranked;
    }

    private Map<String, Object> recommendationMeta(
        double semanticScore,
        Double distanceKm,
        Double distanceScore,
        Double reviewScore,
        Double popularityScore,
        Double contextScore,
        double finalScore,
        Set<String> contexts
    ) {
        Map<String, Object> meta = new LinkedHashMap<>();
        meta.put("semanticScore", semanticScore);
        if (distanceKm != null) meta.put("distanceKm", round(distanceKm));
        if (distanceScore != null) meta.put("distanceScore", distanceScore);
        if (reviewScore != null) meta.put("reviewScore", reviewScore);
        if (popularityScore != null) meta.put("popularityScore", popularityScore);
        if (contextScore != null) meta.put("contextScore", contextScore);
        meta.put("finalScore", finalScore);
        meta.put("semanticWeight", semanticWeight);
        meta.put("contextWeight", contextWeight);
        meta.put("activeContextCodes", contexts.stream().sorted().toList());
        return meta;
    }

    private double reviewScore(Map<String, Object> item) {
        double ratingScore = clamp01(number(item.get("avgRating")) / 5.0);
        double reviewCount = Math.max(0.0, number(item.get("reviewCount")));
        double volumeScore = reviewCount / (reviewCount + 10.0);
        return clamp01(0.7 * ratingScore + 0.3 * volumeScore);
    }

    private double popularityScore(Map<String, Object> item) {
        double saveCount = Math.max(0.0, number(item.get("saveCount")));
        double reviewCount = Math.max(0.0, number(item.get("reviewCount")));
        double saveScore = saveCount / (saveCount + 20.0);
        double reviewScore = reviewCount / (reviewCount + 10.0);
        double ratingScore = clamp01(number(item.get("avgRating")) / 5.0);
        return clamp01(0.5 * saveScore + 0.3 * reviewScore + 0.2 * ratingScore);
    }

    private double normalizeScore(double value) {
        if (!Double.isFinite(value) || value <= 0.0) return 0.0;
        if (value <= 1.0) return value;
        return value / (value + 1.0);
    }

    private double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double rLat1 = Math.toRadians(lat1);
        double rLat2 = Math.toRadians(lat2);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(rLat1) * Math.cos(rLat2)
            * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return 2 * EARTH_RADIUS_KM * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private boolean validCoordinate(Object latitude, Object longitude) {
        if (latitude == null || longitude == null) return false;
        double lat = number(latitude);
        double lon = number(longitude);
        return Double.isFinite(lat)
            && Double.isFinite(lon)
            && lat >= -90.0
            && lat <= 90.0
            && lon >= -180.0
            && lon <= 180.0;
    }

    private double number(Object value) {
        if (value instanceof BigDecimal decimal) return decimal.doubleValue();
        if (value instanceof Number number) return number.doubleValue();
        if (value instanceof String text) {
            try {
                return Double.parseDouble(text);
            } catch (NumberFormatException ignored) {
                return 0.0;
            }
        }
        return 0.0;
    }

    private double clamp01(double value) {
        if (!Double.isFinite(value)) return 0.0;
        return Math.max(0.0, Math.min(1.0, value));
    }

    private double round(double value) {
        return Math.round(value * 100.0) / 100.0;
    }
}
