package vn.gomate.map.routing.dto;

import java.util.List;

public record RouteComputeRequest(
    List<String> placeIds
) {}
