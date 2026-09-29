package vn.gomate;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.gomate.common.Db;
import vn.gomate.map.routing.model.Coordinate;
import vn.gomate.map.routing.model.RouteResult;
import vn.gomate.map.routing.provider.RoutingProvider;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class RouteApiTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired Db db;
    @MockitoBean RoutingProvider routingProvider;

    private long originId;
    private long destinationId;

    @BeforeEach
    void setup() {
        clearPlaces();
        reset(routingProvider);
        when(routingProvider.calculateRoute(anyList())).thenReturn(new RouteResult(
            9460.5,
            1234.0,
            List.of(
                List.of(108.4483, 11.9419),
                List.of(108.4369, 11.9037)
            )
        ));

        db.update("""
            INSERT INTO place_categories(code,name,active)
            VALUES('lake','Hồ và cảnh quan',TRUE)
            """, Map.of());

        long categoryId = ((Number) db.one(
            "SELECT id FROM place_categories WHERE code='lake'",
            Map.of()
        ).get("id")).longValue();

        originId = insertPlace(
            categoryId,
            "Hồ Xuân Hương",
            "Trung tâm thành phố Đà Lạt",
            11.9419,
            108.4483
        );
        destinationId = insertPlace(
            categoryId,
            "Thiền Viện Trúc Lâm",
            "Đường Trúc Lâm Yên Tử",
            11.9037,
            108.4369
        );
    }

    @AfterEach
    void cleanup() {
        clearPlaces();
    }

    @Test
    void directionsUsesRuntimeOriginAndPostgresDestination() throws Exception {
        mvc.perform(post("/api/v1/routes/directions")
                .contentType("application/json")
                .content(json.writeValueAsBytes(Map.of(
                    "originLatitude", 11.9500,
                    "originLongitude", 108.4500,
                    "destinationPlaceId", Long.toString(destinationId)
                ))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.distanceMeters").value(9460.5))
            .andExpect(jsonPath("$.durationSeconds").value(1234.0))
            .andExpect(jsonPath("$.orderedPlaceIds[0]").value("current-location"))
            .andExpect(jsonPath("$.orderedPlaceIds[1]").value(Long.toString(destinationId)))
            .andExpect(jsonPath("$.geometry.length()").value(2));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<Coordinate>> captor =
            ArgumentCaptor.forClass(List.class);
        verify(routingProvider).calculateRoute(captor.capture());
        List<Coordinate> coordinates = captor.getValue();
        assertEquals(2, coordinates.size());
        assertEquals(108.4500, coordinates.get(0).longitude(), 0.00001);
        assertEquals(11.9500, coordinates.get(0).latitude(), 0.00001);
        assertEquals(108.4369, coordinates.get(1).longitude(), 0.00001);
        assertEquals(11.9037, coordinates.get(1).latitude(), 0.00001);
    }

    @Test
    void directionsCanUseTwoPostgresPlaceIds() throws Exception {
        mvc.perform(post("/api/v1/routes/directions")
                .contentType("application/json")
                .content(json.writeValueAsBytes(Map.of(
                    "originPlaceId", Long.toString(originId),
                    "destinationPlaceId", Long.toString(destinationId)
                ))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.distanceMeters").value(9460.5))
            .andExpect(jsonPath("$.durationSeconds").value(1234.0))
            .andExpect(jsonPath("$.orderedPlaceIds[0]").value(Long.toString(originId)))
            .andExpect(jsonPath("$.orderedPlaceIds[1]").value(Long.toString(destinationId)))
            .andExpect(jsonPath("$.geometry.length()").value(2));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<Coordinate>> captor =
            ArgumentCaptor.forClass(List.class);
        verify(routingProvider).calculateRoute(captor.capture());
        List<Coordinate> coordinates = captor.getValue();
        assertEquals(2, coordinates.size());
        assertEquals(108.4483, coordinates.get(0).longitude(), 0.00001);
        assertEquals(11.9419, coordinates.get(0).latitude(), 0.00001);
        assertEquals(108.4369, coordinates.get(1).longitude(), 0.00001);
        assertEquals(11.9037, coordinates.get(1).latitude(), 0.00001);
    }

    @Test
    void invalidOriginAndDestinationAreControlled() throws Exception {
        mvc.perform(post("/api/v1/routes/directions")
                .contentType("application/json")
                .content(json.writeValueAsBytes(Map.of(
                    "originPlaceId", "999999",
                    "destinationPlaceId", Long.toString(destinationId)
                ))))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.code").value("PLACE_NOT_FOUND"));

        mvc.perform(post("/api/v1/routes/directions")
                .contentType("application/json")
                .content(json.writeValueAsBytes(Map.of(
                    "originPlaceId", Long.toString(originId),
                    "destinationPlaceId", "not-a-place-id"
                ))))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("INVALID_INPUT"));

        verifyNoInteractions(routingProvider);
    }

    @Test
    void missingOriginIsControlled() throws Exception {
        mvc.perform(post("/api/v1/routes/directions")
                .contentType("application/json")
                .content(json.writeValueAsBytes(Map.of(
                    "destinationPlaceId", Long.toString(destinationId)
                ))))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("INVALID_INPUT"));

        verifyNoInteractions(routingProvider);
    }

    @Test
    void providerFailureIsControlled() throws Exception {
        when(routingProvider.calculateRoute(anyList()))
            .thenThrow(new IllegalStateException("Mapbox down"));

        mvc.perform(post("/api/v1/routes/directions")
                .contentType("application/json")
                .content(json.writeValueAsBytes(Map.of(
                    "originPlaceId", Long.toString(originId),
                    "destinationPlaceId", Long.toString(destinationId)
                ))))
            .andExpect(status().isServiceUnavailable())
            .andExpect(jsonPath("$.code").value("ROUTE_PROVIDER_UNAVAILABLE"));
    }

    private long insertPlace(
        long categoryId,
        String name,
        String address,
        double latitude,
        double longitude
    ) {
        db.update("""
            INSERT INTO places(
                category_id,name,description,province,district,address,
                latitude,longitude,source_type,status
            )
            VALUES(
                :categoryId,:name,:description,'Lâm Đồng','Đà Lạt',:address,
                :latitude,:longitude,'ADMIN','ACTIVE'
            )
            """, args(
                "categoryId", categoryId,
                "name", name,
                "description", name,
                "address", address,
                "latitude", latitude,
                "longitude", longitude
            ));

        return ((Number) db.one(
            "SELECT id FROM places WHERE name=:name",
            args("name", name)
        ).get("id")).longValue();
    }

    private void clearPlaces() {
        db.update("DELETE FROM place_media", Map.of());
        db.update("DELETE FROM places", Map.of());
        db.update("DELETE FROM place_categories", Map.of());
    }
}
