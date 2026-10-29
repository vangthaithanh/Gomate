package vn.gomate.event.controller;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/health")
public class MongoHealthController {
    private final MongoTemplate mongo;
    private final String database;

    public MongoHealthController(MongoTemplate mongo, @Value("${spring.data.mongodb.database:gomate}") String database) {
        this.mongo = mongo;
        this.database = database;
    }

    @GetMapping("/mongo")
    public ResponseEntity<Map<String, Object>> health() {
        try {
            mongo.executeCommand("{ ping: 1 }");
            return ResponseEntity.ok(Map.of("status", "UP", "database", database));
        } catch (Exception error) {
            return ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("status", "DOWN", "database", database, "message", error.getMessage()));
        }
    }
}
