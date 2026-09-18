package vn.gomate.map.routing.service;

import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import vn.gomate.map.routing.dto.RouteComputeResponse;
import vn.gomate.map.routing.model.Coordinate;
import vn.gomate.map.routing.model.RouteResult;
import vn.gomate.map.routing.provider.RoutingProvider;

@Service
public class RouteService {

    private final DemoPlaceCatalog demoPlaceCatalog;
    private final RoutingProvider routingProvider;

    public RouteService(
        DemoPlaceCatalog demoPlaceCatalog,
        RoutingProvider routingProvider
    ) {
        this.demoPlaceCatalog = demoPlaceCatalog;
        this.routingProvider = routingProvider;
    }

    public RouteComputeResponse calculate(List<String> placeIds) {
        if (placeIds == null || placeIds.size() < 2) {
            throw new IllegalArgumentException(
                "Cần ít nhất 2 GoMate placeId."
            );
        }

        List<Coordinate> waypoints =
            demoPlaceCatalog.resolve(placeIds);

        RouteResult result =
            routingProvider.calculateRoute(waypoints);

        return new RouteComputeResponse(
            UUID.randomUUID().toString(),
            result.distanceMeters(),
            result.durationSeconds(),
            placeIds,
            result.geometry()
        );
    }

    public RouteComputeResponse calculateDirections(
        Coordinate origin,
        String destinationPlaceId
    ) {
        if (origin == null) {
            throw new IllegalArgumentException(
                "Thiếu điểm bắt đầu."
            );
        }

        if (
            destinationPlaceId == null
            || destinationPlaceId.isBlank()
        ) {
            throw new IllegalArgumentException(
                "Thiếu destinationPlaceId."
            );
        }

        Coordinate destination =
            demoPlaceCatalog.resolve(destinationPlaceId);

        RouteResult result =
            routingProvider.calculateRoute(
                List.of(origin, destination)
            );

        return new RouteComputeResponse(
            UUID.randomUUID().toString(),
            result.distanceMeters(),
            result.durationSeconds(),
            List.of(destinationPlaceId),
            result.geometry()
        );
    }
}
