package vn.gomate.map.routing.service;

import org.springframework.stereotype.Component;
import vn.gomate.common.ApiException;
import vn.gomate.map.routing.model.Coordinate;
import vn.gomate.place.repository.PlaceRepository;

@Component
public class PlaceCoordinateResolver {

    private final PlaceRepository placeRepository;

    public PlaceCoordinateResolver(PlaceRepository placeRepository) {
        this.placeRepository = placeRepository;
    }

    public Coordinate resolve(String placeId, String fieldName) {
        long numericId = parsePlaceId(placeId, fieldName);

        Coordinate coordinate = placeRepository.activeCoordinate(numericId)
            .orElseThrow(() -> new ApiException(
                404,
                "PLACE_NOT_FOUND",
                "Không tìm thấy địa điểm " + fieldName + ": " + placeId
            ));

        if (
            !Double.isFinite(coordinate.latitude())
            || !Double.isFinite(coordinate.longitude())
        ) {
            throw new ApiException(
                422,
                "PLACE_COORDINATE_INVALID",
                "Địa điểm " + fieldName + " chưa có tọa độ hợp lệ."
            );
        }

        return coordinate;
    }

    private long parsePlaceId(String placeId, String fieldName) {
        if (placeId == null || placeId.isBlank()) {
            throw ApiException.bad("Thiếu " + fieldName + ".");
        }

        try {
            long parsed = Long.parseLong(placeId.trim());
            if (parsed <= 0) {
                throw ApiException.bad(fieldName + " phải là places.id hợp lệ.");
            }
            return parsed;
        } catch (NumberFormatException e) {
            throw ApiException.bad(fieldName + " phải là places.id hợp lệ.");
        }
    }
}
