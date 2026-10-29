package vn.gomate.map.routing.provider;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import vn.gomate.map.routing.model.Coordinate;
import vn.gomate.map.routing.model.RouteResult;

@Component
public class MapboxRoutingProvider implements RoutingProvider {

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String accessToken;

    public MapboxRoutingProvider(
        ObjectMapper objectMapper,
        @Value("${MAPBOX_SERVER_TOKEN:}") String accessToken
    ) {
        this.objectMapper = objectMapper;
        this.accessToken = accessToken;
        this.httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();
    }

    @Override
    public RouteResult calculateRoute(List<Coordinate> waypoints) {
        if (waypoints == null || waypoints.size() < 2) {
            throw new IllegalArgumentException(
                "Route cần ít nhất 2 waypoint."
            );
        }

        if (waypoints.size() > 25) {
            throw new IllegalArgumentException(
                "Mapbox Directions hỗ trợ tối đa 25 waypoint."
            );
        }

        if (accessToken == null || accessToken.isBlank()) {
            throw new IllegalStateException(
                "Thiếu MAPBOX_SERVER_TOKEN ở backend."
            );
        }

        try {
            String coordinates = waypoints.stream()
                .map(p -> p.longitude() + "," + p.latitude())
                .collect(Collectors.joining(";"));

            String token = URLEncoder.encode(
                accessToken,
                StandardCharsets.UTF_8
            );

            String url =
                "https://api.mapbox.com/directions/v5/mapbox/driving/"
                + coordinates
                + "?geometries=geojson"
                + "&overview=full"
                + "&steps=false"
                + "&access_token="
                + token;

            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(20))
                .header("Accept", "application/json")
                .GET()
                .build();

            HttpResponse<String> response = httpClient.send(
                request,
                HttpResponse.BodyHandlers.ofString()
            );

            if (response.statusCode() != 200) {
                throw new IllegalStateException(
                    "Mapbox Directions HTTP "
                    + response.statusCode()
                    + ": "
                    + response.body()
                );
            }

            JsonNode root = objectMapper.readTree(response.body());

            if (!"Ok".equals(root.path("code").asText())) {
                throw new IllegalStateException(
                    "Mapbox Directions lỗi: "
                    + root.path("message").asText(root.path("code").asText())
                );
            }

            JsonNode route = root.path("routes").path(0);
            if (route.isMissingNode()) {
                throw new IllegalStateException(
                    "Mapbox Directions không trả route."
                );
            }

            List<List<Double>> geometry = new ArrayList<>();
            for (JsonNode pair :
                route.path("geometry").path("coordinates")) {

                geometry.add(List.of(
                    pair.path(0).asDouble(),
                    pair.path(1).asDouble()
                ));
            }

            return new RouteResult(
                route.path("distance").asDouble(),
                route.path("duration").asDouble(),
                geometry
            );
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(
                "Mapbox Directions bị interrupt.",
                e
            );
        } catch (Exception e) {
            throw new IllegalStateException(
                "Không tính được route bằng Mapbox Directions.",
                e
            );
        }
    }
}
