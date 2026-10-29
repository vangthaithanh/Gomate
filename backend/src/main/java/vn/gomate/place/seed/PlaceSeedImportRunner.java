package vn.gomate.place.seed;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "app.place.seed.enabled", havingValue = "true")
public class PlaceSeedImportRunner implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(PlaceSeedImportRunner.class);
    private final PlaceSeedImporter importer;
    private final ResourceLoader resources;
    private final ConfigurableApplicationContext context;
    private final String path;
    private final int limit;
    private final String folderPrefix;
    private final int mediaRetryAttempts;
    private final long mediaRetryDelayMillis;
    private final boolean exitAfterRun;

    public PlaceSeedImportRunner(
        PlaceSeedImporter importer,
        ResourceLoader resources,
        ConfigurableApplicationContext context,
        @Value("${app.place.seed.path:classpath:data/place_seed_dalat.csv}") String path,
        @Value("${app.place.seed.limit:10}") int limit,
        @Value("${app.place.seed.cloudinary-folder-prefix:gomate/dev/places}") String folderPrefix,
        @Value("${app.place.seed.media-retry-attempts:3}") int mediaRetryAttempts,
        @Value("${app.place.seed.media-retry-delay-ms:10000}") long mediaRetryDelayMillis,
        @Value("${app.place.seed.exit-after-run:false}") boolean exitAfterRun
    ) {
        this.importer = importer;
        this.resources = resources;
        this.context = context;
        this.path = path;
        this.limit = limit;
        this.folderPrefix = folderPrefix;
        this.mediaRetryAttempts = mediaRetryAttempts;
        this.mediaRetryDelayMillis = mediaRetryDelayMillis;
        this.exitAfterRun = exitAfterRun;
    }

    @Override
    public void run(ApplicationArguments args) {
        Resource resource = resources.getResource(path);
        var summary = importer.importSeed(resource, limit, folderPrefix, mediaRetryAttempts, mediaRetryDelayMillis);
        log.info(
            "Place seed import completed: seedRows={} placesUpserted={} mediaCreated={} mediaSkipped={} mediaFailed={}",
            summary.seedRows(), summary.placesUpserted(), summary.mediaCreated(), summary.mediaSkipped(), summary.mediaFailed()
        );
        if (exitAfterRun) {
            int code = summary.mediaFailed() == 0 ? 0 : 1;
            int exitCode = SpringApplication.exit(context, () -> code);
            System.exit(exitCode);
        }
    }
}
