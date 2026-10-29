package vn.gomate.social.post;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.Duration;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.Test;
import vn.gomate.media.provider.ProtectedMediaOrigin.Body;
import static org.junit.jupiter.api.Assertions.*;

class PostImageBufferTest {
    private Body source(byte[] data) {
        return new Body(new ByteArrayInputStream(data), data.length, 0, () -> {});
    }

    @Test void warmReadReusesBytesButExpiryAndVariantFetchAgain() throws Exception {
        var time = new AtomicLong();
        var buffer = new PostImageBuffer(time::get);
        var loads = new AtomicInteger();
        PostImageBuffer.Loader loader = () -> { loads.incrementAndGet(); return source(new byte[]{1, 2}); };
        for (int i = 0; i < 2; i++) try (var body = buffer.open("image", loader)) {
            assertArrayEquals(new byte[]{1, 2}, body.stream().readAllBytes());
        }
        assertEquals(1, loads.get());
        try (var body = buffer.open("cover", loader)) { assertEquals(2, body.total()); }
        time.set(Duration.ofMinutes(2).toNanos());
        try (var body = buffer.open("image", loader)) { assertEquals(2, body.total()); }
        assertEquals(3, loads.get());
    }

    @Test void concurrentMissesHaveOneOriginRead() throws Exception {
        var buffer = new PostImageBuffer();
        var loads = new AtomicInteger();
        var entered = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var executor = Executors.newFixedThreadPool(2);
        Callable<byte[]> read = () -> {
            try (var body = buffer.open("shared", () -> {
                loads.incrementAndGet(); entered.countDown();
                assertTrue(release.await(5, TimeUnit.SECONDS));
                return source(new byte[]{3});
            })) { return body.stream().readAllBytes(); }
        };
        try {
            var first = executor.submit(read);
            assertTrue(entered.await(5, TimeUnit.SECONDS));
            var second = executor.submit(read);
            release.countDown();
            assertArrayEquals(new byte[]{3}, first.get(5, TimeUnit.SECONDS));
            assertArrayEquals(new byte[]{3}, second.get(5, TimeUnit.SECONDS));
            assertEquals(1, loads.get());
        } finally { release.countDown(); executor.shutdownNow(); }
    }

    @Test void failuresAndTruncationNeverBecomeHits() throws Exception {
        var buffer = new PostImageBuffer();
        assertThrows(IOException.class, () -> buffer.open("bad", () -> { throw new IOException(); }));
        var closed = new AtomicBoolean();
        assertThrows(IOException.class, () -> buffer.open("bad", () ->
            new Body(new ByteArrayInputStream(new byte[]{1}), 4, 0, () -> closed.set(true))));
        assertTrue(closed.get());
        try (var body = buffer.open("bad", () -> source(new byte[]{2}))) {
            assertArrayEquals(new byte[]{2}, body.stream().readAllBytes());
        }
    }

    @Test void largeImagesAndPartialBodiesAreNotBuffered() throws Exception {
        var buffer = new PostImageBuffer();
        var loads = new AtomicInteger();
        for (int i = 0; i < 2; i++) {
            try (var ignored = buffer.open("large", () -> {
                loads.incrementAndGet();
                return new Body(new ByteArrayInputStream(new byte[0]), 3 * 1024 * 1024, 0, () -> {});
            })) {}
            try (var ignored = buffer.open("partial", () -> {
                loads.incrementAndGet();
                return new Body(new ByteArrayInputStream(new byte[]{1}), 4, 3, () -> {});
            })) {}
        }
        assertEquals(4, loads.get());
    }

    @Test void byteAndEntryBoundsEvictLeastRecentlyUsed() throws Exception {
        var buffer = new PostImageBuffer();
        byte[] data = new byte[2 * 1024 * 1024];
        for (int i = 0; i < 17; i++) try (var ignored = buffer.open("large" + i, () -> source(data))) {}
        var misses = new AtomicInteger();
        try (var ignored = buffer.open("large0", () -> { misses.incrementAndGet(); return source(data); })) {}
        assertEquals(1, misses.get());
        for (int i = 0; i < 129; i++) try (var ignored = buffer.open("small" + i, () -> source(new byte[]{1}))) {}
        try (var ignored = buffer.open("small0", () -> { misses.incrementAndGet(); return source(new byte[]{1}); })) {}
        assertEquals(2, misses.get());
    }
}
