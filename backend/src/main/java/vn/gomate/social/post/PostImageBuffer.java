package vn.gomate.social.post;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.function.LongSupplier;
import org.springframework.stereotype.Component;
import vn.gomate.media.provider.ProtectedMediaOrigin.Body;

/** Binary-only RAM buffer. Caller MUST reauthorize against PostgreSQL first. */
@Component
public class PostImageBuffer {
    private static final int MAX_IMAGE = 2 * 1024 * 1024;
    private static final long MAX_BYTES = 32L * 1024 * 1024;
    private static final int MAX_ENTRIES = 128;
    private static final long TTL = Duration.ofMinutes(2).toNanos();
    private record Entry(byte[] bytes, long loadedAt) {}
    @FunctionalInterface
    public interface Loader { Body open() throws Exception; }
    private final LinkedHashMap<String, Entry> entries = new LinkedHashMap<>(16, .75f, true);
    private final Object[] stripes = new Object[16];
    private final LongSupplier clock;
    private long bytes;

    public PostImageBuffer() { this(System::nanoTime); }
    PostImageBuffer(LongSupplier clock) {
        this.clock = clock;
        for (int i = 0; i < stripes.length; i++) stripes[i] = new Object();
    }

    public Body open(String key, Loader loader) throws Exception {
        // Fixed-size locks coalesce concurrent misses without unbounded lock/future maps.
        synchronized (stripes[(key.hashCode() & Integer.MAX_VALUE) % stripes.length]) {
            var cached = get(key);
            if (cached != null) return body(cached);
            var source = loader.open();
            if (source.offset() != 0 || source.total() <= 0 || source.total() > MAX_IMAGE) return source;
            byte[] data;
            try (source) {
                data = source.stream().readNBytes((int) source.total() + 1);
                if (data.length != source.total()) throw new IOException("Incomplete Post image");
            }
            put(key, data);
            return body(data);
        }
    }

    private synchronized byte[] get(String key) {
        var now = clock.getAsLong();
        var iterator = entries.values().iterator();
        while (iterator.hasNext()) {
            var entry = iterator.next();
            if (now - entry.loadedAt() >= TTL) {
                bytes -= entry.bytes().length;
                iterator.remove();
            }
        }
        var entry = entries.get(key);
        return entry == null ? null : entry.bytes();
    }

    private synchronized void put(String key, byte[] data) {
        entries.put(key, new Entry(data, clock.getAsLong()));
        bytes += data.length;
        var iterator = entries.values().iterator();
        while (bytes > MAX_BYTES || entries.size() > MAX_ENTRIES) {
            bytes -= iterator.next().bytes().length;
            iterator.remove();
        }
    }

    private Body body(byte[] data) {
        return new Body(new ByteArrayInputStream(data), data.length, 0, () -> {});
    }
}
