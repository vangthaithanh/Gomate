package vn.gomate.map.routing.dto;

public record RouteDirectionsRequest(
    String originPlaceId,
    Double originLatitude,
    Double originLongitude,
    String destinationPlaceId
) {}
