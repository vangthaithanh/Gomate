package vn.gomate.media.service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import vn.gomate.common.ApiException;

@Component
public class RemoteImageFetcher {
    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
        "image/jpeg",
        "image/png",
        "image/webp"
    );

    private final HttpClient client;
    private final String userAgent;
    private final Duration timeout;
    private final long maxBytes;

    public RemoteImageFetcher(
        @Value("${app.place.seed.remote-image-user-agent:GoMateMediaImporter/1.0 (local development; contact: gomate-local@example.com)}") String userAgent,
        @Value("${app.place.seed.remote-image-timeout-ms:20000}") long timeoutMillis,
        @Value("${app.place.seed.remote-image-max-bytes:8388608}") long maxBytes
    ) {
        this.client = HttpClient.newBuilder()
            .connectTimeout(Duration.ofMillis(Math.max(1000, timeoutMillis)))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();
        this.userAgent = userAgent;
        this.timeout = Duration.ofMillis(Math.max(1000, timeoutMillis));
        this.maxBytes = Math.max(1, maxBytes);
    }

    public FetchedRemoteImage fetch(String imageUrl, int maxAttempts, long baseDelayMillis) {
        URI uri = URI.create(imageUrl);
        ApiException lastError = null;
        int attempts = Math.max(1, maxAttempts);
        for (int attempt = 1; attempt <= attempts; attempt++) {
            try {
                return fetchOnce(uri);
            } catch (RateLimitedException e) {
                lastError = new ApiException(503, "REMOTE_IMAGE_RATE_LIMITED", "Nguồn ảnh đang giới hạn request.", e);
                sleepBeforeRetry(e.retryAfterMillis(baseDelayMillis, attempt), attempt, attempts);
            } catch (IOException e) {
                lastError = new ApiException(503, "REMOTE_IMAGE_FETCH_FAILED", "Không tải được ảnh nguồn.", e);
                sleepBeforeRetry(backoff(baseDelayMillis, attempt), attempt, attempts);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new ApiException(503, "REMOTE_IMAGE_FETCH_INTERRUPTED", "Fetch ảnh nguồn bị gián đoạn.", e);
            }
        }
        throw lastError;
    }

    private FetchedRemoteImage fetchOnce(URI uri) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(uri)
            .timeout(timeout)
            .header("User-Agent", userAgent)
            .header("Accept", "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.2")
            .GET()
            .build();
        HttpResponse<InputStream> response = client.send(request, HttpResponse.BodyHandlers.ofInputStream());
        int status = response.statusCode();
        if (status == 429) {
            throw new RateLimitedException(retryAfter(response));
        }
        if (status < 200 || status >= 300) {
            throw new IOException("Remote image responded with HTTP " + status);
        }

        Optional<String> length = response.headers().firstValue("Content-Length");
        if (length.isPresent() && parseLong(length.get()) > maxBytes) {
            throw new IOException("Remote image is larger than maxBytes: " + length.get());
        }

        String contentType = response.headers().firstValue("Content-Type")
            .map(RemoteImageFetcher::mediaType)
            .orElse("");
        if (!ALLOWED_CONTENT_TYPES.contains(contentType)) {
            throw new IOException("Remote image content-type is not supported: " + contentType);
        }

        byte[] bytes = readLimited(response.body());
        return new FetchedRemoteImage(bytes, contentType, uri.toString());
    }

    private byte[] readLimited(InputStream input) throws IOException {
        try (InputStream stream = input; ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            long total = 0;
            int read;
            while ((read = stream.read(buffer)) != -1) {
                total += read;
                if (total > maxBytes) {
                    throw new IOException("Remote image exceeded maxBytes: " + maxBytes);
                }
                output.write(buffer, 0, read);
            }
            return output.toByteArray();
        }
    }

    private static long retryAfter(HttpResponse<?> response) {
        return response.headers().firstValue("Retry-After")
            .map(RemoteImageFetcher::parseRetryAfterMillis)
            .orElse(0L);
    }

    private static long parseRetryAfterMillis(String value) {
        String trimmed = value.trim();
        long seconds = parseLong(trimmed);
        if (seconds >= 0) {
            return seconds * 1000L;
        }
        try {
            Instant retryAt = ZonedDateTime.parse(trimmed, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant();
            long millis = Duration.between(Instant.now(), retryAt).toMillis();
            return Math.max(0, millis);
        } catch (DateTimeParseException ignored) {
            return 0;
        }
    }

    private static long parseLong(String value) {
        try {
            return Long.parseLong(value.trim());
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    private static String mediaType(String contentType) {
        return contentType.split(";", 2)[0].trim().toLowerCase(Locale.ROOT);
    }

    private static long backoff(long baseDelayMillis, int attempt) {
        long base = Math.max(1000, baseDelayMillis);
        long multiplier = 1L << Math.min(5, Math.max(0, attempt - 1));
        return Math.min(60000, base * multiplier);
    }

    private static void sleepBeforeRetry(long delayMillis, int attempt, int maxAttempts) {
        if (attempt >= maxAttempts) return;
        long delay = delayMillis > 0 ? delayMillis : backoff(10000, attempt);
        try {
            Thread.sleep(delay);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ApiException(503, "REMOTE_IMAGE_FETCH_INTERRUPTED", "Fetch ảnh nguồn bị gián đoạn.", e);
        }
    }

    private static class RateLimitedException extends IOException {
        private final long retryAfterMillis;

        RateLimitedException(long retryAfterMillis) {
            super("Remote image source responded with HTTP 429");
            this.retryAfterMillis = retryAfterMillis;
        }

        long retryAfterMillis(long baseDelayMillis, int attempt) {
            return retryAfterMillis > 0 ? retryAfterMillis : backoff(baseDelayMillis, attempt);
        }
    }
}
