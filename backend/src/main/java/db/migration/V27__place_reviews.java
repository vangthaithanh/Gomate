package db.migration;

import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** Real GoMate reviews only. Empty-place default stars are a presentation rule. */
public class V27__place_reviews extends BaseJavaMigration {
 @Override public Integer getChecksum() { return 27001; }
 @Override public void migrate(Context context) throws Exception {
  boolean h2=context.getConnection().getMetaData().getDatabaseProductName().equalsIgnoreCase("H2");
  try(var sql=context.getConnection().createStatement()) {
   sql.execute("""
    CREATE TABLE reviews (
     id BIGSERIAL PRIMARY KEY,
     user_id UUID NOT NULL REFERENCES users(id),
     place_id BIGINT NOT NULL REFERENCES places(id),
     rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
     content VARCHAR(1000),
     publication_status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (publication_status IN ('ACTIVE','DELETED')),
     moderation_status VARCHAR(10) NOT NULL DEFAULT 'VISIBLE' CHECK (moderation_status IN ('VISIBLE','HIDDEN')),
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
     updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """);
   if(h2) {
    sql.execute("ALTER TABLE reviews ADD COLUMN active_place_id BIGINT GENERATED ALWAYS AS (CASE WHEN publication_status='ACTIVE' THEN place_id ELSE NULL END)");
    sql.execute("CREATE UNIQUE INDEX uq_reviews_active_user_place ON reviews(user_id,active_place_id)");
   } else sql.execute("CREATE UNIQUE INDEX uq_reviews_active_user_place ON reviews(user_id,place_id) WHERE publication_status='ACTIVE'");
   sql.execute("CREATE INDEX ix_reviews_place_visible_created ON reviews(place_id,publication_status,moderation_status,created_at,id)");
  }
 }
}
