package vn.gomate.map.routing.service;

import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;
import vn.gomate.map.routing.dto.RouteComputeResponse;
import vn.gomate.map.routing.model.Coordinate;
import vn.gomate.map.routing.model.RouteResult;
import vn.gomate.map.routing.provider.RoutingProvider;

@Service
public class RouteService {

    private final PlaceCoordinateResolver coordinateResolver;
    private final RoutingProvider routingProvider;

    public RouteService(
        PlaceCoordinateResolver coordinateResolver,
        RoutingProvider routingProvider
    ) {
        this.coordinateResolver = coordinateResolver;
        this.routingProvider = routingProvider;
    }

    public RouteComputeResponse calculate(List<String> placeIds) {
        if (placeIds == null || placeIds.size() < 2) {
            throw ApiException.bad(
                "Cần ít nhất 2 GoMate placeId."
            );
        }

        List<Coordinate> waypoints =
            placeIds.stream()
                .map(id -> coordinateResolver.resolve(id, "placeIds"))
                .toList();

        RouteResult result = calculateWithProvider(waypoints);

        return new RouteComputeResponse(
            UUID.randomUUID().toString(),
            result.distanceMeters(),
            result.durationSeconds(),
            placeIds,
            result.geometry()
        );
    }

    public RouteComputeResponse calculateDirections(
        String originPlaceId,
        Double originLatitude,
        Double originLongitude,
        String destinationPlaceId
    ) {
        if (originPlaceId != null
            && destinationPlaceId != null
            && originPlaceId.trim().equals(destinationPlaceId.trim())) {
            throw ApiException.bad(
                "Điểm bắt đầu và điểm đến phải là hai địa điểm khác nhau."
            );
        }

        Coordinate origin = resolveDirectionsOrigin(
            originPlaceId,
            originLatitude,
            originLongitude
        );
        Coordinate destination =
            coordinateResolver.resolve(destinationPlaceId, "destinationPlaceId");

        RouteResult result = calculateWithProvider(List.of(origin, destination));

        return new RouteComputeResponse(
            UUID.randomUUID().toString(),
            result.distanceMeters(),
            result.durationSeconds(),
            List.of(
                originPlaceId == null || originPlaceId.isBlank()
                    ? "current-location"
                    : originPlaceId,
                destinationPlaceId
            ),
            result.geometry()
        );
    }

    private Coordinate resolveDirectionsOrigin(
        String originPlaceId,
        Double originLatitude,
        Double originLongitude
    ) {
        if (originPlaceId != null && !originPlaceId.isBlank()) {
            return coordinateResolver.resolve(originPlaceId, "originPlaceId");
        }

        if (originLatitude == null || originLongitude == null) {
            throw ApiException.bad(
                "Cần originPlaceId hoặc originLatitude/originLongitude."
            );
        }

        if (!Double.isFinite(originLatitude)
            || !Double.isFinite(originLongitude)
            || originLatitude < -90
            || originLatitude > 90
            || originLongitude < -180
            || originLongitude > 180) {
            throw ApiException.bad(
                "originLatitude/originLongitude không hợp lệ."
            );
        }

        return new Coordinate(originLongitude, originLatitude);
    }

    private RouteResult calculateWithProvider(List<Coordinate> waypoints) {
        try {
            return routingProvider.calculateRoute(waypoints);
        } catch (ApiException e) {
            throw e;
        } catch (RuntimeException e) {
            throw new ApiException(
                503,
                "ROUTE_PROVIDER_UNAVAILABLE",
                "Không tính được chỉ đường bằng Mapbox Directions. Vui lòng thử lại sau.",
                e
            );
        }
    }
}
