package vn.gomate.map.routing.dto;

import java.util.List;

public record RouteComputeRequest(
    Double originLatitude,
    Double originLongitude,
    List<String> placeIds
) {}
