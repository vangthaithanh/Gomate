package db.migration;

import java.util.Locale;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

public class V18__account_privacy_foundation extends BaseJavaMigration {
 @Override
 public Integer getChecksum() { return 18001; }

 @Override
 public void migrate(Context context) throws Exception {
  var connection=context.getConnection();
  boolean h2=connection.getMetaData().getDatabaseProductName().toLowerCase(Locale.ROOT).contains("h2");
  try(var sql=connection.createStatement()) {
   sql.execute("ALTER TABLE user_settings ADD COLUMN account_visibility VARCHAR(20) NOT NULL DEFAULT 'PUBLIC' CHECK (account_visibility IN ('PUBLIC','PRIVATE'))");
   sql.execute("""
    CREATE TABLE follow_requests (
     id UUID PRIMARY KEY,
     requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     target_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','REJECTED','CANCELLED')),
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
     responded_at TIMESTAMP WITH TIME ZONE,
     CONSTRAINT ck_follow_requests_no_self CHECK (requester_id <> target_id),
     CONSTRAINT ck_follow_requests_response CHECK ((status='PENDING' AND responded_at IS NULL) OR (status<>'PENDING' AND responded_at IS NOT NULL))
    )
    """);
   // H2 tests emulate PostgreSQL's partial unique index with a nullable guard.
   if(h2) {
    sql.execute("ALTER TABLE follow_requests ADD COLUMN pending_guard INTEGER GENERATED ALWAYS AS (CASE WHEN status='PENDING' THEN 1 ELSE NULL END)");
    sql.execute("CREATE UNIQUE INDEX uq_follow_requests_pending ON follow_requests(requester_id,target_id,pending_guard)");
   } else {
    sql.execute("CREATE UNIQUE INDEX uq_follow_requests_pending ON follow_requests(requester_id,target_id) WHERE status='PENDING'");
   }
   sql.execute("CREATE INDEX ix_follow_requests_inbox ON follow_requests(target_id,status,created_at,id)");
  }
 }
}
