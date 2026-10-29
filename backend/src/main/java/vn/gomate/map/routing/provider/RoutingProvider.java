package vn.gomate.map.routing.provider;

import java.util.List;
import vn.gomate.map.routing.model.Coordinate;
import vn.gomate.map.routing.model.RouteResult;

public interface RoutingProvider {
    RouteResult calculateRoute(List<Coordinate> waypoints);
}
