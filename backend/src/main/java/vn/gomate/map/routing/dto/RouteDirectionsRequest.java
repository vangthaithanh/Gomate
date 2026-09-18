package vn.gomate.map.routing.dto;

import vn.gomate.map.routing.model.Coordinate;

public record RouteDirectionsRequest(
    Coordinate origin,
    String destinationPlaceId
) {}
