package vn.gomate.map.routing.dto;

import java.util.List;

public record RouteComputeResponse(
    String routeId,
    double distanceMeters,
    double durationSeconds,
    List<String> orderedPlaceIds,
    List<List<Double>> geometry
) {}
