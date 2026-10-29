package vn.gomate.map.routing.model;

import java.util.List;

public record RouteResult(
    double distanceMeters,
    double durationSeconds,
    List<List<Double>> geometry
) {}
