package vn.gomate.place.seed;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.math.BigDecimal;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;
import vn.gomate.media.dto.MediaUploadResult;
import vn.gomate.media.model.MediaResourceType;
import vn.gomate.media.service.FetchedRemoteImage;
import vn.gomate.media.service.MediaService;
import vn.gomate.media.service.RemoteImageFetcher;
import vn.gomate.place.repository.PlaceRepository;

@Service
@ConditionalOnProperty(name = "app.place.seed.enabled", havingValue = "true")
public class PlaceSeedImporter {
    private static final Logger log = LoggerFactory.getLogger(PlaceSeedImporter.class);
    private final PlaceRepository places;
    private final MediaService media;
    private final RemoteImageFetcher imageFetcher;

    public PlaceSeedImporter(PlaceRepository places, MediaService media, RemoteImageFetcher imageFetcher) {
        this.places = places;
        this.media = media;
        this.imageFetcher = imageFetcher;
    }

    public ImportSummary importSeed(Resource resource, int limit, String folderPrefix, int retryAttempts, long retryDelayMillis) {
        List<SeedPlace> rows = read(resource, limit);
        int placesUpserted = 0;
        int mediaCreated = 0;
        int mediaSkipped = 0;
        int mediaFailed = 0;
        for (SeedPlace row : rows) {
            long categoryId = places.upsertCategory(row.categoryCode(), row.categoryName(), row.categoryDescription());
            long placeId = places.upsertImportedPlace(row.toImportedPlace(), categoryId);
            placesUpserted++;

            if (row.imageSourceUrl() == null || row.imageSourceUrl().isBlank()) {
                mediaSkipped++;
                log.info("Place seed has no reviewed image source, skipping media upload: placeId={} externalId={}", placeId, row.externalId());
                continue;
            }

            String folder = trimSlash(folderPrefix) + "/" + placeId;
            String assetName = "cover-v11";
            String expectedPublicId = folder + "/" + assetName;
            if (places.imageMediaExistsForPlace(placeId)) {
                mediaSkipped++;
                log.info("Place seed image cover already exists: placeId={} externalId={}", placeId, row.externalId());
                continue;
            }
            if (places.mediaExists(expectedPublicId)) {
                mediaSkipped++;
                log.info("Place seed media already exists: placeId={} publicId={}", placeId, expectedPublicId);
                continue;
            }

            try {
                MediaUploadResult uploaded = uploadWithRetry(row, folder, assetName, Math.max(1, retryAttempts), Math.max(0, retryDelayMillis));
                if (uploaded.secureUrl() == null || uploaded.publicId() == null) {
                    throw new ApiException(503, "MEDIA_UPLOAD_FAILED", "Cloudinary không trả đủ secure_url/public_id.");
                }
                try {
                    places.insertPlaceMedia(placeId, uploaded, row.imageCaption(), 0);
                    mediaCreated++;
                    log.info("Imported place media: placeId={} publicId={}", placeId, uploaded.publicId());
                } catch (RuntimeException dbError) {
                    cleanup(uploaded.publicId());
                    throw dbError;
                }
            } catch (ApiException uploadError) {
                mediaFailed++;
                Throwable cause = uploadError.getCause();
                log.warn("Place seed media upload failed: place='{}' code={} message={} cause={} causeMessage={}",
                    row.name(),
                    uploadError.code,
                    uploadError.getMessage(),
                    cause == null ? "" : cause.getClass().getSimpleName(),
                    cause == null ? "" : cause.getMessage());
            }
        }
        return new ImportSummary(rows.size(), placesUpserted, mediaCreated, mediaSkipped, mediaFailed);
    }

    private MediaUploadResult uploadWithRetry(SeedPlace row, String folder, String assetName, int retryAttempts, long retryDelayMillis) {
        FetchedRemoteImage fetched = imageFetcher.fetch(row.imageSourceUrl(), retryAttempts, retryDelayMillis);
        ApiException lastError = null;
        for (int attempt = 1; attempt <= retryAttempts; attempt++) {
            try {
                return media.uploadImageBytes(fetched.bytes(), folder, assetName, fetched.contentType());
            } catch (ApiException uploadError) {
                lastError = uploadError;
                if (attempt >= retryAttempts) break;
                Throwable cause = uploadError.getCause();
                log.warn("Place seed media upload retry scheduled: place='{}' attempt={}/{} delayMs={} causeMessage={}",
                    row.name(),
                    attempt,
                    retryAttempts,
                    retryDelayMillis,
                    cause == null ? uploadError.getMessage() : cause.getMessage());
                sleep(retryDelayMillis);
            }
        }
        throw lastError;
    }

    private static void sleep(long retryDelayMillis) {
        if (retryDelayMillis <= 0) return;
        try {
            Thread.sleep(retryDelayMillis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ApiException(503, "MEDIA_UPLOAD_INTERRUPTED", "Import media bị gián đoạn khi chờ retry.", e);
        }
    }

    private void cleanup(String publicId) {
        try {
            media.delete(publicId, MediaResourceType.IMAGE);
            log.warn("Cleaned up Cloudinary asset after DB media insert failure: publicId={}", publicId);
        } catch (RuntimeException cleanupError) {
            log.warn("Cloudinary cleanup failed after DB media insert failure: publicId={}", publicId, cleanupError);
        }
    }

    private static List<SeedPlace> read(Resource resource, int limit) {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8))) {
            String headerLine = reader.readLine();
            if (headerLine == null) return List.of();
            List<String> header = csv(headerLine);
            Map<String, Integer> columns = new HashMap<>();
            for (int i = 0; i < header.size(); i++) columns.put(header.get(i), i);

            List<SeedPlace> result = new ArrayList<>();
            String line;
            while ((line = reader.readLine()) != null && result.size() < limit) {
                if (line.isBlank()) continue;
                result.add(SeedPlace.from(csv(line), columns));
            }
            return result;
        } catch (IOException e) {
            throw new IllegalStateException("Không đọc được seed Place: " + resource, e);
        }
    }

    private static List<String> csv(String line) {
        List<String> values = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean quoted = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (c == '"') {
                if (quoted && i + 1 < line.length() && line.charAt(i + 1) == '"') {
                    current.append('"');
                    i++;
                } else {
                    quoted = !quoted;
                }
            } else if (c == ',' && !quoted) {
                values.add(current.toString());
                current.setLength(0);
            } else {
                current.append(c);
            }
        }
        values.add(current.toString());
        return values;
    }

    private static String trimSlash(String value) {
        String result = value == null || value.isBlank() ? "gomate/dev/places" : value.trim();
        while (result.endsWith("/")) result = result.substring(0, result.length() - 1);
        return result;
    }

    public record ImportSummary(int seedRows, int placesUpserted, int mediaCreated, int mediaSkipped, int mediaFailed) {}

    record SeedPlace(
        String name,
        String categoryCode,
        String categoryName,
        String categoryDescription,
        String description,
        String province,
        String district,
        String address,
        BigDecimal latitude,
        BigDecimal longitude,
        String sourceType,
        String externalSource,
        String externalId,
        String imageSourceUrl,
        String imageCaption
    ) {
        static SeedPlace from(List<String> row, Map<String, Integer> columns) {
            SeedPlace place = new SeedPlace(
                required(row, columns, "name"),
                required(row, columns, "category_code"),
                required(row, columns, "category_name"),
                optional(row, columns, "category_description"),
                optional(row, columns, "description"),
                required(row, columns, "province"),
                optional(row, columns, "district"),
                optional(row, columns, "address"),
                decimal(required(row, columns, "latitude"), "latitude"),
                decimal(required(row, columns, "longitude"), "longitude"),
                required(row, columns, "source_type"),
                required(row, columns, "external_source"),
                required(row, columns, "external_id"),
                optional(row, columns, "image_source_url"),
                optional(row, columns, "image_caption")
            );
            place.validate();
            return place;
        }

        PlaceRepository.ImportedPlace toImportedPlace() {
            return new PlaceRepository.ImportedPlace(
                name, description, province, district, address, latitude, longitude,
                sourceType, externalSource, externalId
            );
        }

        private void validate() {
            if (!Set.of("ADMIN", "EXTERNAL_API", "USER_APPROVED").contains(sourceType)) {
                throw new IllegalArgumentException("source_type không hợp lệ cho Place seed: " + sourceType);
            }
            if (imageSourceUrl != null && !imageSourceUrl.isBlank()) {
                URI uri = URI.create(imageSourceUrl);
                if (!Set.of("http", "https").contains(uri.getScheme())) {
                    throw new IllegalArgumentException("image_source_url phải là HTTP/HTTPS: " + name);
                }
            }
        }

        private static String required(List<String> row, Map<String, Integer> columns, String name) {
            String value = optional(row, columns, name);
            if (value == null || value.isBlank()) throw new IllegalArgumentException("Thiếu cột seed bắt buộc: " + name);
            return value.trim();
        }

        private static String optional(List<String> row, Map<String, Integer> columns, String name) {
            Integer index = columns.get(name);
            if (index == null || index >= row.size()) return null;
            String value = row.get(index).trim();
            return value.isEmpty() ? null : value;
        }

        private static BigDecimal decimal(String value, String field) {
            try {
                return new BigDecimal(value);
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("Giá trị " + field + " không hợp lệ: " + value, e);
            }
        }
    }
}
