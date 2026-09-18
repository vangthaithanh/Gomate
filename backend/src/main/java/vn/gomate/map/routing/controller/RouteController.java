package vn.gomate.map.routing.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.gomate.map.routing.dto.RouteComputeRequest;
import vn.gomate.map.routing.dto.RouteComputeResponse;
import vn.gomate.map.routing.dto.RouteDirectionsRequest;
import vn.gomate.map.routing.service.RouteService;

@RestController
@RequestMapping("/api/v1/routes")
public class RouteController {

    private final RouteService routeService;

    public RouteController(RouteService routeService) {
        this.routeService = routeService;
    }

    @PostMapping("/compute")
    public ResponseEntity<RouteComputeResponse> compute(
        @RequestBody RouteComputeRequest request
    ) {
        return ResponseEntity.ok(
            routeService.calculate(request.placeIds())
        );
    }

    @PostMapping("/directions")
    public ResponseEntity<RouteComputeResponse> directions(
        @RequestBody RouteDirectionsRequest request
    ) {
        return ResponseEntity.ok(
            routeService.calculateDirections(
                request.origin(),
                request.destinationPlaceId()
            )
        );
    }
}
