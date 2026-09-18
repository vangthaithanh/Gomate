package vn.gomate.map.routing.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;
import vn.gomate.map.routing.model.Coordinate;

/// DATA CỨNG CHỈ DÙNG ĐỂ TEST ROUTING.
///
/// Production:
/// thay class này bằng PlaceRepository/JPA query PostgreSQL places.id
/// để resolve placeId -> longitude/latitude.
@Component
public class DemoPlaceCatalog {

    private final Map<String, Coordinate> places =
        new LinkedHashMap<>();

    public DemoPlaceCatalog() {
        places.put(
            "place-101",
            new Coordinate(108.4488, 11.9416)
        );
        places.put(
            "place-102",
            new Coordinate(108.4453, 11.9367)
        );
        places.put(
            "place-103",
            new Coordinate(108.4376, 11.9439)
        );
        places.put(
            "place-104",
            new Coordinate(108.4499, 11.9514)
        );
        places.put(
            "place-105",
            new Coordinate(108.4387, 11.9445)
        );
        places.put(
            "place-106",
            new Coordinate(108.4432, 11.9389)
        );
        places.put(
            "place-107",
            new Coordinate(108.4548, 11.9419)
        );
        places.put(
            "place-108",
            new Coordinate(108.4298, 11.9302)
        );
    }

    public Coordinate resolve(String placeId) {
        Coordinate coordinate = places.get(placeId);

        if (coordinate == null) {
            throw new IllegalArgumentException(
                "Không tìm thấy GoMate placeId: " + placeId
            );
        }

        return coordinate;
    }

    public List<Coordinate> resolve(List<String> placeIds) {
        return placeIds.stream()
            .map(this::resolve)
            .toList();
    }
}
